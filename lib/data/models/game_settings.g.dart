// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameSettingsAdapter extends TypeAdapter<GameSettings> {
  @override
  final int typeId = 1;

  @override
  GameSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameSettings(
      soundOn: fields[0] as bool,
      musicOn: fields[1] as bool,
      hapticsOn: fields[2] as bool,
      notificationsOn: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GameSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.soundOn)
      ..writeByte(1)
      ..write(obj.musicOn)
      ..writeByte(2)
      ..write(obj.hapticsOn)
      ..writeByte(3)
      ..write(obj.notificationsOn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
