import 'dart:typed_data';

import '../domain/asset.dart';
import '../domain/asset_attachment.dart';
import '../domain/asset_note.dart';
import '../domain/relation.dart';
import 'asset_repository.dart';

/// 内存实现：MVP 阶段演示与测试用，重启后数据丢失。
class MemoryAssetRepository implements AssetRepository {
  final Map<String, Asset> _assets = {};
  final Map<String, Relation> _relations = {};
  final Map<String, AssetNote> _notes = {};
  final Map<String, AssetAttachment> _attachments = {};
  final Map<String, Uint8List> _attachmentBytesById = {};

  @override
  Future<List<Asset>> listAssets() async =>
      _assets.values.toList(growable: false);

  @override
  Future<Asset?> getAsset(String id) async => _assets[id];

  @override
  Future<void> saveAsset(Asset asset) async => _assets[asset.id] = asset;

  @override
  Future<void> deleteAsset(String id) async {
    _assets.remove(id);
    _relations.removeWhere(
      (_, relation) => relation.fromAssetId == id || relation.toAssetId == id,
    );
    _notes.removeWhere((_, note) => note.assetId == id);
    final removedAttachmentIds = _attachments.entries
        .where((entry) => entry.value.assetId == id)
        .map((entry) => entry.key)
        .toList();
    _attachments.removeWhere((_, attachment) => attachment.assetId == id);
    for (final attachmentId in removedAttachmentIds) {
      _attachmentBytesById.remove(attachmentId);
    }
  }

  @override
  Future<List<Relation>> listRelations() async =>
      _relations.values.toList(growable: false);

  @override
  Future<void> saveRelation(Relation relation) async =>
      _relations[relation.id] = relation;

  @override
  Future<void> deleteRelation(String id) async => _relations.remove(id);

  @override
  Future<List<Relation>> relationsOf(String assetId) async => _relations.values
      .where(
        (relation) =>
            relation.fromAssetId == assetId || relation.toAssetId == assetId,
      )
      .toList(growable: false);

  @override
  Future<List<AssetNote>> listNotes(String assetId) async {
    final notes = _notes.values
        .where((note) => note.assetId == assetId)
        .toList(growable: false);
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  @override
  Future<void> addNote(AssetNote note) async => _notes[note.id] = note;

  @override
  Future<void> deleteNote(String noteId) async => _notes.remove(noteId);

  @override
  Future<List<AssetAttachment>> listAttachments(String assetId) async =>
      _attachments.values
          .where((attachment) => attachment.assetId == assetId)
          .toList(growable: false);

  @override
  Future<void> addAttachment(
    AssetAttachment attachment,
    List<int> bytes,
  ) async {
    _attachments[attachment.id] = attachment;
    _attachmentBytesById[attachment.id] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> attachmentBytes(String attachmentId) async =>
      _attachmentBytesById[attachmentId];

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    _attachments.remove(attachmentId);
    _attachmentBytesById.remove(attachmentId);
  }
}
