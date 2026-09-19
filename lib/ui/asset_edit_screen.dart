import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'widgets/asset_type_badge.dart';

/// 新增 / 编辑资产。敏感内容经控制器加密后保存，明文不落盘。
class AssetEditScreen extends StatefulWidget {
  const AssetEditScreen({
    super.key,
    required this.controller,
    required this.repository,
    this.asset,
  });

  final VaultController controller;
  final MemoryAssetRepository repository;
  final Asset? asset;

  @override
  State<AssetEditScreen> createState() => _AssetEditScreenState();
}

class _AssetEditScreenState extends State<AssetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretController = TextEditingController();
  late final TextEditingController _titleController;
  late final TextEditingController _tagsController;
  late AssetType _type;
  bool _busy = false;
  bool _editingSecret = false;

  bool get _isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _titleController = TextEditingController(text: asset?.title ?? '');
    _tagsController = TextEditingController(
      text: asset?.tags.join(', ') ?? '',
    );
    _type = asset?.type ?? AssetType.password;
    _editingSecret = asset == null;
  }

  @override
  void dispose() {
    _secretController.dispose();
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final secretText = _secretController.text;
      final encryptedSecret = secretText.isEmpty
          ? widget.asset?.encryptedSecret
          : await widget.controller.encryptSecret(secretText);
      final tags = _tagsController.text
          .split(RegExp(r'[,，]'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      final asset = (widget.asset ??
              Asset(
                id: const Uuid().v4(),
                type: _type,
                title: _titleController.text,
              ))
          .copyWith(
        type: _type,
        title: _titleController.text,
        tags: tags,
        encryptedSecret: encryptedSecret,
        updatedAt: DateTime.now(),
      );
      await widget.repository.saveAsset(asset);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_isEditing ? '编辑资产' : '新增资产')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('类型', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.12,
                children: [
                  for (final type in AssetType.values)
                    _TypePickerCard(
                      type: type,
                      selected: type == _type,
                      onTap: () => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? '请填写名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: '标签（逗号分隔）',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 16),
              if (_isEditing && !_editingSecret)
                _SealedSecretCard(
                  onEdit: () => setState(() => _editingSecret = true),
                )
              else
                TextFormField(
                  controller: _secretController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '敏感内容（密码 / Key，加密保存）',
                    prefixIcon: const Icon(Icons.password_outlined),
                    helperText: _isEditing ? '留空则保持原有内容不变' : null,
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
            ],
          ),
        ),
      );
}

class _TypePickerCard extends StatelessWidget {
  const _TypePickerCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AssetType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppColors.typeLight(type)
        : AppColors.typeDeep(type);
    return Material(
      color: selected
          ? color.withValues(alpha: .12)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : Theme.of(context).dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AssetTypeBadge(type: type, selected: selected, size: 34),
              const SizedBox(height: 8),
              Text(
                type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SealedSecretCard extends StatelessWidget {
  const _SealedSecretCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.nightSurface.withValues(alpha: .72)
              : Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 12),
            const Expanded(child: Text('敏感内容已加密')),
            OutlinedButton(onPressed: onEdit, child: const Text('修改')),
          ],
        ),
      );
}
