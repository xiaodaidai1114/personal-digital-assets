import 'package:flutter/material.dart';

import '../../domain/asset.dart';
import '../../domain/relation.dart';
import 'native_graph_view.dart';

Widget buildGraphView({
  required List<Asset> assets,
  required List<Relation> relations,
  required ValueChanged<Asset> onOpenNode,
}) => NativeGraphView(
  assets: assets,
  relations: relations,
  onOpenNode: onOpenNode,
);
