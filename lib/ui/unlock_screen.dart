import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';

/// 首次创建主密码 / 解锁界面：纸面 + 居中账册卡。
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.controller});

  final VaultController controller;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  late final AnimationController _entrance;

  bool get _isFirstRun => !widget.controller.isConfigured;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    if (_isFirstRun) {
      return;
    }
    try {
      final available = await widget.controller.canUseBiometric();
      final enabled = available && await widget.controller.isBiometricEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
      if (enabled) {
        await _tryBiometric();
      }
    } on Exception {
      // 生物识别不可用时静默回退到主密码。
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await widget.controller.unlockWithBiometric();
      if (!ok && mounted) {
        setState(() => _error = '生物识别验证失败，请使用主密码');
      }
    } on Exception {
      if (mounted) {
        setState(() => _error = '生物识别验证失败，请使用主密码');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isFirstRun) {
        await widget.controller.createVault(_passwordController.text);
      } else {
        await widget.controller.unlock(_passwordController.text);
      }
    } on VaultUnlockException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.skin.canvas,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedBuilder(
              animation: _entrance,
              builder: (context, child) {
                final curve = CurvedAnimation(
                  parent: _entrance,
                  curve: Curves.easeOutCubic,
                );
                return Opacity(
                  opacity: curve.value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - curve.value)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.skin.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.skin.outline),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _VaultMark(),
                      const SizedBox(height: 16),
                      Text(
                        _isFirstRun ? '创建主密码' : '解锁保险库',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isFirstRun ? '主密码用于加密你的所有敏感数据。' : '输入主密码以查看敏感数据。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: context.skin.textSecondary),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.skin.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Web 预览：数据仅保存在本次浏览器会话，正式数据请使用 Android 应用。',
                            style: TextStyle(color: context.skin.textSecondary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: '主密码',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) =>
                            (value == null || value.length < 8)
                            ? '主密码至少 8 位'
                            : null,
                      ),
                      if (_isFirstRun) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '确认主密码',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
                              ? '两次输入不一致'
                              : null,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(color: context.skin.danger),
                        ),
                      ],
                      if (_isFirstRun) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.skin.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '主密码无法找回。丢失后只能重置保险库。',
                            style: TextStyle(color: context.skin.textSecondary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _SubmitButton(
                        busy: _busy,
                        label: _isFirstRun ? '创建' : '解锁',
                        onPressed: _submit,
                      ),
                      if (!_isFirstRun && _biometricAvailable) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _busy ? null : _tryBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(
                            _biometricEnabled ? '使用生物识别' : '使用生物识别（可在设置中开启）',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 保险库徽记：线稿库门 + 表盘把手，纯描边、无填充，契合无阴影视觉契约。
/// 包一层 Center：父 Column 是 stretch，直接放定宽 Container 会被横向拉成椭圆。
class _VaultMark extends StatelessWidget {
  const _VaultMark();

  @override
  Widget build(BuildContext context) => Center(
    child: CustomPaint(
      size: const Size(64, 64),
      painter: _VaultEmblemPainter(context.skin.textPrimary),
    ),
  );
}

class _VaultEmblemPainter extends CustomPainter {
  _VaultEmblemPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // 库门
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
        const Radius.circular(12),
      ),
      paint,
    );
    final center = Offset(size.width / 2, size.height / 2);
    // 表盘
    canvas.drawCircle(center, 11, paint);
    // 三辐把手
    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / 3);
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + dir * 11, center + dir * 17, paint);
    }
    // 轴心
    canvas.drawCircle(center, 2.2, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _VaultEmblemPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 提交按钮：busy 态切换为进度条 + 信任文案（设计文档 §4.8）。
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.busy,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: busy
        ? GFButton(
            key: const ValueKey('busy'),
            onPressed: null,
            blockButton: true,
            disabledTextColor: context.skin.textSecondary,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('正在解锁保险库'),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    child: LinearProgressIndicator(minHeight: 4),
                  ),
                ],
              ),
            ),
          )
        : GFButton(
            key: const ValueKey('idle'),
            onPressed: onPressed,
            blockButton: true,
            size: GFSize.LARGE,
            color: context.skin.primary,
            textColor: context.skin.onPrimary,
            text: label,
            // GFButton 内部 textStyle 不带 family,Web 预览中文会 tofu,显式补上。
            textStyle: const TextStyle(fontFamily: 'NotoSansSC'),
          ),
  );
}
