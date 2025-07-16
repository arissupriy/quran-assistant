import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart';

class ReadingStatsPage extends ConsumerWidget {
  const ReadingStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(readingSessionsGroupedByDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Baca'),
        centerTitle: true,
      ),
      body: asyncSessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (groupedSessions) {
          if (groupedSessions.isEmpty) {
            return const Center(child: Text('Belum ada sesi baca.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groupedSessions.length,
            itemBuilder: (context, index) {
              final entry = groupedSessions.entries.elementAt(index);
              final date = entry.key;
              final sessions = entry.value;
              final totalDuration = sessions.fold<Duration>(
                Duration.zero,
                (sum, s) => sum + s.duration,
              );

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total waktu baca: ${_formatDuration(totalDuration)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...sessions.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Hal. ${s.page}'),
                                Text(_formatDuration(s.duration)),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) {
      return '${d.inSeconds}s';
    } else if (d.inMinutes < 60) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
  }
}
