import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive 存储
  await StorageService.instance.initialize();

  runApp(
    const ProviderScope(
      child: LoveCookApp(),
    ),
  );
}
