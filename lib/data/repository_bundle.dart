import '../vault/vault_state_store.dart';
import 'asset_repository.dart';

/// 平台对应的数据装配：资产仓库 + 保险库状态存储。
class RepositoryBundle {
  const RepositoryBundle({
    required this.repository,
    required this.vaultStateStore,
  });

  final AssetRepository repository;
  final VaultStateStore vaultStateStore;
}
