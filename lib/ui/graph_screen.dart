import 'package:flutter/material.dart';

class GraphScreen extends StatelessWidget {
  const GraphScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('资产图谱')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hub_outlined, size: 64),
                SizedBox(height: 16),
                Text(
                  '图谱视图即将上线',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '将以内嵌 G6 画布呈现资产之间的关联网络。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
