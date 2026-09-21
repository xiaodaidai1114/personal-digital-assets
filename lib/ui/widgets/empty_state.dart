import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.dark = false,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // 星图空态仍走固定夜色（dark=true），随 Stage 2 拆除星图一并移除。
    final ink = dark ? const Color(0xFFEDE8DC) : skin.textPrimary;
    return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ink, width: 1.5),
            ),
            child: Icon(icon, color: ink, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
  }
}
