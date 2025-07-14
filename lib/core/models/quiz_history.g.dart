// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuizSessionAdapter extends TypeAdapter<QuizSession> {
  @override
  final int typeId = 0;

  @override
  QuizSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizSession(
      sessionId: fields[0] as String,
      userId: fields[1] as String,
      quizType: fields[2] as String,
      scopeType: fields[3] as String,
      scopeDetailsJson: fields[4] as String,
      requestedQuestionCount: fields[5] as int,
      actualQuestionCount: fields[6] as int,
      startTime: fields[7] as DateTime,
      endTime: fields[8] as DateTime,
      totalDurationSeconds: fields[9] as int,
      correctAnswersCount: fields[10] as int,
      incorrectAnswersCount: fields[11] as int,
    );
  }

  @override
  void write(BinaryWriter writer, QuizSession obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.quizType)
      ..writeByte(3)
      ..write(obj.scopeType)
      ..writeByte(4)
      ..write(obj.scopeDetailsJson)
      ..writeByte(5)
      ..write(obj.requestedQuestionCount)
      ..writeByte(6)
      ..write(obj.actualQuestionCount)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.endTime)
      ..writeByte(9)
      ..write(obj.totalDurationSeconds)
      ..writeByte(10)
      ..write(obj.correctAnswersCount)
      ..writeByte(11)
      ..write(obj.incorrectAnswersCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuizAttemptAdapter extends TypeAdapter<QuizAttempt> {
  @override
  final int typeId = 1;

  @override
  QuizAttempt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuizAttempt(
      attemptId: fields[0] as String,
      sessionId: fields[1] as String,
      questionIndex: fields[2] as int,
      verseKey: fields[3] as String,
      questionTextPart1: fields[4] as String,
      questionTextPart2: fields[5] as String,
      missingPartText: fields[6] as String,
      optionsJson: fields[7] as String,
      userAnswerIndex: fields[8] as int?,
      correctAnswerIndex: fields[9] as int,
      isCorrect: fields[10] as bool,
      timeSpentSeconds: fields[11] as int,
      timestamp: fields[12] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, QuizAttempt obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.attemptId)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.questionIndex)
      ..writeByte(3)
      ..write(obj.verseKey)
      ..writeByte(4)
      ..write(obj.questionTextPart1)
      ..writeByte(5)
      ..write(obj.questionTextPart2)
      ..writeByte(6)
      ..write(obj.missingPartText)
      ..writeByte(7)
      ..write(obj.optionsJson)
      ..writeByte(8)
      ..write(obj.userAnswerIndex)
      ..writeByte(9)
      ..write(obj.correctAnswerIndex)
      ..writeByte(10)
      ..write(obj.isCorrect)
      ..writeByte(11)
      ..write(obj.timeSpentSeconds)
      ..writeByte(12)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizAttemptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HiveQuizOptionAdapter extends TypeAdapter<HiveQuizOption> {
  @override
  final int typeId = 2;

  @override
  HiveQuizOption read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveQuizOption(
      text: fields[0] as String,
      isCorrect: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveQuizOption obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.text)
      ..writeByte(1)
      ..write(obj.isCorrect);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveQuizOptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
