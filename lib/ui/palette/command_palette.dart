import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../domain/asset.dart';
import '../../theme/app_theme.dart';
import '../widgets/asset_type_badge.dart';
import '../widgets/smart_truncate.dart';
import 'fuzzy_match.dart';

/// 命令控制台（DESIGN.md）：下拉唤醒的全局面板，
/// 极模糊匹配 名称/标签/类型/自定义字段，选中直达详情。
Future<void> showCommandPalette(
  BuildContext context, {
  required List<Asset> assets,
  required ValueChanged<Asset> onSelect,
}) => showDialog(
  context: context,
  barrierColor: Colors.black54,
  builder: (_) => CommandPalette(assets: assets, onSelect: onSelect),
);

class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.assets,
    required this.onSelect,
  });

  final List<Asset> assets;
  final ValueChanged<Asset> onSelect;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  List<PaletteHit> _hits = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    _update();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _update() {
    setState(() => _hits = rankAssets(_controller.text, widget.assets));
  }

  void _select(PaletteHit hit) {
    Navigator.of(context).pop();
    widget.onSelect(hit.asset);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width >= 1024 ? 560 : double.infinity,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: skin.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: skin.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Icon(Icons.search, color: skin.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          filled: false,
                          hintText: '检索资产、字段、标签…',
                          hintStyle: TextStyle(color: skin.textTertiary),
                        ),
                        style: TextStyle(color: skin.textPrimary),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭面板',
                      icon: Icon(Icons.close, color: skin.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: skin.outline),
              Flexible(
                child: _hits.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Text(
                          '无匹配资产',
                          style: TextStyle(color: skin.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _hits.length,
                        itemBuilder: (context, index) {
                          final hit = _hits[index];
                          return GFListTile(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            color: Colors.transparent,
                            listItemTextColor: skin.textPrimary,
                            avatar: AssetTypeBadge(
                              type: hit.asset.type,
                              size: 30,
                            ),
                            title: _hitTitle(hit, skin),
                            subTitleText: smartTruncate(
                              _subtitle(hit.asset),
                              max: 42,
                            ),
                            onTap: () => _select(hit),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hitTitle(PaletteHit hit, AppSkin skin) {
    final ranges = hit.ranges;
    if (ranges == null || ranges.isEmpty) {
      return Text(
        hit.asset.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.w600),
      );
    }
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(
          TextSpan(text: hit.asset.title.substring(cursor, range.start)),
        );
      }
      spans.add(
        TextSpan(
          text: hit.asset.title.substring(range.start, range.end),
          style: TextStyle(color: skin.primary, fontWeight: FontWeight.w700),
        ),
      );
      cursor = range.end;
    }
    if (cursor < hit.asset.title.length) {
      spans.add(TextSpan(text: hit.asset.title.substring(cursor)));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.w600),
        children: spans,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _subtitle(Asset asset) => [
    asset.type.label,
    if (asset.tags.isNotEmpty) asset.tags.take(3).join(' / '),
  ].join(' · ');
}
