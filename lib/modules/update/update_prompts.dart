import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/design_tokens.dart';
import '../../routes/app_router.dart';
import '../../services/update/app_update_models.dart';
import '../../services/update/update_service.dart';
import '../../widgets/game_dialog.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

/// Update dialogs. Automatic prompts appear only on the Home screen, never
/// over a puzzle in progress.
class UpdatePrompts {
  UpdatePrompts._();

  static bool _showing = false;

  static UpdateService? get _service => Get.isRegistered<UpdateService>()
      ? Get.find<UpdateService>()
      : null;

  static bool get _onHomeWithNothingOnTop =>
      Get.currentRoute == AppRoutes.home && !(Get.isDialogOpen ?? false);

  /// Call when Home becomes visible: runs the once-per-session check and
  /// shows at most one prompt.
  static Future<void> onHomeVisible() async {
    final s = _service;
    if (s == null || !s.isSupported) return;
    await s.autoCheck();
    if (_showing || !_onHomeWithNothingOnTop) return;
    if (s.shouldPromptRestart) {
      s.markRestartPrompted();
      await showRestartDialog();
    } else if (s.shouldAutoPrompt) {
      s.markPrompted();
      await showUpdateDialog();
    }
  }

  /// Optional or required prompt for the update Play reported.
  static Future<void> showUpdateDialog() async {
    final s = _service;
    final d = s?.decision;
    if (s == null || d == null) return;
    await _guard(() => Get.dialog<void>(
          d.required
              ? _RequiredUpdateDialog(service: s)
              : _OptionalUpdateDialog(service: s, decision: d),
          barrierDismissible: !d.required,
        ));
  }

  static Future<void> showRestartDialog() async {
    final s = _service;
    if (s == null) return;
    await _guard(() => Get.dialog<void>(_RestartDialog(service: s)));
  }

  /// Manual "Check for Updates" from Settings: always reports an outcome.
  static Future<void> checkFromSettings() async {
    final s = _service;
    if (s == null || !s.isSupported) return;
    if (s.status.value == UpdateStatus.downloaded) return showRestartDialog();
    if (s.status.value == UpdateStatus.downloading ||
        s.status.value == UpdateStatus.installing) {
      return _guard(() => Get.dialog<void>(_InfoDialog(
            icon: Icons.downloading_rounded,
            color: AppColors.accentBlue,
            title: AppStrings.updateDownloading,
            body: AppStrings.updateAvailableBody,
          )));
    }

    Get.dialog<void>(const _CheckingDialog(), barrierDismissible: false);
    await s.checkForUpdate();
    if (Get.isDialogOpen ?? false) Get.back<void>();

    switch (s.status.value) {
      case UpdateStatus.available:
        if (s.decision != null) {
          s.markPrompted();
          return showUpdateDialog();
        }
        return _showCheckFailed(unavailable: true);
      case UpdateStatus.downloading:
      case UpdateStatus.installing:
        return;
      case UpdateStatus.downloaded:
        return showRestartDialog();
      case UpdateStatus.upToDate:
        return _guard(() => Get.dialog<void>(const _InfoDialog(
              icon: Icons.verified_rounded,
              color: AppColors.success,
              title: AppStrings.upToDateTitle,
              body: AppStrings.upToDateBody,
            )));
      case UpdateStatus.unavailable:
      case UpdateStatus.unsupported:
        return _showCheckFailed(unavailable: true);
      case UpdateStatus.failed:
      case UpdateStatus.idle:
      case UpdateStatus.checking:
        return _showCheckFailed(unavailable: false);
    }
  }

  static Future<void> _showCheckFailed({required bool unavailable}) {
    return _guard(() => Get.dialog<void>(_InfoDialog(
          icon: Icons.cloud_off_rounded,
          color: AppColors.warning,
          title: AppStrings.updateCheckFailedTitle,
          body: unavailable
              ? AppStrings.updateCheckUnavailable
              : AppStrings.updateCheckOffline,
          showStoreButton: true,
        )));
  }

  /// Opens this app's Play Store listing (fallback when the in-app flow is
  /// not available). Returns false if nothing could open it.
  static Future<bool> openPlayStore() async {
    final s = _service;
    if (s == null) return false;
    final uri = playStoreUri(await s.storePackageName());
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _guard(Future<void> Function() show) async {
    if (_showing) return;
    _showing = true;
    try {
      await show();
    } finally {
      _showing = false;
    }
  }
}

class _OptionalUpdateDialog extends StatefulWidget {
  final UpdateService service;
  final UpdateDecision decision;

  const _OptionalUpdateDialog({required this.service, required this.decision});

  @override
  State<_OptionalUpdateDialog> createState() => _OptionalUpdateDialogState();
}

class _OptionalUpdateDialogState extends State<_OptionalUpdateDialog> {
  bool _busy = false;
  bool _failed = false;
  bool _decided = false;

