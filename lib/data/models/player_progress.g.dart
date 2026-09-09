// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_progress.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerProgressAdapter extends TypeAdapter<PlayerProgress> {
  @override
  final int typeId = 0;

  @override
  PlayerProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayerProgress(
      highestUnlockedLevel: fields[0] as int,
      levelStars: (fields[1] as Map).cast<int, int>(),
      coins: fields[2] as int,
      hints: fields[3] as int,
      currentThemeId: fields[4] as String,
      dailyStreak: fields[5] as int,
      lastDailyCompletedDate: fields[6] as String?,
      removeAds: fields[7] as bool,
      hasSeenTutorial: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PlayerProgress obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.highestUnlockedLevel)
      ..writeByte(1)
      ..write(obj.levelStars)
      ..writeByte(2)
      ..write(obj.coins)
      ..writeByte(3)
      ..write(obj.hints)
      ..writeByte(4)
      ..write(obj.currentThemeId)
      ..writeByte(5)
      ..write(obj.dailyStreak)
      ..writeByte(6)
      ..write(obj.lastDailyCompletedDate)
      ..writeByte(7)
      ..write(obj.removeAds)
      ..writeByte(8)
      ..write(obj.hasSeenTutorial);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
