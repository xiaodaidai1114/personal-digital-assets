import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/asset_repository.dart';
import '../domain/asset.dart';
import '../domain/asset_field_policy.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/dashed_border.dart';

/// 新增 / 编辑资产。敏感内容经控制器加密后保存，明文不落盘。
class AssetEditScreen extends StatefulWidget {
  const AssetEditScreen({
    super.key,
    required this.controller,
    required this.repository,
    this.asset,
    this.initialType,
  });

  final VaultController controller;
  final AssetRepository repository;
  final Asset? asset;
  final AssetType? initialType;

  @override
  State<AssetEditScreen> createState() => _AssetEditScreenState();
}

class _AssetEditScreenState extends State<AssetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretController = TextEditingController();
  late final TextEditingController _titleController;
  final _tagInputController = TextEditingController();
  final _fieldControllers = <String, TextEditingController>{};
  final _tags = <String>{};
  final _suggestedTags = <String>[];
  late AssetType _type;
  String? _tagError;
  bool _busy = false;
  bool _editingSecret = false;

  bool get _isEditing => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _titleController = TextEditingController(text: asset?.title ?? '');
    _tags.addAll(asset?.tags ?? const <String>[]);
    _type = asset?.type ?? widget.initialType ?? AssetType.password;
    _editingSecret = asset == null;
    for (final field in fieldTemplates.values.expand((fields) => fields)) {
      _fieldControllers[field.key] = TextEditingController(
        text: asset?.fields[field.key]?.toString() ?? '',
      );
    }
    _loadSuggestedTags();
  }

  @override
  void dispose() {
    _secretController.dispose();
    _titleController.dispose();
    _tagInputController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSuggestedTags() async {
    final assets = await widget.repository.listAssets();
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestedTags
        ..clear()
        ..addAll(
          assets
              .expand((asset) => asset.tags)
              .where((tag) => !_tags.contains(tag))
              .toSet()
              .take(8),
        );
    });
  }

  void _commitTagInput() {
    final tags = _tagInputController.text
        .split(RegExp(r'[,，\n]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty);
    final newTags = tags.where((tag) => !_tags.contains(tag)).toList();
    if (newTags.isEmpty) {
      _tagInputController.clear();
      return;
    }
    setState(() {
      _tags.addAll(newTags);
      _suggestedTags.removeWhere(newTags.contains);
      _tagInputController.clear();
      _tagError = null;
    });
  }

  void _addTag(String tag) {
    final normalizedTag = tag.trim();
    if (normalizedTag.isEmpty) {
      return;
    }
    setState(() {
      _tags.add(normalizedTag);
      _suggestedTags.remove(normalizedTag);
      _tagError = null;
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _tagError = null;
      if (_suggestedTags.length < 8) {
        _suggestedTags.add(tag);
      }
    });
  }

  void _selectType(AssetType type) {
    if (type == _type) {
      return;
    }
    final currentKeys =
        fieldTemplates[type]?.map((item) => item.key).toSet() ??
        const <String>{};
    final staleKeys = fieldTemplates.values
        .expand((fields) => fields)
        .map((field) => field.key)
        .where((key) => !currentKeys.contains(key))
        .toSet();
    for (final key in staleKeys) {
      _fieldControllers[key]?.clear();
    }
    setState(() => _type = type);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final sensitiveTag = _tags
        .map((tag) => AssetFieldPolicy.sensitivePlainTextError(tag))
        .firstWhere((error) => error != null, orElse: () => null);
    if (sensitiveTag != null) {
      setState(() => _tagError = sensitiveTag);
      return;
    }
    setState(() => _busy = true);
    try {
      final secretText = _secretController.text;
      final encryptedSecret = secretText.isEmpty
          ? widget.asset?.encryptedSecret
          : await widget.controller.encryptSecret(secretText);
      final fields = Map<String, dynamic>.from(widget.asset?.fields ?? {});
      final templates = fieldTemplates[_type] ?? const <_FieldTemplate>[];
      final currentKeys = templates.map((template) => template.key).toSet();
      final managedKeys = fieldTemplates.values
          .expand((items) => items)
          .map((template) => template.key)
          .toSet();
      fields.removeWhere(
        (key, value) =>
            currentKeys.contains(key) ||
            managedKeys.difference(currentKeys).contains(key),
      );
      for (final template in templates) {
        final value = _fieldControllers[template.key]?.text.trim();
        if (value != null && value.isNotEmpty) {
          fields[template.key] = value;
        }
      }
      final asset =
          (widget.asset ??
                  Asset(
                    id: const Uuid().v4(),
                    type: _type,
                    title: _titleController.text,
                  ))
              .copyWith(
                type: _type,
                title: _titleController.text,
                fields: fields,
                tags: _tags.toList(),
                encryptedSecret: encryptedSecret,
                updatedAt: DateTime.now(),
              );
      await widget.repository.saveAsset(asset);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in AssetType.values)
                _TypePickerChip(
                  type: type,
                  selected: type == _type,
                  onTap: () => _selectType(type),
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
            validator: (value) => (value == null || value.trim().isEmpty)
                ? '请填写名称'
                : AssetFieldPolicy.sensitivePlainTextError(value.trim()),
          ),
          const SizedBox(height: 12),
          Text('标签', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TagField(
            controller: _tagInputController,
            tags: _tags.toList(),
            suggestions: _suggestedTags,
            errorText: _tagError,
            onSubmitted: _commitTagInput,
            onChanged: (value) {
              if (RegExp(r'[,，\n]\s*$').hasMatch(value)) {
                _commitTagInput();
              }
            },
            onDeleted: _removeTag,
            onSuggestionSelected: _addTag,
          ),
          const SizedBox(height: 20),
          ..._buildTemplateFields(),
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
  List<Widget> _buildTemplateFields() {
    final templates = fieldTemplates[_type] ?? const <_FieldTemplate>[];
    if (templates.isEmpty) {
      return const <Widget>[];
    }
    return [
      Text('${_type.label}字段', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final template in templates) ...[
        TextFormField(
          controller: _fieldControllers[template.key],
          decoration: InputDecoration(
            labelText: template.label,
            helperText: template.helper,
            prefixIcon: Icon(template.icon),
          ),
          validator: (value) =>
              AssetFieldPolicy.plainFieldError(template.key, value ?? ''),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  static const fieldTemplates = <AssetType, List<_FieldTemplate>>{
    AssetType.subscription: [
      _FieldTemplate('plan', '套餐', Icons.workspace_premium_outlined),
      _FieldTemplate('cycle', '周期', Icons.repeat),
      _FieldTemplate('amount', '金额', Icons.payments_outlined),
      _FieldTemplate('nextRenewalDate', '下次续费', Icons.event_outlined),
    ],
    AssetType.apiKey: [
      _FieldTemplate('prefix', '前缀', Icons.tag),
      _FieldTemplate('environment', '环境', Icons.dns_outlined),
      _FieldTemplate('expiryDate', '到期时间', Icons.event_busy_outlined),
    ],
    AssetType.password: [
      _FieldTemplate('username', '用户名', Icons.person_outline),
      _FieldTemplate('url', '网址', Icons.link),
    ],
    AssetType.email: [
      _FieldTemplate('address', '邮箱地址', Icons.alternate_email),
      _FieldTemplate('recoveryEmail', '恢复邮箱', Icons.mark_email_unread_outlined),
    ],
    AssetType.device: [
      _FieldTemplate('model', '型号', Icons.devices_other_outlined),
      _FieldTemplate('os', '系统', Icons.memory),
      _FieldTemplate('serialNumber', '序列号', Icons.numbers),
      _FieldTemplate('warrantyExpiry', '保修到期', Icons.verified_outlined),
    ],
    AssetType.bill: [
      _FieldTemplate('amount', '金额', Icons.payments_outlined),
      _FieldTemplate('date', '日期', Icons.calendar_today_outlined),
      _FieldTemplate('paid', '已支付', Icons.check_circle_outline),
    ],
    AssetType.bankCard: [
      _FieldTemplate('bank', '银行', Icons.account_balance_outlined),
      _FieldTemplate(
        'cardNumber',
        '卡号后四位',
        Icons.credit_card,
        '仅保存后四位，完整卡号请写入敏感内容',
      ),
      _FieldTemplate('expiryDate', '有效期', Icons.event_outlined),
    ],
  };
}

class _FieldTemplate {
  const _FieldTemplate(this.key, this.label, this.icon, [this.helper]);

  final String key;
  final String label;
  final IconData icon;
  final String? helper;
}

class _TagField extends StatelessWidget {
  const _TagField({
    required this.controller,
    required this.tags,
    required this.suggestions,
    this.errorText,
    required this.onSubmitted,
    required this.onChanged,
    required this.onDeleted,
    required this.onSuggestionSelected,
  });

  final TextEditingController controller;
  final List<String> tags;
  final List<String> suggestions;
  final String? errorText;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onDeleted;
  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmitted(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: '输入后回车或逗号添加',
          prefixIcon: Icon(Icons.sell_outlined),
          errorText: errorText,
        ),
      ),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags)
              InputChip(label: Text(tag), onDeleted: () => onDeleted(tag)),
          ],
        ),
      ],
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in suggestions)
              ActionChip(
                avatar: const Icon(Icons.add, size: 15),
                label: Text(tag),
                onPressed: () => onSuggestionSelected(tag),
              ),
          ],
        ),
      ],
    ],
  );
}

class _TypePickerChip extends StatelessWidget {
  const _TypePickerChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AssetType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Material(
      color: selected ? skin.surfaceAlt : skin.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? skin.textPrimary : skin.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AssetTypeBadge(type: type, selected: selected, size: 24),
              const SizedBox(width: 6),
              Text(
                type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
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
    padding: EdgeInsets.zero,
    child: CustomPaint(
      foregroundPainter: DashedBorder(color: context.skin.textTertiary),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.skin.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 18),
            const SizedBox(width: 12),
            const Expanded(child: Text('已加密')),
            OutlinedButton(onPressed: onEdit, child: const Text('修改')),
          ],
        ),
      ),
    ),
  );
}
