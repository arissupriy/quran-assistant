import 'package:hive/hive.dart';

part 'reading_session.g.dart';

@HiveType(typeId: 3)
class ReadingSession extends HiveObject {
  @HiveField(0)
  final int page;

  @HiveField(1)
  final DateTime openedAt;

  @HiveField(2)
  final DateTime closedAt;

  @HiveField(3)
  final int? previousPage;

  @HiveField(4)
  final DateTime date; // Only date part

  ReadingSession({
    required this.page,
    required this.openedAt,
    required this.closedAt,
    this.previousPage,
    required this.date,
  });

  Duration get duration => closedAt.difference(openedAt);

  ReadingSession copyWith({
    int? page,
    DateTime? openedAt,
    DateTime? closedAt,
    int? previousPage,
    DateTime? date,
  }) {
    return ReadingSession(
      page: page ?? this.page,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      previousPage: previousPage ?? this.previousPage,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt.toIso8601String(),
        'previousPage': previousPage,
        'date': date.toIso8601String(),
      };
}
