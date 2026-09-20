import 'data/asset_repository.dart';
import 'data/backup/backup_file_store.dart';
import 'data/reminders/bill_calendar.dart';
import 'data/reminders/reminder_scheduler.dart';
import 'data/settings_store.dart';
import 'data/app_update.dart';
import 'vault/vault_controller.dart';

/// 应用级服务装配：控制器、仓库、设置、提醒调度、备份。
class AppServices {
  AppServices({
    required this.controller,
    required this.repository,
    required this.settingsStore,
    required this.reminderScheduler,
    required this.backupFileStore,
    required this.updateChecker,
  });

  final VaultController controller;
  final AssetRepository repository;
  final SettingsStore settingsStore;
  final ReminderScheduler reminderScheduler;
  final BackupFileStore backupFileStore;
  final AppUpdateChecker updateChecker;

  /// 依据当前资产数据重排提醒通知。失败不影响主流程。
  Future<void> syncReminders() async {
    try {
      final assets = await repository.listAssets();
      final items = const ReminderPlanner().plan(assets, DateTime.now());
      await reminderScheduler.reschedule(items);
    } on Exception {
      // 通知不可用时静默降级。
    }
  }
}
