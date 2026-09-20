import 'repository_bundle.dart';
import 'repository_factory_stub.dart'
    if (dart.library.html) 'repository_factory_web.dart'
    if (dart.library.io) 'repository_factory_io.dart'
    as impl;

/// Android/iOS：SQLCipher 加密数据库；Web 预览：内存仓库。
Future<RepositoryBundle> createRepositoryBundle() =>
    impl.createRepositoryBundle();
