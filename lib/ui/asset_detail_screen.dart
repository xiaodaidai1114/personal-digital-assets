import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/asset_repository.dart';
import '../domain/asset.dart';
import '../domain/asset_attachment.dart';
import '../domain/asset_field_format.dart';
import '../domain/asset_field_policy.dart';
import '../domain/asset_note.dart';
import '../domain/relation.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_edit_screen.dart';
import 'graph/graph_view.dart';
import 'widgets/asset_type_badge.dart';
import 'widgets/dashed_border.dart';
import 'widgets/empty_state.dart';

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.controller,
    required this.repository,
    required this.assetId,
    this.embedded = false,
    this.onDeleted,
    this.onDataChanged,
    this.onOpenGraph,
  });

  final VaultController controller;
  final AssetRepository repository;
  final String assetId;
  final bool embedded;
  final VoidCallback? onDeleted;
  final VoidCallback? onDataChanged;
  final VoidCallback? onOpenGraph;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  Asset? _asset;
  List<Asset> _allAssets = [];
  List<Relation> _relations = [];
  Map<String, Asset> _relatedAssets = {};
  List<AssetNote> _notes = const [];
  List<AssetAttachment> _attachments = const [];
  String? _revealedSecret;
  String? _secretError;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final asset = await widget.repository.getAsset(widget.assetId);
      final relations = asset == null
          ? const <Relation>[]
          : await widget.repository.relationsOf(asset.id);
      final notes = asset == null
          ? const <AssetNote>[]
          : await widget.repository.listNotes(asset.id);
      final attachments = asset == null
          ? const <AssetAttachment>[]
          : await widget.repository.listAttachments(asset.id);
      final relatedAssets = <String, Asset>{};
      for (final relation in relations) {
        final otherId = relation.fromAssetId == asset?.id
            ? relation.toAssetId
            : relation.fromAssetId;
        final other = await widget.repository.getAsset(otherId);
        if (other != null) {
          relatedAssets[relation.id] = other;
        }
      }
      final allAssets = await widget.repository.listAssets();
      if (!mounted) {
        return;
      }
      setState(() {
        _asset = asset;
        _relations = relations;
        _relatedAssets = relatedAssets;
        _allAssets = allAssets;
        _notes = notes;
        _attachments = attachments;
        _loaded = true;
        _error = null;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = true;
        _error = '读取详情失败';
      });
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _revealedSecret = null);
      }
    });
  }

  Future<void> _revealSecret() async {
    final encrypted = _asset?.encryptedSecret;
    if (encrypted == null) {
      return;
    }
    setState(() {
      _busy = true;
      _secretError = null;
    });
    try {
      final plain = await widget.controller.decryptSecret(encrypted);
      if (mounted) {
        setState(() => _revealedSecret = plain);
        _scheduleAutoHide();
      }
    } on Exception {
      if (mounted) {
        setState(() => _secretError = '无法解密：保险库状态异常');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _hideSecret() {
    _autoHideTimer?.cancel();
    setState(() {
      _revealedSecret = null;
      _secretError = null;
    });
  }

  Future<void> _copySecret() async {
    final secret = _revealedSecret;
    if (secret == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: secret));
    _scheduleAutoHide();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制，请注意剪贴板安全')));
    }
  }

  Future<void> _delete() async {
    final skin = context.skin;
    final asset = _asset;
    if (asset == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除资产'),
        content: Text('确定删除「${asset.title}」吗？相关关联也会一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: skin.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteAsset(asset.id);
      if (mounted) {
        if (widget.embedded) {
          widget.onDeleted?.call();
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _addRelation() async {
    final asset = _asset;
    if (asset == null) {
      return;
    }
    final candidates = _allAssets.where((item) => item.id != asset.id).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无其他资产可关联，请先在资产页新增')));
      return;
    }
    final created = await showModalBottomSheet<Relation>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) =>
          _AddRelationSheet(current: asset, candidates: candidates),
    );
    if (created != null) {
      await widget.repository.saveRelation(created);
      await _reload();
      widget.onDataChanged?.call();
    }
  }

  Future<void> _deleteRelation(Relation relation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除关联'),
        content: const Text('确定移除这条关联吗？资产本身不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.skin.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteRelation(relation.id);
      await _reload();
      widget.onDataChanged?.call();
    }
  }

  /// 返回 null 表示保存成功，否则为给用户看的错误文案。
  Future<String?> _addNote(String content) async {
    final asset = _asset;
    if (asset == null) {
      return '资产不存在';
    }
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '备注内容不能为空';
    }
    // 设计红线：敏感明文不落盘，保存前与资产表单同规校验
    final error = AssetFieldPolicy.sensitivePlainTextError(trimmed);
    if (error != null) {
      return error;
    }
    await widget.repository.addNote(
      AssetNote(id: const Uuid().v4(), assetId: asset.id, content: trimmed),
    );
    await _reload();
    widget.onDataChanged?.call();
    return null;
  }

  Future<void> _deleteNote(AssetNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备注'),
        content: const Text('确定删除这条备注吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.skin.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteNote(note.id);
      await _reload();
      widget.onDataChanged?.call();
    }
  }

  Future<void> _pickImage() async {
    final asset = _asset;
    if (asset == null) {
      return;
    }
    // 仅相册入口：Android 13+ 走系统 Photo Picker，无需任何权限声明；
    // maxWidth/imageQuality 由原生侧压缩。web 预览不生效（预览数据即弃，可接受）。
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (xfile == null) {
      return; // 用户取消选择
    }
    final bytes = await xfile.readAsBytes();
    await widget.repository.addAttachment(
      AssetAttachment(
        id: const Uuid().v4(),
        assetId: asset.id,
        name: xfile.name,
        mimeType: xfile.mimeType,
        byteSize: bytes.length,
      ),
      bytes,
    );
    await _reload();
    widget.onDataChanged?.call();
  }

  Future<void> _deleteAttachment(AssetAttachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图片'),
        content: Text('确定删除「${attachment.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.skin.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteAttachment(attachment.id);
      await _reload();
      widget.onDataChanged?.call();
    }
  }

  Future<void> _openPreviewNode(Asset node) async {
    final asset = _asset;
    if (asset == null || node.id == asset.id) {
      widget.onOpenGraph?.call();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          controller: widget.controller,
          repository: widget.repository,
          assetId: node.id,
          onOpenGraph: widget.onOpenGraph,
        ),
      ),
    );
    await _reload();
    widget.onDataChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final asset = _asset;
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: _error!,
          actionLabel: '重试',
          onAction: _reload,
        ),
      );
    }
    if (asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('资产详情')),
        body: EmptyState(
          icon: Icons.search_off,
          title: '资产不存在或已删除',
          actionLabel: '返回',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }
    return Listener(
      onPointerDown: (_) {
        if (_revealedSecret != null) {
          _scheduleAutoHide();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          title: Text(asset.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssetEditScreen(
                      controller: widget.controller,
                      repository: widget.repository,
                      asset: asset,
                    ),
                  ),
                );
                await _reload();
                widget.onDataChanged?.call();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: _delete,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AssetTypeBadge(type: asset.type, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            asset.type.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? skin.textSecondary
                                      : skin.textSecondary,
                                ),
                          ),
                          if (asset.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in asset.tags)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: skin.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: skin.outline),
                                    ),
                                    child: Text(
                                      tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: skin.textSecondary),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (asset.fields.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('字段', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final entry in asset.fields.entries.toList()) ...[
                      ListTile(
                        title: Text(
                          AssetFieldFormat.label(entry.key),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? skin.textSecondary
                                    : skin.textSecondary,
                              ),
                        ),
                        subtitle: Text(
                          AssetFieldFormat.value(entry.key, entry.value),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (entry.key != asset.fields.keys.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
            if (asset.encryptedSecret != null) ...[
              const SizedBox(height: 20),
              _SealedSecretCard(
                revealed: _revealedSecret,
                error: _secretError,
                busy: _busy,
                onReveal: _revealSecret,
                onHide: _hideSecret,
                onCopy: _copySecret,
              ),
            ],
            const SizedBox(height: 20),
            _NotesCard(
              notes: _notes,
              onAddNote: _addNote,
              onDeleteNote: _deleteNote,
            ),
            const SizedBox(height: 20),
            _AttachmentsCard(
              attachments: _attachments,
              repository: widget.repository,
              onAdd: _pickImage,
              onDelete: _deleteAttachment,
            ),
            const SizedBox(height: 20),
            _LocalGraphCard(
              assets: [
                asset,
                ..._allAssets.where(
                  (item) => _relations.any(
                    (relation) =>
                        (relation.fromAssetId == asset.id &&
                            relation.toAssetId == item.id) ||
                        (relation.toAssetId == asset.id &&
                            relation.fromAssetId == item.id),
                  ),
                ),
              ],
              relations: _relations,
              onOpenGraph: widget.onOpenGraph,
              onOpenNode: _openPreviewNode,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '关联',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addRelation,
                  icon: const Icon(Icons.add_link),
                  label: const Text('添加关联'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_relations.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.link_outlined, size: 32),
                      SizedBox(height: 8),
                      Text('资产之间还没有关联'),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final relation in _relations) ...[
                      ListTile(
                        leading: AssetTypeBadge(
                          type:
                              _relatedAssets[relation.id]?.type ??
                              AssetType.other,
                          size: 34,
                        ),
                        title: Text(
                          '${relation.type.label}：${_relatedAssets[relation.id]?.title ?? '未知资产'}',
                        ),
                        subtitle: Text(
                          relation.fromAssetId == asset.id
                              ? '${asset.title} → ${_relatedAssets[relation.id]?.title ?? '未知资产'}'
                              : '${_relatedAssets[relation.id]?.title ?? '未知资产'} → ${asset.title}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.link_off_outlined),
                          tooltip: '移除关联',
                          onPressed: () => _deleteRelation(relation),
                        ),
                      ),
                      if (relation != _relations.last) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 封缄敏感卡：frosted + blur 开合（motion/medium 240ms），
/// 显示 8 秒无操作自动隐藏（设计文档 §4.4）。
class _SealedSecretCard extends StatelessWidget {
  const _SealedSecretCard({
    required this.revealed,
    required this.error,
    required this.busy,
    required this.onReveal,
    required this.onHide,
    required this.onCopy,
  });

  final String? revealed;
  final String? error;
  final bool busy;
  final VoidCallback onReveal;
  final VoidCallback onHide;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isOpen = revealed != null;
    return CustomPaint(
      foregroundPainter: DashedBorder(color: skin.textTertiary),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: skin.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('已加密')),
                TextButton(
                  onPressed: busy
                      ? null
                      : isOpen
                      ? onHide
                      : onReveal,
                  child: Text(isOpen ? '隐藏' : '显示'),
                ),
                if (isOpen)
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制',
                    onPressed: onCopy,
                  ),
              ],
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(color: skin.danger),
                      ),
                    ),
                    TextButton(onPressed: onReveal, child: const Text('重试')),
                  ],
                ),
              )
            else if (isOpen)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SelectableText(
                  revealed!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('显示后本地解密，8 秒自动隐藏。'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 备注时间线卡：多条带时间戳的短记录，新条目在前（设计文档 §资产详情）。
/// 内容为明文，仅存加密库；保存前经敏感明文校验（见 _AssetDetailScreenState._addNote）。
class _NotesCard extends StatefulWidget {
  const _NotesCard({
    required this.notes,
    required this.onAddNote,
    required this.onDeleteNote,
  });

  final List<AssetNote> notes;
  final Future<String?> Function(String content) onAddNote;
  final void Function(AssetNote note) onDeleteNote;

  @override
  State<_NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<_NotesCard> {
  final TextEditingController _controller = TextEditingController();
  bool _composing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await widget.onAddNote(_controller.text);
    if (!mounted) {
      return;
    }
    if (error == null) {
      _controller.clear();
      setState(() {
        _composing = false;
        _error = null;
      });
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('备注', style: Theme.of(context).textTheme.titleLarge),
            ),
            TextButton.icon(
              onPressed: _composing
                  ? null
                  : () => setState(() => _composing = true),
              icon: const Icon(Icons.edit_note),
              label: const Text('添加备注'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_composing)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '记录一笔动态',
                      hintText: '例如：已开启二次验证',
                      errorText: _error,
                    ),
                    onChanged: (_) {
                      if (_error != null) {
                        setState(() => _error = null);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _composing = false;
                          _error = null;
                        }),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _save,
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (widget.notes.isEmpty && !_composing)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.notes_outlined, size: 32),
                  SizedBox(height: 8),
                  Text('暂无备注'),
                ],
              ),
            ),
          )
        else if (widget.notes.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final note in widget.notes) ...[
                  ListTile(
                    leading: Text(
                      DateFormat('MM-dd HH:mm').format(note.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: skin.textSecondary,
                      ),
                    ),
                    title: Text(note.content),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除备注',
                      onPressed: () => widget.onDeleteNote(note),
                    ),
                  ),
                  if (note != widget.notes.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// 图片附件卡：96px 缩略方块，点开全屏查看，长按删除（设计文档 §资产详情）。
/// 字节为密文 BLOB，按需读取；缩略用 Image.memory 的 cacheWidth 渲染时降采样。
class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({
    required this.attachments,
    required this.repository,
    required this.onAdd,
    required this.onDelete,
  });

  final List<AssetAttachment> attachments;
  final AssetRepository repository;
  final VoidCallback onAdd;
  final void Function(AssetAttachment attachment) onDelete;

  void _openViewer(BuildContext context, AssetAttachment attachment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AttachmentViewerScreen(
          attachment: attachment,
          repository: repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('图片', style: Theme.of(context).textTheme.titleLarge),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('添加图片'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (attachments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.image_outlined, size: 32),
                  SizedBox(height: 8),
                  Text('暂无图片'),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in attachments)
                    _AttachmentTile(
                      attachment: attachment,
                      repository: repository,
                      onTap: () => _openViewer(context, attachment),
                      onLongPress: () => onDelete(attachment),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.repository,
    required this.onTap,
    required this.onLongPress,
  });

  final AssetAttachment attachment;
  final AssetRepository repository;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  late final Future<Uint8List?> _bytesFuture = widget.repository
      .attachmentBytes(widget.attachment.id);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _bytesFuture.then((bytes) {
      if (mounted && bytes != null) {
        setState(() => _loaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kb = (widget.attachment.byteSize / 1024).round();
    return Semantics(
      label: '${widget.attachment.name} · $kb KB',
      child: FutureBuilder<Uint8List?>(
        future: _bytesFuture,
        builder: (context, snapshot) {
          final skin = context.skin;
          final bytes = snapshot.data;
          return GestureDetector(
            // 字节未就绪时点按不进查看器，避免打开空白页
            onTap: _loaded ? widget.onTap : null,
            onLongPress: widget.onLongPress,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                height: 96,
                child: bytes == null
                    ? ColoredBox(
                        color: skin.surfaceAlt,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : Image.memory(
                        bytes,
                        cacheWidth: 240,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AttachmentViewerScreen extends StatelessWidget {
  const _AttachmentViewerScreen({
    required this.attachment,
    required this.repository,
  });

  final AssetAttachment attachment;
  final AssetRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(attachment.name)),
      body: FutureBuilder<Uint8List?>(
        future: repository.attachmentBytes(attachment.id),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.memory(bytes)),
          );
        },
      ),
    );
  }
}

class _LocalGraphCard extends StatelessWidget {
  const _LocalGraphCard({
    required this.assets,
    required this.relations,
    required this.onOpenGraph,
    required this.onOpenNode,
  });

  final List<Asset> assets;
  final List<Relation> relations;
  final VoidCallback? onOpenGraph;
  final ValueChanged<Asset> onOpenNode;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      height: 200,
      child: Stack(
        children: [
          Container(
            color: context.skin.canvas,
            child: buildGraphView(
              assets: assets,
              relations: relations,
              focusIds: assets.isEmpty ? const {} : {assets.first.id},
              onOpenNode: onOpenNode,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '一跳关系图',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.skin.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onOpenGraph != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: context.skin.textPrimary,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onOpenGraph,
                    icon: const Icon(Icons.open_in_full, size: 16),
                    label: const Text('打开星图'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 添加关联：关系类型 + 方向 + 目标资产。
class _AddRelationSheet extends StatefulWidget {
  const _AddRelationSheet({required this.current, required this.candidates});

  final Asset current;
  final List<Asset> candidates;

  @override
  State<_AddRelationSheet> createState() => _AddRelationSheetState();
}

class _AddRelationSheetState extends State<_AddRelationSheet> {
  final _targetSearchController = TextEditingController();
  RelationType _type = RelationType.relatesTo;
  Asset? _target;
  bool _forward = true;

  @override
  void dispose() {
    _targetSearchController.dispose();
    super.dispose();
  }

  List<Asset> get _visibleCandidates {
    final query = _targetSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.candidates;
    }
    return widget.candidates
        .where(
          (candidate) =>
              candidate.title.toLowerCase().contains(query) ||
              candidate.type.label.toLowerCase().contains(query) ||
              candidate.tags.any((tag) => tag.toLowerCase().contains(query)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final candidates = _visibleCandidates;
    final targetTitle = _target?.title ?? '目标资产';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('添加关联', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<RelationType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '关系类型'),
            items: [
              for (final type in RelationType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '搜索关联资产',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: candidates.isEmpty
                ? const Center(child: Text('没有匹配的资产'))
                : ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      final selected = candidate.id == _target?.id;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        leading: AssetTypeBadge(type: candidate.type, size: 28),
                        title: Text(
                          candidate.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(candidate.type.label),
                        trailing: selected
                            ? const Icon(Icons.check_circle_outline)
                            : null,
                        onTap: () => setState(
                          () => _target = selected ? null : candidate,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(
                  '${widget.current.title} → $targetTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ButtonSegment(
                value: false,
                label: Text(
                  '$targetTitle → ${widget.current.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            selected: {_forward},
            onSelectionChanged: (selection) =>
                setState(() => _forward = selection.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _target == null
                ? null
                : () {
                    final target = _target!;
                    Navigator.of(context).pop(
                      Relation(
                        id: const Uuid().v4(),
                        fromAssetId: _forward ? widget.current.id : target.id,
                        toAssetId: _forward ? target.id : widget.current.id,
                        type: _type,
                      ),
                    );
                  },
            child: const Text('保存关联'),
          ),
        ],
      ),
    );
  }
}