  @override
  void dispose() {
    // Dismissed without choosing (tap outside / back) counts as "Later".
    if (!_decided) widget.service.snooze();
    super.dispose();
  }

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result = await widget.service.startUpdate();
    if (!mounted) return;
    if (result == UpdateFlowResult.failed) {
      setState(() {
        _busy = false;
        _failed = true;
      });
      return;
    }
    // Accepted: downloading (Home shows progress). Canceled: the service
    // already recorded it as "Later".
    _decided = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final flexible = widget.decision.type == UpdateType.flexible;
    return GameDialog(
      icon: const DialogIcon(
        icon: Icons.system_update_rounded,
        color: AppColors.accentBlue,
      ),
      title: const Text(AppStrings.updateAvailableTitle),
      message: Text(
        _failed
            ? AppStrings.updateFailed
            : (flexible
                ? AppStrings.updateAvailableBody
                : AppStrings.updateAvailableBodyImmediate),
      ),
      children: [
        PrimaryButton(
          label: AppStrings.updateNow,
          icon: Icons.download_rounded,
          width: double.infinity,
          loading: _busy,
          onTap: _busy ? null : _update,
        ),
        if (_failed) ...[
          const SizedBox(height: AppSpacing.sm),
          const _StoreButton(),
        ],
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: AppStrings.updateLater,
          textColor: AppColors.textSecondary,
          borderColor: AppColors.cardBorder,
          onTap: _busy
              ? null
              : () {
                  _decided = true;
                  widget.service.snooze();
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

/// Shown when Play marks the update as required. Cannot be dismissed; it
/// stays until the player starts the update (Play then takes over the screen
/// and restarts the app once installed).
class _RequiredUpdateDialog extends StatefulWidget {
  final UpdateService service;

  const _RequiredUpdateDialog({required this.service});

  @override
  State<_RequiredUpdateDialog> createState() => _RequiredUpdateDialogState();
}

class _RequiredUpdateDialogState extends State<_RequiredUpdateDialog> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final result =
        await widget.service.startUpdate(type: UpdateType.immediate);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = result == UpdateFlowResult.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GameDialog(
        icon: const DialogIcon(
          icon: Icons.system_update_rounded,
          color: AppColors.accentPurple,
        ),
        title: const Text(AppStrings.updateRequiredTitle),
        message: Text(
          _failed ? AppStrings.updateFailed : AppStrings.updateRequiredBody,
        ),
        children: [
          PrimaryButton(
            label: AppStrings.updateNow,
            icon: Icons.download_rounded,
            width: double.infinity,
            loading: _busy,
            onTap: _busy ? null : _update,
          ),
          if (_failed) ...[
            const SizedBox(height: AppSpacing.sm),
            const _StoreButton(),
          ],
        ],
      ),
    );
  }
}

class _RestartDialog extends StatefulWidget {
  final UpdateService service;

  const _RestartDialog({required this.service});

  @override
  State<_RestartDialog> createState() => _RestartDialogState();
}

class _RestartDialogState extends State<_RestartDialog> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _restart() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    // On success Android restarts the app, so this usually never returns.
    final ok = await widget.service.completeUpdate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameDialog(
      icon: const DialogIcon(
        icon: Icons.restart_alt_rounded,
        color: AppColors.success,
      ),
      title: const Text(AppStrings.updateReadyTitle),
      message: Text(
        _failed
            ? AppStrings.updateFailed
            : (_busy
                ? AppStrings.updateInstalling
                : AppStrings.updateReadyBody),
      ),
      children: [
        PrimaryButton(
          label: AppStrings.updateRestart,
          icon: Icons.restart_alt_rounded,
          gradient: AppGradients.reward,
          width: double.infinity,
          loading: _busy,
          onTap: _busy ? null : _restart,
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: AppStrings.updateLater,
          textColor: AppColors.textSecondary,
          borderColor: AppColors.cardBorder,
          onTap: _busy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _InfoDialog extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool showStoreButton;

  const _InfoDialog({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.showStoreButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return GameDialog(
      icon: DialogIcon(icon: icon, color: color),
      title: Text(title),
      message: Text(body),
      children: [
        if (showStoreButton) ...[
          const _StoreButton(primary: true),
          const SizedBox(height: AppSpacing.sm),
        ],
        SecondaryButton(
          label: AppStrings.close,
          textColor: AppColors.textSecondary,
          borderColor: AppColors.cardBorder,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: GameDialog(
        icon: DialogIcon(
          icon: Icons.system_update_rounded,
          color: AppColors.accentBlue,
        ),
        title: Text(AppStrings.checkingForUpdates),
        children: [
          Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Update on Google Play": opens the store listing for this package.
class _StoreButton extends StatelessWidget {
  final bool primary;

  const _StoreButton({this.primary = false});

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return PrimaryButton(
        label: AppStrings.updateOnPlay,
        icon: Icons.shop_rounded,
        width: double.infinity,
        onTap: UpdatePrompts.openPlayStore,
      );
    }
    return SecondaryButton(
      label: AppStrings.updateOnPlay,
      icon: Icons.shop_rounded,
      onTap: UpdatePrompts.openPlayStore,
    );
  }
}
