import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_file_store.dart';

/// Web：导出走浏览器下载（share_plus web 行为），导入用 file_picker 的 bytes。
BackupFileStore createBackupFileStore() => _WebBackupFileStore();

class _WebBackupFileStore implements BackupFileStore {
  @override
  Future<String> exportFile(String content, String filename) async {
    final file = XFile.fromData(
      Uint8List.fromList(content.codeUnits),
      name: filename,
      mimeType: 'application/json',
    );
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
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      return null;
    }
    return String.fromCharCodes(bytes);
  }
}
