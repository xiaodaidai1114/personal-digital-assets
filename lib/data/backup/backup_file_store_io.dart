import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_file_store.dart';

/// 移动端/桌面：导出写入应用文档目录后调起分享面板；导入用系统文件选择器。
BackupFileStore createBackupFileStore() => ShareBackupFileStore();

class ShareBackupFileStore implements BackupFileStore {
  @override
  Future<String> exportFile(String content, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(content, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return filename;
  }

  @override
  Future<String?> pickAndRead() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['avbak', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    if (file.bytes != null) {
      return String.fromCharCodes(file.bytes!);
    }
    final path = file.path;
    if (path == null) {
      return null;
    }
    return File(path).readAsString();
  }
}
