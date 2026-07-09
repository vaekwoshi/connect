import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'core/data/db_helper.dart';
import 'core/data/app_mode.dart';
import 'ui/screens/home_screen.dart';

import 'core/security/notification_helper.dart';

import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await notificationHelper.init();
    await notificationHelper.requestPermissions();
  }
  await dbService.initDatabase();

  // 저장된 데이터 수집 모드(제1/제2) 복원
  final profile = await dbService.getProfile();
  appModeNotifier.value = appModeFromDb(profile?['data_mode'] as String?);

  runApp(const SeculApp());
}

/// 세끌 어플리케이션 메인 진입점
class SeculApp extends StatelessWidget {
  const SeculApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '세끌',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
