import 'biometric_gate.dart';
import 'biometric_gate_stub.dart'
    if (dart.library.html) 'biometric_gate_web.dart'
    if (dart.library.io) 'biometric_gate_io.dart'
    as impl;

/// 平台对应的生物识别门：移动端 local_auth，其余平台空实现。
BiometricGate createBiometricGate() => impl.createBiometricGate();
