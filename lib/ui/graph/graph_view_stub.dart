import 'package:flutter/material.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';

Widget buildGraphView({
  required List<Asset> assets,
  required List<Relation> relations,
  required ValueChanged<Asset> onOpenNode,
}) {
  throw UnsupportedError('图谱视图不支持当前平台');
}
