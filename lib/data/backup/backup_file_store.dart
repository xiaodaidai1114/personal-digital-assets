/// 备份文件的导出与选择读取抽象。
abstract interface class BackupFileStore {
  /// 把内容写出为文件并调起系统分享面板。返回展示给用户的文件名。
  Future<String> exportFile(String content, String filename);

  /// 调起文件选择器读取文本内容；用户取消返回 null。
  Future<String?> pickAndRead();
}

/// 内存实现：测试用。
class MemoryBackupFileStore implements BackupFileStore {
  final Map<String, String> files = {};

  String? pickedContent;

  @override
  Future<String> exportFile(String content, String filename) async {
    files[filename] = content;
    return filename;
  }

  @override
  Future<String?> pickAndRead() async => pickedContent;
}
