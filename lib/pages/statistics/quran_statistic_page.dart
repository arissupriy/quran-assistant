import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart'; // Import provider dari sini saja
import 'package:shimmer/shimmer.dart'; // Import package shimmer

// DEFINISI allReadingSessionsStreamProvider TELAH DIHAPUS DARI SINI.
// Provider ini sudah didefinisikan di 'package:quran_assistant/providers/reading_session_provider.dart'.


class QuranStatisticPage extends ConsumerStatefulWidget {
  const QuranStatisticPage({super.key});

  @override
  ConsumerState<QuranStatisticPage> createState() => _QuranStatisticPageState();
}

class _QuranStatisticPageState extends ConsumerState<QuranStatisticPage> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
    String twoDigitSeconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}j ${twoDigitMinutes}m";
    } else if (duration.inMinutes > 0) {
      return "${twoDigitMinutes}m ${twoDigitSeconds}d";
    } else {
      return "${twoDigits(duration.inSeconds)}d";
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.cardColor,
              onSurface: AppTheme.textColor,
            ),
            dialogBackgroundColor: AppTheme.cardColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _resetDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  String _getComparisonMessage(Duration todayDuration, Duration yesterdayDuration) {
    if (todayDuration.inSeconds == 0 && yesterdayDuration.inSeconds == 0) {
      return 'Anda belum mulai membaca. Ayo semangat!';
    } else if (todayDuration.inSeconds > 0 && yesterdayDuration.inSeconds == 0) {
      return 'Hebat! Anda mulai membaca hari ini. Pertahankan!';
    } else if (todayDuration.inSeconds == 0 && yesterdayDuration.inSeconds > 0) {
      return 'Anda belum membaca hari ini. Mari lanjutkan semangat kemarin!';
    }

    double todaySeconds = todayDuration.inSeconds.toDouble();
    double yesterdaySeconds = yesterdayDuration.inSeconds.toDouble();

    if (todaySeconds > yesterdaySeconds) {
      double percentageIncrease = ((todaySeconds - yesterdaySeconds) / yesterdaySeconds) * 100;
      return 'Luar biasa! Anda membaca ${percentageIncrease.toStringAsFixed(0)}% lebih banyak dari hari kemarin.';
    } else if (todaySeconds < yesterdaySeconds) {
      double percentageDecrease = ((yesterdaySeconds - todaySeconds) / yesterdaySeconds) * 100;
      return 'Anda membaca ${percentageDecrease.toStringAsFixed(0)}% lebih sedikit dari hari kemarin. Ayo tingkatkan lagi!';
    } else {
      return 'Progres bacaan Anda konsisten dengan hari kemarin. Terus istiqomah!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ReadingSession>> readingSessionsAsync = ref.watch(allReadingSessionsStreamProvider);
    final AsyncValue<Map<DateTime, Duration>> dailyDurationsAsync = ref.watch(dailyReadingDurationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Statistik Bacaan',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.iconColor),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_rounded, color: AppTheme.iconColor),
            tooltip: 'Pilih Tanggal',
            onPressed: () => _pickDate(context),
          ),
          if (_selectedDate != null)
            IconButton(
              icon: Icon(Icons.clear_all_rounded, color: AppTheme.iconColor),
              tooltip: 'Reset Filter',
              onPressed: _resetDateFilter,
            ),
        ],
        bottom: _selectedDate != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight / 2),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Filter: ${DateFormat('dd MMMM yyyy').format(_selectedDate!)}',
                    style: TextStyle(fontSize: 16, color: AppTheme.textColor.withOpacity(0.8)),
                  ),
                ),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        key: ValueKey(
          '${readingSessionsAsync.isLoading}-${readingSessionsAsync.hasError}-${_selectedDate.toString()}-${readingSessionsAsync.value?.length ?? 0}',
        ),
        child: readingSessionsAsync.when(
          loading: () => const ShimmerLoadingStatisticPage(key: ValueKey('loading')),
          error: (err, stack) => Center(
            key: ValueKey('error'),
            child: Text(
              'Error memuat statistik: ${err.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (allSessions) {
            final filteredSessions = _selectedDate == null
                ? allSessions
                : allSessions.where((session) {
                    final sessionDate = DateTime(session.date.year, session.date.month, session.date.day);
                    return sessionDate.isAtSameMomentAs(_selectedDate!);
                  }).toList();

            final totalDuration = filteredSessions.fold(
              Duration.zero,
              (sum, session) => sum + session.duration,
            );
            final totalPagesRead = filteredSessions.map((s) => s.page).toSet().length;
            final totalSessions = filteredSessions.length;
            final averageSessionDuration = filteredSessions.isNotEmpty
                ? totalDuration ~/ filteredSessions.length
                : Duration.zero;

            Duration todayDuration = Duration.zero;
            Duration yesterdayDuration = Duration.zero;
            
            dailyDurationsAsync.whenData((dailyDurations) {
              final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
              final yesterday = today.subtract(const Duration(days: 1));
              
              todayDuration = dailyDurations[today] ?? Duration.zero;
              yesterdayDuration = dailyDurations[yesterday] ?? Duration.zero;
            });

            return SingleChildScrollView(
              key: ValueKey('data-${_selectedDate.toString()}'),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedDate == null || _selectedDate!.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)))
                    Card(
                      color: AppTheme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.compare_arrows_rounded, color: AppTheme.primaryColor, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Perbandingan Hari Ini',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getComparisonMessage(todayDuration, yesterdayDuration),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  Card(
                    color: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ringkasan Progres Anda',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow(
                            context,
                            Icons.timer_rounded,
                            'Total Waktu Baca:',
                            _formatDuration(totalDuration),
                            Colors.white,
                          ),
                          _buildStatRow(
                            context,
                            Icons.menu_book_rounded,
                            'Total Halaman Unik Dibaca:',
                            '$totalPagesRead halaman',
                            Colors.white,
                          ),
                          _buildStatRow(
                            context,
                            Icons.history_rounded,
                            'Total Sesi Baca:',
                            '$totalSessions sesi',
                            Colors.white,
                          ),
                          _buildStatRow(
                            context,
                            Icons.av_timer_rounded,
                            'Durasi Sesi Rata-rata:',
                            _formatDuration(averageSessionDuration),
                            Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Riwayat Sesi Bacaan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (filteredSessions.isEmpty)
                    Center(
                      child: Text(
                        'Tidak ada riwayat sesi bacaan untuk tanggal ini.',
                        style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredSessions.length,
                      itemBuilder: (context, index) {
                        final session = filteredSessions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          color: AppTheme.cardColor,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                              child: Text(
                                '${session.page}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                ),
                              ),
                            ),
                            title: Text(
                              'Halaman ${session.page}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor),
                            ),
                            subtitle: Text(
                              'Tanggal: ${DateFormat('dd MMM yyyy').format(session.date)}\nWaktu: ${DateFormat('HH:mm').format(session.openedAt)} - ${DateFormat('HH:mm').format(session.closedAt)}\nDurasi: ${_formatDuration(session.duration)}',
                              style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Membuka Halaman ${session.page}')),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper widget untuk membangun baris statistik
  Widget _buildStatRow(BuildContext context, IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.9)),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHIMMER LOADING WIDGET
// =============================================================================
class ShimmerLoadingStatisticPage extends StatelessWidget {
  const ShimmerLoadingStatisticPage({super.key});

  // Helper untuk membuat placeholder baris teks shimmer
  Widget _buildShimmerLine({double width = double.infinity, double height = 14.0, double borderRadius = 4.0}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shimmer untuk Kartu Perbandingan
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: Colors.grey.shade400, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildShimmerLine(width: 150),
                          const SizedBox(height: 8),
                          _buildShimmerLine(width: double.infinity),
                          const SizedBox(height: 4),
                          _buildShimmerLine(width: double.infinity),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Shimmer untuk Kartu Ringkasan Statistik
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShimmerLine(width: 200),
                    const SizedBox(height: 16),
                    _buildShimmerLine(width: double.infinity),
                    const SizedBox(height: 12),
                    _buildShimmerLine(width: double.infinity),
                    const SizedBox(height: 12),
                    _buildShimmerLine(width: double.infinity),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Shimmer untuk Judul Riwayat Sesi
            _buildShimmerLine(width: 180),
            const SizedBox(height: 12),

            // Shimmer untuk Daftar Riwayat Sesi
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildShimmerLine(width: 100),
                              const SizedBox(height: 4),
                              _buildShimmerLine(width: double.infinity),
                              const SizedBox(height: 4),
                              _buildShimmerLine(width: 150),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
