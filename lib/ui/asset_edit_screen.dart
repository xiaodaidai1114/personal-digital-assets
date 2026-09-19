import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/memory_asset_repository.dart';
import '../domain/asset.dart';
import '../vault/vault_controller.dart';

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

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _titleController = TextEditingController(text: asset?.title ?? '');
    _tagsController = TextEditingController(
      text: asset?.tags.join(', ') ?? '',
    );
    _type = asset?.type ?? AssetType.password;
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
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.asset == null ? '新增资产' : '编辑资产'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<AssetType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: '类型',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final type in AssetType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) =>
                    setState(() => _type = value ?? AssetType.other),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '名称',
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _secretController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '敏感内容（密码 / Key，加密保存）',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.password_outlined),
                  helperText: widget.asset == null ? null : '留空则保持原有内容不变',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
            ],
          ),
        ),
      );
}
