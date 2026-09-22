import 'package:flutter/material.dart';

import 'app.dart';
import 'web_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerWebFonts();
  runApp(const PersonalDigitalAssetsApp());
}
