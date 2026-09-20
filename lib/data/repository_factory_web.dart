import 'demo_data.dart';
import 'memory_asset_repository.dart';
import '../vault/vault_state_store.dart';
import 'repository_bundle.dart';

/// Web 预览：内存仓库，每次启动重置并写入演示数据。
Future<RepositoryBundle> createRepositoryBundle() async {
  final repository = MemoryAssetRepository();
  await seedDemoData(repository);
  return RepositoryBundle(
    repository: repository,
    vaultStateStore: MemoryVaultStateStore(),
  );
}
