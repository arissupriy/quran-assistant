// lib/pages/more_page.dart
import 'dart:async';
import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:quran_assistant/src/rust/api/recorder.dart' as rec;
import 'package:quran_assistant/src/rust/api/whisper.dart' as whisper;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _busyWhisper = false;
  int _totalSamples = 0;
  Timer? _poller;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  // Spectrum state
  static const int _ringSize = 4096; // ~256 ms at 16kHz
  static const int _fftSize = 512; // power of two, <= _ringSize
  static const int _numBands = 32;
  final List<int> _ring = List.filled(_ringSize, 0, growable: false);
  int _ringPos = 0;
  List<double> _bands = List.filled(_numBands, 0.0, growable: false);
  double _level = 0.0;
  int _ringFill = 0;
  // Diagnostics state
  static const int _sr = 16000;
  static const int _saveWindowSec = 5;
  final List<int> _saveRing = List.filled(_sr * _saveWindowSec, 0, growable: false);
  int _savePos = 0;
  int _saveFill = 0;
  // Raw (pre-processing) save ring
  final List<int> _saveRingRaw = List.filled(_sr * _saveWindowSec, 0, growable: false);
  int _savePosRaw = 0;
  int _saveFillRaw = 0;
  double _rmsDb = -160.0;
  double _peakDb = -160.0;
  double _dcOffset = 0.0;
  double _zcr = 0.0; // 0..1 fraction per chunk
  double? _snrDb; // requires calibration
  final List<double> _snrVoicedHist = <double>[]; // recent voiced SNRs
  // Rolling history (last ~5s at 90ms per window, ~55 windows)
  final List<double> _rmsHist = <double>[];
  final List<double> _clipHist = <double>[];
  final List<double> _zcrHist = <double>[];
  int _logCounter = 0;
  // Noise calibration
  bool _calibrating = false;
  int _calibSamplesLeft = 0;
  // Processed-noise accumulators removed; using RAW-only metrics
  // RAW noise tracking (pre-processing)
  double _noiseSum2Raw = 0.0;
  int _noiseNSamplesRaw = 0;
  double? _noiseRmsRaw;
  // Software gain & limiter (post-capture, pre-visual/metrics/WAV)
  double _gainDb = 18.0; // adjustable 0..24 dB (higher default)
  bool _softLimit = true;
  // High-pass filter state (first-order) and Auto-Gain Control (AGC)
  double _hpX1 = 0.0;
  double _hpY1 = 0.0;
  bool _autoGain = true;
  double _targetRmsDb = -15.0; // aim around -15 dBFS
  double _agcDb = 0.0; // dynamic adjustment added to _gainDb
  // VAD & silence
  bool _vadEnabled = true;
  bool _trimSilence = true;
  bool _normalizeForWhisper = true;
  bool _isVoiced = false;
  int _vadOnStreak = 0;
  int _vadOffStreak = 0;
  // Silence tracking for refine-pass
  int _silenceMs = 0;
  // Keep a raw rolling buffer of ~6s to allow refine window of 3–5s
  static const int _refineWindowSec = 6;
  final List<int> _refineRingRaw = List.filled(_sr * _refineWindowSec, 0, growable: false);
  int _refinePosRaw = 0;
  int _refineFillRaw = 0;
  // Whisper sliding window
  bool _slidingWhisper = false;
  Timer? _slideTimer;
  String _liveTranscript = '';
  String _lastSlideText = '';
  final int _slideHopMs = 1500; // hop size for sliding updates
  // Verbose logging + in-app log buffer
  bool _verboseLog = false;
  final List<String> _logBuf = <String>[];
  int _chunkSeq = 0;
  // Input preset for Android Oboe
  rec.RecInputPreset _preset = rec.RecInputPreset.voiceRecognition;

  void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts] $msg';
    _logBuf.add(line);
    if (_logBuf.length > 5000) {
      _logBuf.removeRange(0, _logBuf.length - 5000);
    }
    // mirror to console
    // ignore: avoid_print
    print(line);
  }

  @override
  void dispose() {
    _poller?.cancel();
  _slideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  Future<void> _toggleRecorder() async {
    if (!Platform.isAndroid) {
      _showSnack('Recorder hanya didukung di Android');
      return;
    }

    if (!_recording) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showSnack('Izin mikrofon ditolak');
        return;
      }
      await rec.recorderInit();
  await rec.recorderStart(sampleRate: _sr, preset: _preset);
  // reset processing states
  _hpX1 = 0.0; _hpY1 = 0.0; _agcDb = 0.0;
  _chunkSeq = 0;
  _log('[AudioStart] sr=$_sr, preset=${_preset.name}, baseGainDb=${_gainDb.toStringAsFixed(1)}, limiter=$_softLimit, autoGain=$_autoGain,'
    ' hpCut=70Hz, targetRmsDb=${_targetRmsDb.toStringAsFixed(1)}, fft=$_fftSize, bands=$_numBands, ring=$_ringSize');
      setState(() => _recording = true);
      if (_slidingWhisper) {
        _startSlidingWhisper();
      }
      // Poll frequently for smoother spectrum
      _poller = Timer.periodic(const Duration(milliseconds: 90), (_) async {
        final chunk = await rec.recorderTakeSamples();
        if (chunk.isNotEmpty) {
          // Update counters
          _totalSamples += chunk.length;
          // Push RAW into raw save ring (pre-processing)
          for (int i = 0; i < chunk.length; i++) {
            _saveRingRaw[_savePosRaw] = chunk[i];
            _savePosRaw = (_savePosRaw + 1) % _saveRingRaw.length;
            // also into refine ring (~6s)
            _refineRingRaw[_refinePosRaw] = chunk[i];
            _refinePosRaw = (_refinePosRaw + 1) % _refineRingRaw.length;
          }
          _saveFillRaw = math.min(_saveRingRaw.length, _saveFillRaw + chunk.length);
          _refineFillRaw = math.min(_refineRingRaw.length, _refineFillRaw + chunk.length);
          // Push into ring buffer (processed)
          final double appliedDb = (_autoGain ? (_gainDb + _agcDb) : _gainDb).clamp(0.0, 30.0);
          final double gainLin = math.pow(10.0, appliedDb / 20.0).toDouble();
          // High-pass coefficient (first-order): y[n] = a*(y[n-1] + x[n] - x[n-1])
          const double hpCut = 70.0; // Hz
          final double rc = 1.0 / (2 * math.pi * hpCut);
          final double dt = 1.0 / _sr;
          final double a = rc / (rc + dt);
          double sum2RawChunk = 0.0; // accumulate RAW energy per chunk
          for (int i = 0; i < chunk.length; i++) {
            // high-pass first to reduce DC/rumble, then apply gain and limiter
            final double xin = (chunk[i] / 32768.0);
            sum2RawChunk += xin * xin;
            final double yhp = a * (_hpY1 + xin - _hpX1);
            _hpX1 = xin;
            _hpY1 = yhp;
            double x = yhp * gainLin;
            double y = x;
            if (_softLimit) {
              // simple smooth saturation that asymptotically approaches 1.0
              y = y / (1.0 + 0.5 * y.abs());
            }
            y = y.clamp(-1.0, 1.0);
            final int sInt = (y * 32767.0).round().clamp(-32768, 32767);
            _ring[_ringPos] = sInt;
            _ringPos = (_ringPos + 1) & (_ringSize - 1);
            // Also push into 5s save ring (non power-of-two length)
            _saveRing[_savePos] = sInt;
            _savePos = (_savePos + 1) % _saveRing.length;
          }
          _ringFill = math.min(_ringSize, _ringFill + chunk.length);
          _saveFill = math.min(_saveRing.length, _saveFill + chunk.length);
          // Compute level (RMS) for quick feedback
          double sum = 0.0, sum2 = 0.0, maxAbs = 0.0;
          int clip = 0, zc = 0;
          double prev = 0.0;
          for (int i = 0; i < chunk.length; i++) {
            // read back processed samples from ring for metrics (last chunk-sized tail)
            final int idx = (_ringPos - (chunk.length - i)) & (_ringSize - 1);
            final double s = _ring[idx] / 32768.0;
            sum += s;
            sum2 += s * s;
            final double a = s.abs();
            if (a > maxAbs) maxAbs = a;
            if (a >= 0.998) clip++;
            if (i > 0 && (s > 0) != (prev > 0)) zc++;
            prev = s;
          }
          final double mean = sum / chunk.length;
          final double rms = math.sqrt(math.max(1e-12, sum2 / chunk.length));
          final double rmsRaw = math.sqrt(math.max(1e-12, sum2RawChunk / chunk.length));
          final double peak = maxAbs;
          final double dbRms = 20.0 * math.log(rms) / math.ln10; // dBFS
          final double dbPeak = 20.0 * math.log(math.max(1e-12, peak)) / math.ln10;
          final double dbRmsRaw = 20.0 * math.log(rmsRaw) / math.ln10; // dBFS (raw)
          final double zcrFrac = (zc / chunk.length).clamp(0.0, 1.0);
          final double clipFrac = (clip / chunk.length).clamp(0.0, 1.0);

          // Keep rolling histories (cap ~60 windows)
          void pushCapped(List<double> list, double v) {
            list.add(v);
            if (list.length > 60) list.removeAt(0);
          }
          pushCapped(_rmsHist, dbRms);
          pushCapped(_clipHist, clipFrac);
          pushCapped(_zcrHist, zcrFrac);

          _rmsDb = dbRms;
          _peakDb = dbPeak;
          _dcOffset = _smooth(_dcOffset, mean, 0.2);
          _zcr = _smooth(_zcr, zcrFrac, 0.3);
          _level = _smooth(_level, rms.clamp(0.0, 1.0), 0.35);
          // Simple AGC to approach target RMS
          if (_autoGain) {
            final double err = (_targetRmsDb - dbRms).clamp(-18.0, 18.0);
            // slow adjustment to avoid pumping
            final double agcAlpha = 0.09;
            _agcDb = (_agcDb + agcAlpha * (err - _agcDb)).clamp(-12.0, 24.0);
          } else {
            _agcDb = 0.0;
          }

          // Noise calibration collection
          if (_calibrating) {
            _calibSamplesLeft -= chunk.length;
            // keep processed collection off; use RAW-based only
            // _noiseSum2 += sum2;
            // _noiseNSamples += chunk.length;
            _noiseSum2Raw += sum2RawChunk;
            _noiseNSamplesRaw += chunk.length;
            if (_calibSamplesLeft <= 0) {
              _calibrating = false;
        // final double noiseRms = math.sqrt(math.max(1e-12, _noiseSum2 / math.max(1, _noiseNSamples)));
        final double noiseRmsRaw = math.sqrt(math.max(1e-12, _noiseSum2Raw / math.max(1, _noiseNSamplesRaw)));
              _noiseRmsRaw = noiseRmsRaw;
              final double snrRaw = 20.0 * math.log(rmsRaw / noiseRmsRaw) / math.ln10;
              _snrDb = snrRaw; // prefer RAW SNR for quality display
  _noiseSum2Raw = 0.0; _noiseNSamplesRaw = 0; _calibSamplesLeft = 0;
              // Quick console summary
        _log('[AudioCalib] noiseRmsRaw=${(20*math.log(noiseRmsRaw)/math.ln10).toStringAsFixed(1)} dBFS');
            }
      } else if (_noiseRmsRaw != null) {
            final double snrInstant = 20.0 * math.log(rmsRaw / (_noiseRmsRaw!.clamp(1e-9, 1.0))) / math.ln10;
            final bool voiced = snrInstant > 6.0 && dbRmsRaw > -36.0;
            if (voiced) {
              _snrDb = snrInstant;
              _snrVoicedHist.add(snrInstant);
              if (_snrVoicedHist.length > 60) _snrVoicedHist.removeAt(0);
            }
            // Simple VAD with hysteresis on SNR+RMS
            if (_vadEnabled) {
              if (_isVoiced) {
                // require stronger evidence to turn off
                if (!(snrInstant > 3.0 && dbRmsRaw > -39.0)) {
                  _vadOffStreak++;
                  if (_vadOffStreak >= 4) { _isVoiced = false; _vadOffStreak = 0; }
                } else {
                  _vadOffStreak = 0;
                }
              } else {
                if (snrInstant > 6.0 && dbRmsRaw > -36.0) {
                  _vadOnStreak++;
                  if (_vadOnStreak >= 2) { _isVoiced = true; _vadOnStreak = 0; }
                } else {
                  _vadOnStreak = 0;
                }
              }
            } else {
              _isVoiced = true;
            }
            // Track silence duration for refine-pass trigger
            final int frameMs = ((chunk.length / _sr) * 1000).round();
            if (_isVoiced) {
              _silenceMs = 0;
            } else {
              _silenceMs = (_silenceMs + frameMs).clamp(0, 10000);
            }
          } else {
            // Auto-calibrate noise floor opportunistically from quiet frames
            if (dbRmsRaw < -36.0) {
              _noiseSum2Raw += sum2RawChunk;
              _noiseNSamplesRaw += chunk.length;
              // finalize after ~0.5s of quiet
              if (_noiseNSamplesRaw >= (_sr ~/ 2)) {
                final double noiseRmsRaw = math.sqrt(math.max(1e-12, _noiseSum2Raw / math.max(1, _noiseNSamplesRaw)));
                _noiseRmsRaw = noiseRmsRaw;
                _noiseSum2Raw = 0.0; _noiseNSamplesRaw = 0;
                _log('[AudioCalibAuto] noiseRmsRaw=${(20*math.log(noiseRmsRaw)/math.ln10).toStringAsFixed(1)} dBFS');
              }
            } else {
              // reset if it's not quiet to avoid biasing noise too high
              _noiseSum2Raw = 0.0; _noiseNSamplesRaw = 0;
            }
          }

          // Periodic console log for debugging
          if ((_logCounter++ % 12) == 0) {
            final avgClip = _clipHist.isEmpty ? 0.0 : _clipHist.reduce((a,b)=>a+b) / _clipHist.length;
            final avgRms = _rmsHist.isEmpty ? _rmsDb : _rmsHist.reduce((a,b)=>a+b) / _rmsHist.length;
            double? snrForLog;
            if (_snrVoicedHist.isNotEmpty) {
              final sorted = List<double>.from(_snrVoicedHist)..sort();
              snrForLog = sorted[sorted.length ~/ 2];
            } else {
              snrForLog = _snrDb;
            }
      final snrText = snrForLog == null
        ? (_noiseRmsRaw == null ? '— (kalibrasi?)' : '—')
        : snrForLog.toStringAsFixed(1);
    _log('[AudioDiag] RMS=${avgRms.toStringAsFixed(1)} dBFS, Peak=${_peakDb.toStringAsFixed(1)} dBFS, '
          'Clip=${(avgClip*100).toStringAsFixed(2)}%, DC=${(_dcOffset*1000).toStringAsFixed(2)}‰, '
      'ZCR=${(_zcr*100).toStringAsFixed(1)}%, SNR=${snrText} dB, VAD=${_isVoiced ? 'on' : 'off'}');
          }
          if (_verboseLog) {
            // Detailed per-chunk snapshot
            final appliedDb = (_autoGain ? (_gainDb + _agcDb) : _gainDb).clamp(0.0, 30.0);
            _chunkSeq++;
    _log('[AudioDetail] n=$_chunkSeq, chunk=${chunk.length}, appliedDb=${appliedDb.toStringAsFixed(1)} (base=${_gainDb.toStringAsFixed(1)}, agc=${_agcDb.toStringAsFixed(1)}), '
      'RMS=${_rmsDb.toStringAsFixed(1)} dBFS (raw ${dbRmsRaw.toStringAsFixed(1)}), Peak=${_peakDb.toStringAsFixed(1)} dBFS, ClipNow=${(clipFrac*100).toStringAsFixed(2)}%, '
                  'DC=${(mean*1000).toStringAsFixed(2)}‰, ZCR=${(zcrFrac*100).toStringAsFixed(1)}%, SNR=${_snrDb?.toStringAsFixed(1) ?? '-'} dB, '
                  'ringFill=$_ringFill, saveFill=$_saveFill, window=${_hasWindow()}');
          }
          // Compute spectrum on the latest window when we have enough samples
          if (_hasWindow()) {
            final window = _extractWindow();
            final mags = _fftMagnitudes(window);
            _bands = _toBands(mags, 16000, _numBands);
          }
          if (mounted) setState(() {});
        }
      });
    } else {
      await rec.recorderStop();
      _poller?.cancel();
  _stopSlidingWhisper();
  try {
    final avgClip = _clipHist.isEmpty ? 0.0 : _clipHist.reduce((a,b)=>a+b) / _clipHist.length;
    final avgRms = _rmsHist.isEmpty ? _rmsDb : _rmsHist.reduce((a,b)=>a+b) / _rmsHist.length;
    _log('[AudioStop] totalSamples=$_totalSamples, duration=${_formatDuration(_totalSamples)}, '
      'avgRMS=${avgRms.toStringAsFixed(1)} dBFS, avgClip=${(avgClip*100).toStringAsFixed(2)}%');
  } catch (_) {}
      setState(() => _recording = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recorder', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (_recording)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text('REC', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                              ]),
                            )
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(isAndroid ? 'Siap merekam di Android' : 'Recorder hanya tersedia di Android',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Sample rate: 16 kHz • Mono • i16', style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor)),
                            const SizedBox(height: 16),
                            _SpectrumWithAdvice(active: _recording, bands: _bands, level: _level, advice: _gainAdviceLabel(), adviceColor: _gainAdviceColor(context)),
                            const SizedBox(height: 14),
                            // Gain + limiter controls
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Gain (dB)', style: theme.textTheme.labelMedium),
                                          Text(_gainDb.toStringAsFixed(0), style: theme.textTheme.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                                        ],
                                      ),
                                      Slider(
                                        value: _gainDb,
                                        min: 0,
                                        max: 24,
                                        divisions: 24,
                                        label: '${_gainDb.toStringAsFixed(0)} dB',
                                        onChanged: (v) => setState(() => _gainDb = v),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Limiter', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _softLimit,
                                      onChanged: (v) => setState(() => _softLimit = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Auto gain', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _autoGain,
                                      onChanged: (v) => setState(() => _autoGain = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Preset', style: theme.textTheme.labelMedium),
                                    DropdownButton<rec.RecInputPreset>(
                                      value: _preset,
                                      onChanged: _recording ? null : (v) => setState(() => _preset = v ?? _preset),
                                      items: const [
                                        DropdownMenuItem(
                                          value: rec.RecInputPreset.voiceRecognition,
                                          child: Text('VoiceRecognition'),
                                        ),
                                        DropdownMenuItem(
                                          value: rec.RecInputPreset.unprocessed,
                                          child: Text('Unprocessed'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Verbose log', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _verboseLog,
                                      onChanged: (v) => setState(() => _verboseLog = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('AGC', style: theme.textTheme.labelMedium),
                                    TextButton(
                                      onPressed: !_recording ? null : () {
                                        setState(() {
                                          _agcDb = 0.0;
                                          _snrVoicedHist.clear();
                                        });
                                        _log('[AudioCtrl] Reset AGC and SNR history');
                                      },
                                      child: const Text('Reset'),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('VAD', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _vadEnabled,
                                      onChanged: (v) => setState(() => _vadEnabled = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Trim', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _trimSilence,
                                      onChanged: (v) => setState(() => _trimSilence = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Normalize', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _normalizeForWhisper,
                                      onChanged: (v) => setState(() => _normalizeForWhisper = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Sliding', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _slidingWhisper,
                                      onChanged: (v) {
                                        setState(() => _slidingWhisper = v);
                                        if (_recording) {
                                          if (v) {
                                            _startSlidingWhisper();
                                          } else {
                                            _stopSlidingWhisper();
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _statTile(context, 'Samples', _totalSamples.toString()),
                                _statTile(context, 'Durasi', _formatDuration(_totalSamples)),
                                _statTile(context, 'Status', _recording ? 'Merekam' : 'Siap'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildDebugPanel(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ScaleTransition(
                  scale: _recording ? _scale : const AlwaysStoppedAnimation(1.0),
                  child: GestureDetector(
                    onTap: _toggleRecorder,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _recording ? theme.colorScheme.error : theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_recording ? theme.colorScheme.error : theme.colorScheme.primary).withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Icon(_recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                          color: theme.colorScheme.onPrimary, size: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _recording ? 'Menekan STOP akan mengakhiri rekaman.' : 'Tekan tombol untuk mulai rekam 16 kHz.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: child,
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _formatDuration(int samples) {
    // 16k samples per second, mono
    final seconds = samples / 16000.0;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toStringAsFixed(1).padLeft(4, '0');
    return '$m:${s.padLeft(4)}';
  }

  Widget _buildDebugPanel(BuildContext context) {
    final theme = Theme.of(context);
    String fmtDb(double v) => v.isFinite ? '${v.toStringAsFixed(1)} dBFS' : '- dBFS';
    double? snrDisp;
    if (_snrVoicedHist.isNotEmpty) {
      final sorted = List<double>.from(_snrVoicedHist)..sort();
      snrDisp = sorted[sorted.length ~/ 2];
    } else {
      snrDisp = _snrDb;
    }
    final snrText = snrDisp == null ? '—' : '${snrDisp.isFinite ? snrDisp.toStringAsFixed(1) : '-'} dB';
    final clipAvg = _clipHist.isEmpty ? 0.0 : _clipHist.reduce((a,b)=>a+b) / _clipHist.length;
  final verdict = _qualityVerdict();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _miniStat(theme, 'RMS', fmtDb(_rmsDb)),
                  _miniStat(theme, 'Peak', fmtDb(_peakDb)),
                  _miniStat(theme, 'Clip', '${(clipAvg*100).toStringAsFixed(2)}%'),
                  _miniStat(theme, 'DC', '${(_dcOffset*1000).toStringAsFixed(1)}‰'),
                  _miniStat(theme, 'ZCR', '${(_zcr*100).toStringAsFixed(1)}%'),
                  _miniStat(theme, 'SNR', snrText),
          _miniStat(theme, 'Kualitas', verdict),
                  _miniStat(theme, 'Gain', '${_gainDb.toStringAsFixed(0)} dB'),
                  _miniStat(theme, 'Limiter', _softLimit ? 'On' : 'Off'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: !_recording || _calibrating ? null : () {
                setState(() {
                  _calibrating = true;
                  _calibSamplesLeft = _sr; // ~1s noise capture
                  _noiseSum2Raw = 0.0;
                  _noiseNSamplesRaw = 0;
                  _noiseRmsRaw = null; // will be filled
                  _snrDb = null;
                });
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(_calibrating ? 'Kalibrasi…' : 'Kalibrasi noise'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _saveFill == 0 ? null : _dumpLast5sWav,
              icon: const Icon(Icons.save_alt_rounded, size: 18),
              label: const Text('Simpan 5s WAV (proc)'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _saveFillRaw == 0 ? null : _dumpLast5sWavRaw,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Simpan 5s RAW'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: (!_recording && _saveFillRaw > 0 && !_busyWhisper) ? _transcribeLast5sRawWithWhisper : null,
              icon: const Icon(Icons.translate_rounded, size: 18),
              label: Text(_busyWhisper ? 'Transkripsi…' : 'Transkrip 5s RAW'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _liveTranscript.isEmpty ? null : _saveTranscript,
              icon: const Icon(Icons.save_as_rounded, size: 18),
              label: const Text('Simpan transkrip'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: _logBuf.isEmpty ? null : _dumpDebugLog,
              icon: const Icon(Icons.note_alt_rounded, size: 18),
              label: const Text('Simpan log'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tip: Diam sejenak dan tekan “Kalibrasi noise”. Target RMS -18..-12 dBFS, clipping < 0.1%, DC ~0, ZCR ~10–20%.',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 8),
        if (_slidingWhisper || _liveTranscript.isNotEmpty)
          _buildTranscriptPanel(theme),
      ],
    );
  }

  Widget _miniStat(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          const SizedBox(width: 6),
          Text(value, style: theme.textTheme.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  String _qualityVerdict() {
    // Heuristic thresholds for ASR input:
    // RMS target -18..-12 dBFS; Peak < -1 dBFS; Clipping < 0.1%; DC small; ZCR reasonable; SNR >= 20 dB
    final clipAvg = _clipHist.isEmpty ? 0.0 : _clipHist.reduce((a,b)=>a+b) / _clipHist.length;
    int score = 0;
    if (_rmsDb > -22 && _rmsDb < -10) score += 2; else if (_rmsDb > -30 && _rmsDb < -6) score += 1;
    if (_peakDb < -0.5) score += 1; // not hitting 0 dBFS
    if (clipAvg < 0.001) score += 2; else if (clipAvg < 0.01) score += 1;
    if (_dcOffset.abs() < 0.01) score += 1; // <1%
    if (_zcr > 0.05 && _zcr < 0.25) score += 1;
    if (_snrDb != null) {
      if (_snrDb! >= 25) score += 2; else if (_snrDb! >= 15) score += 1;
    }
    if (score >= 7) return 'Bagus';
    if (score >= 4) return 'Cukup';
    return 'Perbaiki';
  }

  // --- Spectrum helpers ---
  bool _hasWindow() => _ringFill >= _fftSize;

  List<double> _extractWindow() {
    // Take the last _fftSize samples from the ring buffer, apply Hann window, convert to double [-1,1]
    final List<double> out = List.filled(_fftSize, 0.0, growable: false);
    final int start = (_ringPos - _fftSize) & (_ringSize - 1);
    for (int n = 0; n < _fftSize; n++) {
      final idx = (start + n) & (_ringSize - 1);
      final double s = _ring[idx] / 32768.0; // i16 -> [-1,1)
      final double w = 0.5 * (1 - math.cos(2 * math.pi * n / (_fftSize - 1)));
      out[n] = s * w;
    }
    return out;
  }

  // Compute magnitude spectrum (first N/2 bins) using radix-2 FFT
  List<double> _fftMagnitudes(List<double> input) {
    final int n = input.length;
    final List<double> real = List.of(input, growable: false);
    final List<double> imag = List.filled(n, 0.0, growable: false);

    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while (j & bit != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j |= bit;
      if (i < j) {
        final tmpR = real[i];
        real[i] = real[j];
        real[j] = tmpR;
        final tmpI = imag[i];
        imag[i] = imag[j];
        imag[j] = tmpI;
      }
    }

    // FFT
    for (int len = 2; len <= n; len <<= 1) {
      final double ang = -2 * math.pi / len;
      final double wlenCos = math.cos(ang);
      final double wlenSin = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double wCos = 1.0;
        double wSin = 0.0;
        for (int k = 0; k < len / 2; k++) {
          final int u = i + k;
          final int v = i + k + len ~/ 2;
          final double rV = real[v] * wCos - imag[v] * wSin;
          final double iV = real[v] * wSin + imag[v] * wCos;
          final double rU = real[u];
          final double iU = imag[u];
          real[v] = rU - rV;
          imag[v] = iU - iV;
          real[u] = rU + rV;
          imag[u] = iU + iV;
          final double nextCos = wCos * wlenCos - wSin * wlenSin;
          final double nextSin = wCos * wlenSin + wSin * wlenCos;
          wCos = nextCos;
          wSin = nextSin;
        }
      }
    }

    // Magnitude for bins 0..n/2
    final int half = n ~/ 2;
    final List<double> mags = List.filled(half + 1, 0.0, growable: false);
    for (int k = 0; k <= half; k++) {
      final double re = real[k];
      final double im = imag[k];
      mags[k] = math.sqrt(re * re + im * im) / n; // scale
    }
    return mags;
  }

  List<double> _toBands(List<double> mags, int sampleRate, int bands) {
    final int n = (_fftSize ~/ 2);
    // Log-spaced bands between 60Hz and Nyquist
    const double fMin = 60.0;
    final double fMax = sampleRate / 2.0;
    final List<double> edges = List.filled(bands + 1, 0.0);
    for (int i = 0; i <= bands; i++) {
      final double t = i / bands;
      edges[i] = fMin * math.pow(fMax / fMin, t);
    }
    final List<double> out = List.filled(bands, 0.0);
    for (int b = 0; b < bands; b++) {
      final double f0 = edges[b];
      final double f1 = edges[b + 1];
      final int k0 = ((f0 * _fftSize) / sampleRate).floor().clamp(0, n);
      final int k1 = ((f1 * _fftSize) / sampleRate).ceil().clamp(0, n);
      double acc = 0.0;
      int cnt = 0;
      for (int k = k0; k <= k1 && k < mags.length; k++) {
        acc += mags[k];
        cnt++;
      }
      final double m = cnt > 0 ? acc / cnt : (mags[(k0 + k1) ~/ 2]).toDouble();
      // Convert to dB-like scale and normalize
      final double db = 20.0 * math.log(m + 1e-6) / math.ln10; // [-inf, ~0]
      final double norm = ((db + 80.0) / 80.0).clamp(0.0, 1.0);
      // Smooth with previous value
      out[b] = _smooth(_bands[b], norm, 0.35);
    }
    return out;
  }

  double _smooth(double prev, double next, double alpha) {
    return prev + (next - prev) * alpha;
  }

  // --- Gain advice overlay ---
  String _gainAdviceLabel() {
    // Use RMS, Peak, and clipping to advise
    if (_peakDb > -1.0 || (_clipHist.isNotEmpty && _clipHist.last > 0.001)) return 'Terlalu keras';
    if (_rmsDb < -30.0) return 'Terlalu pelan';
    if (_snrDb != null && _snrDb! < 15) return 'Bising';
    return 'Baik';
  }

  Color _gainAdviceColor(BuildContext context) {
    final s = _gainAdviceLabel();
    final cs = Theme.of(context).colorScheme;
    if (s == 'Terlalu keras') return cs.error;
    if (s == 'Terlalu pelan' || s == 'Bising') return cs.tertiary;
    return cs.primary;
  }

  // --- WAV dump (last 5s) ---
  Future<void> _dumpLast5sWav() async {
    try {
      // Collect in time order from save ring
      final int n = _saveFill;
      final int len = _saveRing.length;
      final List<int> samples = List.filled(n, 0);
      final int start = (len + _savePos - n) % len;
      for (int i = 0; i < n; i++) {
        samples[i] = _saveRing[(start + i) % len];
      }
      // Prepare WAV (PCM16, mono, _sr)
      final bytes = _encodeWavPcm16(samples, sampleRate: _sr, channels: 1);
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'rec_${ts}_5s.wav'));
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) _showSnack('Disimpan: ${file.path}');
      // ignore: avoid_print
      print('[AudioDump] Saved ${samples.length/_sr}s -> ${file.path}');
    } catch (e) {
      if (mounted) _showSnack('Gagal simpan WAV: $e');
    }
  }

  Future<void> _dumpLast5sWavRaw() async {
    try {
      final int n = _saveFillRaw;
      final int len = _saveRingRaw.length;
      final List<int> samples = List.filled(n, 0);
      final int start = (len + _savePosRaw - n) % len;
      for (int i = 0; i < n; i++) {
        samples[i] = _saveRingRaw[(start + i) % len];
      }
      final bytes = _encodeWavPcm16(samples, sampleRate: _sr, channels: 1);
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'rec_${ts}_5s_raw.wav'));
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) _showSnack('Disimpan RAW: ${file.path}');
      // ignore: avoid_print
      print('[AudioDump] Saved RAW ${samples.length/_sr}s -> ${file.path}');
    } catch (e) {
      if (mounted) _showSnack('Gagal simpan RAW: $e');
    }
  }

  // --- Debug log dump ---
  Future<void> _dumpDebugLog() async {
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'audio_debug_${ts}.log'));
      await file.writeAsString(_logBuf.join('\n'));
      if (mounted) _showSnack('Log disimpan: ${file.path}');
      // ignore: avoid_print
      print('[AudioDump] Saved log -> ${file.path} (${_logBuf.length} lines)');
    } catch (e) {
      if (mounted) _showSnack('Gagal simpan log: $e');
    }
  }

  // --- Whisper: transcribe last 5s RAW ---
  Future<void> _transcribeLast5sRawWithWhisper() async {
    if (_saveFillRaw <= 0 || _busyWhisper) return;
    setState(() => _busyWhisper = true);
    try {
      // Ensure model loaded from assets once
      final loaded = await whisper.isWhisperModelLoaded();
      if (!loaded) {
        // Load default tiny model from assets (declared in pubspec)
        final data = await rootBundle.load('assets/ggml-tiny.bin');
        await whisper.loadWhisperModelFromFlutter(data: data.buffer.asUint8List());
      }
      // Collect last window from RAW ring
      final int n = _saveFillRaw;
      final int len = _saveRingRaw.length;
      final List<int> samples = List.filled(n, 0);
      final int start = (len + _savePosRaw - n) % len;
      for (int i = 0; i < n; i++) {
        samples[i] = _saveRingRaw[(start + i) % len];
      }
      // Optionally trim silence (VAD-based) and normalize before Whisper
      final List<int> ready = _applyTrimAndNormalizeForWhisper(samples);
      if (ready.isEmpty) {
        if (mounted) _showSnack('(kosong)');
        return;
      }
      // Run Whisper
      final text = await whisper.transcribePcm(pcmS16Mono: ready, sampleRate: _sr);
      if (mounted) _showSnack(text.isEmpty ? '(kosong)' : text.trim());
    } catch (e) {
      if (mounted) _showSnack('Whisper gagal: $e');
    } finally {
      if (mounted) setState(() => _busyWhisper = false);
    }
  }

  // Sliding Whisper transcription management
  void _startSlidingWhisper() {
    _slideTimer?.cancel();
    // warm start: run soon after enabling
    _slideTimer = Timer.periodic(Duration(milliseconds: _slideHopMs), (_) {
      _handleSlidingTick();
    });
  // fire one immediately
  // ignore: discarded_futures
  _handleSlidingTick();
    _log('[WhisperSlide] started hop=${_slideHopMs}ms');
  }

  void _stopSlidingWhisper() {
    _slideTimer?.cancel();
    _slideTimer = null;
    _log('[WhisperSlide] stopped');
  }

  Future<void> _handleSlidingTick() async {
    if (!_recording) return;
    if (!_slidingWhisper) return;
    if (_busyWhisper) return; // avoid overlapping inference
  if (_saveFillRaw < (_sr * 1)) return; // need at least 1s of audio
    setState(() => _busyWhisper = true);
    try {
      // Ensure model loaded
      final loaded = await whisper.isWhisperModelLoaded();
      if (!loaded) {
        final data = await rootBundle.load('assets/ggml-tiny.bin');
        await whisper.loadWhisperModelFromFlutter(data: data.buffer.asUint8List());
      }
      // Collect last window from RAW ring (same as manual path)
      final int n = _saveFillRaw;
      final int len = _saveRingRaw.length;
      final List<int> samples = List.filled(n, 0);
      final int start = (len + _savePosRaw - n) % len;
      for (int i = 0; i < n; i++) {
        samples[i] = _saveRingRaw[(start + i) % len];
      }

      final List<int> ready = _applyTrimAndNormalizeForWhisper(samples);
      if (ready.isEmpty) return; // nothing voiced
      // Fast streaming decode: Arabic, no timestamps, temp 0.0, beam_size 2
      final String text = await whisper.transcribePcmWithParams(
        pcmS16Mono: ready,
        sampleRate: _sr,
        language: 'ar',
        noTimestamps: true,
        temperature: 0.0,
        beamSize: 2,
      );
      _appendSlidingText(text);
      if (mounted) setState(() {});
      // Refine-pass: if silence >= 600ms, grab last 3–5s and decode with timestamps
      if (_silenceMs >= 600) {
        final int refineSec = 4; // middle of 3–5s
        final int need = (_sr * refineSec).clamp(0, _refineFillRaw);
        if (need > 0) {
          final int lenR = _refineRingRaw.length;
          final List<int> win = List.filled(need, 0);
          final int startR = (lenR + _refinePosRaw - need) % lenR;
          for (int i = 0; i < need; i++) {
            win[i] = _refineRingRaw[(startR + i) % lenR];
          }
          final List<int> trimmed = _applyTrimAndNormalizeForWhisper(win);
          if (trimmed.isNotEmpty) {
            final segs = await whisper.transcribePcmSegments(
              pcmS16Mono: trimmed,
              sampleRate: _sr,
              language: 'ar',
              withTimestamps: true,
              temperature: 0.0,
              beamSize: 2,
            );
            // For now, append refined text tail; downstream can do alignment/highlight with segs[t0/t1]
            final refinedText = segs.map((s) => s.text).join('');
            if (refinedText.trim().isNotEmpty) {
              _appendSlidingText(refinedText);
              if (mounted) setState(() {});
            }
          }
          // reset silence to avoid repeated refine floods
          _silenceMs = 0;
        }
      }
    } catch (e) {
      _log('[WhisperSlide][err] $e');
    } finally {
      if (mounted) setState(() => _busyWhisper = false);
    }
  }

  void _appendSlidingText(String t) {
    final String newText = t.trim();
    if (newText.isEmpty) return;
    // Skip identical repeat
    if (newText == _lastSlideText) return;
    _lastSlideText = newText;
    // Deduplicate overlap with tail of existing transcript
    const int maxOverlap = 64;
    final String tail = _liveTranscript.length <= maxOverlap
        ? _liveTranscript
        : _liveTranscript.substring(_liveTranscript.length - maxOverlap);
    int overlap = 0;
    final int limit = math.min(tail.length, newText.length);
    for (int k = limit; k > 0; k--) {
      if (tail.endsWith(newText.substring(0, k))) { overlap = k; break; }
    }
    final String appendPart = newText.substring(overlap);
    if (_liveTranscript.isNotEmpty && appendPart.isNotEmpty && !appendPart.startsWith(' ')) {
      _liveTranscript += ' ';
    }
    _liveTranscript += appendPart;
  }

  Widget _buildTranscriptPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Transkrip sliding', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (_slidingWhisper)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Aktif', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() { _liveTranscript = ''; _lastSlideText = ''; }),
              child: const Text('Bersihkan'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 60, maxHeight: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: SingleChildScrollView(
            child: Text(
              _liveTranscript.isEmpty ? '(kosong)' : _liveTranscript,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  // Trim silence using short-frame VAD and normalize to target RMS for Whisper.
  // Returns possibly empty list if no voiced audio detected.
  List<int> _applyTrimAndNormalizeForWhisper(List<int> input) {
    if (input.isEmpty) return const <int>[];

    List<int> work = input;

    // --- Trimming: pick the main voiced region in the last 5s window ---
    if (_trimSilence) {
      // Frame config: 20 ms frames with small gap bridging
      const int frameLen = 320; // 20ms @ 16kHz
      const int padPreMs = 100, padPostMs = 200; // keep some context
      final int padPre = (padPreMs * _sr) ~/ 1000;
      final int padPost = (padPostMs * _sr) ~/ 1000;

      int nFrames = work.length ~/ frameLen;
      if (nFrames == 0) return const <int>[];

      // Determine threshold using noise baseline when available.
      double? noiseDb;
      if (_noiseRmsRaw != null && _noiseRmsRaw! > 0) {
        noiseDb = 20.0 * math.log(_noiseRmsRaw!.clamp(1e-9, 1.0)) / math.ln10;
      }
  final double rmsDbMin = -36.0; // absolute guard
  final double enterSnrDb = 6.0; // hysteresis (exit uses separate check)

      bool isVoicedFrame(int fi) {
        int start = fi * frameLen;
        int end = start + frameLen;
        if (end > work.length) end = work.length;
        double sum2 = 0.0;
        for (int i = start; i < end; i++) {
          final double x = work[i] / 32768.0;
          sum2 += x * x;
        }
        final double rms = math.sqrt(math.max(1e-12, sum2 / math.max(1, end - start)));
        final double db = 20.0 * math.log(rms) / math.ln10;
        if (noiseDb != null && _vadEnabled) {
          final double snrDb = db - noiseDb;
          return (snrDb > enterSnrDb && db > rmsDbMin);
        }
        return db > rmsDbMin; // fallback when no baseline
      }

      // Build voiced mask with hysteresis and allow small gaps bridging
      final List<bool> mask = List.filled(nFrames, false);
      bool state = false; int offStreak = 0, onStreak = 0;
      for (int f = 0; f < nFrames; f++) {
        final voiced = isVoicedFrame(f);
        if (state) {
          // stay on until strong off evidence
          if (!voiced) {
            offStreak++;
            if (offStreak >= 2) { state = false; offStreak = 0; }
          } else {
            offStreak = 0;
          }
        } else {
          if (voiced) {
            onStreak++;
            if (onStreak >= 1) { state = true; onStreak = 0; }
          } else {
            onStreak = 0;
          }
        }
        mask[f] = state;
      }

      // Bridge tiny gaps (<=1 frame) and remove tiny islands (<3 frames)
      for (int f = 1; f + 1 < nFrames; f++) {
        if (!mask[f] && mask[f - 1] && mask[f + 1]) mask[f] = true;
      }
      int runStart = -1, bestStart = -1, bestLen = 0;
      for (int f = 0; f < nFrames; f++) {
        if (mask[f]) {
          if (runStart < 0) runStart = f;
        } else if (runStart >= 0) {
          final int len = f - runStart;
          if (len > bestLen) { bestLen = len; bestStart = runStart; }
          runStart = -1;
        }
      }
      if (runStart >= 0) {
        final int len = nFrames - runStart;
        if (len > bestLen) { bestLen = len; bestStart = runStart; }
      }

      if (bestLen == 0 || bestStart < 0) {
        // No voiced region
        work = const <int>[];
      } else {
        int s = bestStart * frameLen - padPre;
        int e = (bestStart + bestLen) * frameLen + padPost;
        if (s < 0) s = 0;
        if (e > work.length) e = work.length;
        // Avoid returning too short clips
        if (e - s < frameLen * 3) {
          work = const <int>[];
        } else {
          work = work.sublist(s, e);
        }
      }
    }

    if (work.isEmpty) return const <int>[];

    // --- Normalization: aim for target RMS without clipping ---
    if (_normalizeForWhisper) {
      double sum2 = 0.0; int peak = 1;
      for (final v in work) {
        final int a = v.abs();
        if (a > peak) peak = a;
        final double x = v / 32768.0;
        sum2 += x * x;
      }
      final double rms = math.sqrt(math.max(1e-12, sum2 / work.length));
      final double db = 20.0 * math.log(rms) / math.ln10;
      final double desired = _targetRmsDb; // e.g., -15 dBFS
      final double gainDb = (desired - db).clamp(-24.0, 24.0);
      double lin = math.pow(10.0, gainDb / 20.0).toDouble();
      final double maxLin = 0.99 * 32767.0 / peak;
      if (!maxLin.isFinite || maxLin <= 0) lin = 1.0; else lin = math.min(lin, maxLin);

      if (lin != 1.0) {
        final List<int> out = List.filled(work.length, 0);
        for (int i = 0; i < work.length; i++) {
          final double y = (work[i] * lin).clamp(-32767.0, 32767.0);
          out[i] = y.round();
        }
        work = out;
      }
    }

    return work;
  }

  Uint8List _encodeWavPcm16(List<int> samples, {required int sampleRate, required int channels}) {
    final int byteRate = sampleRate * channels * 2;
    final int blockAlign = channels * 2;
    final int dataSize = samples.length * 2;
    final int fmtChunkSize = 16;
    final int riffChunkSize = 4 + (8 + fmtChunkSize) + (8 + dataSize);

    final bytes = BytesBuilder();
    void putStr(String s) => bytes.add(s.codeUnits);
    void putU32(int v) {
      bytes.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    }
    void putU16(int v) {
      bytes.add([v & 0xFF, (v >> 8) & 0xFF]);
    }

    // RIFF header
    putStr('RIFF');
    putU32(riffChunkSize);
    putStr('WAVE');
    // fmt chunk
    putStr('fmt ');
    putU32(fmtChunkSize);
    putU16(1); // PCM
    putU16(channels);
    putU32(sampleRate);
    putU32(byteRate);
    putU16(blockAlign);
    putU16(16); // bits per sample
    // data chunk
    putStr('data');
    putU32(dataSize);
    // samples little-endian
    for (final s in samples) {
      final v = s & 0xFFFF;
      bytes.add([v & 0xFF, (v >> 8) & 0xFF]);
    }
    return bytes.toBytes();
  }

  Future<void> _saveTranscript() async {
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File(p.join(dir.path, 'transcript_${ts}.txt'));
      await file.writeAsString(_liveTranscript);
      if (mounted) _showSnack('Transkrip disimpan: ${file.path}');
    } catch (e) {
      if (mounted) _showSnack('Gagal simpan transkrip: $e');
    }
  }
}

class _WaveformPlaceholder extends StatefulWidget {
  const _WaveformPlaceholder({required this.active});
  final bool active;

  @override
  State<_WaveformPlaceholder> createState() => _WaveformPlaceholderState();
}

class _WaveformPlaceholderState extends State<_WaveformPlaceholder> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.active) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _WaveformPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    if (!widget.active && _ctrl.isAnimating) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 84,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return CustomPaint(
            painter: _WavePainter(_anim.value, theme.colorScheme.primary, active: widget.active),
            size: const Size(double.infinity, 84),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.color, {required this.active});
  final double t;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(active ? 0.85 : 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;
    final path = Path();
    const waves = 3;
    final amp = active ? 16.0 : 6.0;
    for (int w = 0; w < waves; w++) {
      final phase = t * 2 * 3.14159 + w * 1.2;
      path.reset();
      path.moveTo(0, midY);
      for (double x = 0; x <= size.width; x += 6) {
        final y = midY + amp *
            (0.7 * math.sin((x / 36) + phase) + 0.3 * math.sin((x / 15) - phase));
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.t != t || oldDelegate.active != active;
}

class _SpectrumWithAdvice extends StatelessWidget {
  const _SpectrumWithAdvice({required this.active, required this.bands, required this.level, required this.advice, required this.adviceColor});
  final bool active;
  final List<double> bands;
  final double level;
  final String advice;
  final Color adviceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!active) return _WaveformPlaceholder(active: false);
    return SizedBox(
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: _SpectrumPainter(
              bands: bands,
              level: level,
              color: theme.colorScheme.primary,
              gridColor: theme.dividerColor.withOpacity(0.15),
            ),
            size: const Size(double.infinity, 84),
          ),
          Positioned(
            right: 8,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: adviceColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: adviceColor.withOpacity(0.35)),
              ),
              child: Text(advice, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: adviceColor, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.bands, required this.level, required this.color, required this.gridColor});
  final List<double> bands; // 0..1
  final double level; // 0..1
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      bg,
    );

    // Grid lines
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final int hLines = 3;
    for (int i = 1; i <= hLines; i++) {
      final y = size.height * (i / (hLines + 1));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final int n = bands.length;
    final double gap = 2.0;
    final double barW = (size.width - gap * (n - 1)) / n;
    final double maxH = size.height - 6; // padding for round caps

    for (int i = 0; i < n; i++) {
      final double v = bands[i].clamp(0.0, 1.0);
      final double h = v * maxH;
      final double x = i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(3),
      );
      final Paint p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.9),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, p);
    }

    // Draw level indicator as a thin line at overall RMS
    final double lvl = (level.clamp(0.0, 1.0)) * maxH;
    final Paint lvlPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2;
    final double y = size.height - lvl;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), lvlPaint);
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return !listEquals(oldDelegate.bands, bands) || oldDelegate.level != level || oldDelegate.color != color;
  }
}

// end
