import '../domain/asset.dart';
import '../domain/relation.dart';
import 'asset_repository.dart';

/// 内存实现：MVP 阶段演示与测试用，重启后数据丢失。
class MemoryAssetRepository implements AssetRepository {
  final Map<String, Asset> _assets = {};
  final Map<String, Relation> _relations = {};

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
}
