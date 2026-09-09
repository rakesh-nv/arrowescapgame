import 'package:hive/hive.dart';
import '../../core/constants/app_constants.dart';

part 'game_settings.g.dart';

@HiveType(typeId: AppConstants.gameSettingsTypeId)
class GameSettings extends HiveObject {
  @HiveField(0)
  bool soundOn;

  @HiveField(1)
  bool musicOn;

  @HiveField(2)
  bool hapticsOn;

  @HiveField(3)
  bool notificationsOn;

  GameSettings({
    this.soundOn = true,
    this.musicOn = true,
    this.hapticsOn = true,
    this.notificationsOn = true,
  });

  GameSettings copyWith({
    bool? soundOn,
    bool? musicOn,
    bool? hapticsOn,
    bool? notificationsOn,
  }) {
    return GameSettings(
      soundOn: soundOn ?? this.soundOn,
      musicOn: musicOn ?? this.musicOn,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      notificationsOn: notificationsOn ?? this.notificationsOn,
    );
  }
}
