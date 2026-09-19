import '../domain/asset.dart';
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
}
