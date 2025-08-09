// lib/pages/more_page.dart
import 'dart:async';
import 'dart:io' show Platform, File;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quran_assistant/src/rust/api/recorder.dart' as rec;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> with SingleTickerProviderStateMixin {
  bool _recording = false;
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
  double _rmsDb = -160.0;
  double _peakDb = -160.0;
  double _dcOffset = 0.0;
  double _zcr = 0.0; // 0..1 fraction per chunk
  double? _snrDb; // requires calibration
  // Rolling history (last ~5s at 90ms per window, ~55 windows)
  final List<double> _rmsHist = <double>[];
  final List<double> _clipHist = <double>[];
  final List<double> _zcrHist = <double>[];
  int _logCounter = 0;
  // Noise calibration
  bool _calibrating = false;
  int _calibSamplesLeft = 0;
  double _noiseSum2 = 0.0;
  int _noiseNSamples = 0;
  double? _noiseRms;
  // Software gain & limiter (post-capture, pre-visual/metrics/WAV)
  double _gainDb = 12.0; // adjustable 0..24 dB
  bool _softLimit = true;
  // High-pass filter state (first-order) and Auto-Gain Control (AGC)
  double _hpX1 = 0.0;
  double _hpY1 = 0.0;
  bool _autoGain = false;
  double _targetRmsDb = -15.0; // aim around -15 dBFS
  double _agcDb = 0.0; // dynamic adjustment added to _gainDb
  // Verbose logging
  bool _verboseLog = false;

  @override
  void dispose() {
    _poller?.cancel();
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
  await rec.recorderStart(sampleRate: _sr);
  // reset processing states
  _hpX1 = 0.0; _hpY1 = 0.0; _agcDb = 0.0;
  // ignore: avoid_print
  print('[AudioStart] sr=$_sr, gainDb=${_gainDb.toStringAsFixed(1)}, limiter=$_softLimit, autoGain=$_autoGain,'
    ' hpCut=70Hz, targetRmsDb=${_targetRmsDb.toStringAsFixed(1)}, fft=$_fftSize, bands=$_numBands, ring=$_ringSize');
      setState(() => _recording = true);
      // Poll frequently for smoother spectrum
      _poller = Timer.periodic(const Duration(milliseconds: 90), (_) async {
        final chunk = await rec.recorderTakeSamples();
        if (chunk.isNotEmpty) {
          // Update counters
          _totalSamples += chunk.length;
          // Push into ring buffer
          final double appliedDb = (_autoGain ? (_gainDb + _agcDb) : _gainDb).clamp(0.0, 30.0);
          final double gainLin = math.pow(10.0, appliedDb / 20.0).toDouble();
          // High-pass coefficient (first-order): y[n] = a*(y[n-1] + x[n] - x[n-1])
          const double hpCut = 70.0; // Hz
          final double rc = 1.0 / (2 * math.pi * hpCut);
          final double dt = 1.0 / _sr;
          final double a = rc / (rc + dt);
          for (int i = 0; i < chunk.length; i++) {
            // high-pass first to reduce DC/rumble, then apply gain and limiter
            final double xin = (chunk[i] / 32768.0);
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
          final double peak = maxAbs;
          final double dbRms = 20.0 * math.log(rms) / math.ln10; // dBFS
          final double dbPeak = 20.0 * math.log(math.max(1e-12, peak)) / math.ln10;
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
            _noiseSum2 += sum2;
            _noiseNSamples += chunk.length;
            if (_calibSamplesLeft <= 0) {
              _calibrating = false;
              final double noiseRms = math.sqrt(math.max(1e-12, _noiseSum2 / math.max(1, _noiseNSamples)));
              _noiseRms = noiseRms;
              _snrDb = 20.0 * math.log(rms / noiseRms) / math.ln10;
              _noiseSum2 = 0.0; _noiseNSamples = 0; _calibSamplesLeft = 0;
              // Quick console summary
              // ignore: avoid_print
              print('[AudioCalib] noiseRms=${(20*math.log(noiseRms)/math.ln10).toStringAsFixed(1)} dBFS');
            }
          } else if (_noiseRms != null) {
            _snrDb = 20.0 * math.log(rms / (_noiseRms!.clamp(1e-9, 1.0))) / math.ln10;
          }

          // Periodic console log for debugging
          if ((_logCounter++ % 12) == 0) {
            final avgClip = _clipHist.isEmpty ? 0.0 : _clipHist.reduce((a,b)=>a+b) / _clipHist.length;
            final avgRms = _rmsHist.isEmpty ? _rmsDb : _rmsHist.reduce((a,b)=>a+b) / _rmsHist.length;
            // ignore: avoid_print
            print('[AudioDiag] RMS=${avgRms.toStringAsFixed(1)} dBFS, Peak=${_peakDb.toStringAsFixed(1)} dBFS, '
                  'Clip=${(avgClip*100).toStringAsFixed(2)}%, DC=${(_dcOffset*1000).toStringAsFixed(2)}‰, '
                  'ZCR=${(_zcr*100).toStringAsFixed(1)}%, SNR=${_snrDb?.toStringAsFixed(1) ?? '-'} dB');
          }
          if (_verboseLog) {
            // Detailed per-chunk snapshot
            final appliedDb = (_autoGain ? (_gainDb + _agcDb) : _gainDb).clamp(0.0, 30.0);
            // ignore: avoid_print
            print('[AudioDetail] chunk=${chunk.length}, appliedDb=${appliedDb.toStringAsFixed(1)} (base=${_gainDb.toStringAsFixed(1)}, agc=${_agcDb.toStringAsFixed(1)}), '
                  'RMS=${_rmsDb.toStringAsFixed(1)} dBFS, Peak=${_peakDb.toStringAsFixed(1)} dBFS, ClipNow=${(clipFrac*100).toStringAsFixed(2)}%, '
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
  // ignore: avoid_print
  try {
    final avgClip = _clipHist.isEmpty ? 0.0 : _clipHist.reduce((a,b)=>a+b) / _clipHist.length;
    final avgRms = _rmsHist.isEmpty ? _rmsDb : _rmsHist.reduce((a,b)=>a+b) / _rmsHist.length;
    print('[AudioStop] totalSamples=$_totalSamples, duration=${_formatDuration(_totalSamples)}, '
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
                                    Text('Verbose log', style: theme.textTheme.labelMedium),
                                    Switch(
                                      value: _verboseLog,
                                      onChanged: (v) => setState(() => _verboseLog = v),
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
    final snrText = _snrDb == null ? '—' : '${_snrDb!.isFinite ? _snrDb!.toStringAsFixed(1) : '-'} dB';
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
                  _noiseSum2 = 0.0;
                  _noiseNSamples = 0;
                  _noiseRms = null; // will be filled
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
              label: const Text('Simpan 5s WAV'),
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
