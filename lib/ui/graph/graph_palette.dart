/// 星图专用夜色取值：星图画布固定夜色，不随应用亮暗主题切换。
///
/// 临时桥接文件——星图整体拆除（青穹资产云 Phase A Stage 2）时随之删除。
library;

import 'package:flutter/material.dart';

const Color kGraphBackground = Color(0xFF1A1915);
const Color kGraphSurface = Color(0xFF24221C);
const Color kGraphTextPrimary = Color(0xFFEDE8DC);
const Color kGraphTextSecondary = Color(0xFFA39B8C);
const Color kGraphNode = Color(0xFFEDE8DC);

/// 星图内嵌页使用的夜色主题（原 AppTheme.night() 的极简替身）。
ThemeData graphTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kGraphBackground,
  colorScheme: const ColorScheme.dark(
    surface: kGraphSurface,
    onSurface: kGraphTextPrimary,
    primary: kGraphTextPrimary,
  ),
);
