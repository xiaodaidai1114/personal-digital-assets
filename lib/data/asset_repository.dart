import 'dart:typed_data';

import '../domain/asset.dart';
import '../domain/asset_attachment.dart';
import '../domain/asset_note.dart';
import '../domain/relation.dart';

/// 资产与关系的存储接口。当前为内存实现，数据库迭代时替换为 SQLCipher 实现。
abstract class AssetRepository {
  Future<List<Asset>> listAssets();

  Future<Asset?> getAsset(String id);

  Future<void> saveAsset(Asset asset);

  Future<void> deleteAsset(String id);

  Future<List<Relation>> listRelations();

  Future<void> saveRelation(Relation relation);

  Future<void> deleteRelation(String id);

  /// 与某资产相关的所有边（含入边与出边）。
  Future<List<Relation>> relationsOf(String assetId);

  /// 资产备注时间线，新条目在前。
  Future<List<AssetNote>> listNotes(String assetId);

  Future<void> addNote(AssetNote note);

  Future<void> deleteNote(String noteId);

  /// 附件元数据列表（不含图片字节）。
  Future<List<AssetAttachment>> listAttachments(String assetId);

  /// 写入附件元数据与图片字节（SQLCipher 下字节随库加密）。
  Future<void> addAttachment(AssetAttachment attachment, List<int> bytes);

  /// 按需读取附件图片字节；不存在时返回 null。
  Future<Uint8List?> attachmentBytes(String attachmentId);

  Future<void> deleteAttachment(String attachmentId);
}
