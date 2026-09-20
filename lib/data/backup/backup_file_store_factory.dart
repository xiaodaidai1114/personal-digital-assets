import 'backup_file_store.dart';
import 'backup_file_store_stub.dart'
    if (dart.library.html) 'backup_file_store_web.dart'
    if (dart.library.io) 'backup_file_store_io.dart'
    as impl;

/// 平台对应的备份文件存储：导出加密文件 + 选择导入。
BackupFileStore createBackupFileStore() => impl.createBackupFileStore();
