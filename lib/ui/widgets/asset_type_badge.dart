import 'package:flutter/material.dart';

import '../../domain/asset.dart';
import '../../theme/app_theme.dart';

class AssetTypeBadge extends StatelessWidget {
  const AssetTypeBadge({
    super.key,
    required this.type,
    this.size = 40,
    this.selected = false,
  });

  final AssetType type;
  final double size;
  final bool selected;

  IconData get _icon => assetTypeIcon(type);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppColors.typeLight(type)
        : AppColors.typeDeep(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.ink : color,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: Icon(_icon, color: color, size: size * .52),
    );
  }
}

IconData assetTypeIcon(AssetType type) => switch (type) {
  AssetType.email => Icons.mail_outline,
  AssetType.subscription => Icons.autorenew,
  AssetType.apiKey => Icons.key_outlined,
  AssetType.password => Icons.password_outlined,
  AssetType.device => Icons.devices_outlined,
  AssetType.item => Icons.inventory_2_outlined,
  AssetType.bill => Icons.receipt_long_outlined,
  AssetType.bankCard => Icons.credit_card,
  AssetType.other => Icons.category_outlined,
};
