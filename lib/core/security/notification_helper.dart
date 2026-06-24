import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS — 초기화 시점에 알림 권한 요청 (버전 안전)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
  }

  Future<void> requestPermissions() async {
    // Android 13+ 알림·정확알람 권한
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
    // iOS 권한은 init의 DarwinInitializationSettings에서 요청됨
  }

  Future<void> showImmediateNotification({required int id, required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'tax_nudge_channel',
      '세금·절세 알림',
      channelDescription: '공제 문턱 도달 등 절세 가이드 알림',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> scheduleNotification({required int id, required String title, required String body, required Duration delay}) async {
    await scheduleAtDate(
      id: id,
      title: title,
      body: body,
      when: tz.TZDateTime.now(tz.local).add(delay),
    );
  }

  /// 절대 시각 예약. [matchComponents]를 주면 매월·매일 반복.
  Future<void> scheduleAtDate({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    DateTimeComponents? matchComponents,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'tax_schedule_channel',
      '세금 일정·기록 알림',
      channelDescription: '신고 시즌·가계부 기록 리마인더',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    final tzWhen = when is tz.TZDateTime
        ? when
        : tz.TZDateTime.from(when, tz.local);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );
    } on PlatformException catch (e) {
      // 정확 알람 권한이 없으면(exact_alarms_not_permitted 등) 비정확 모드로라도 예약.
      // 안 울리는 것보다 몇 분 오차로라도 울리는 게 낫다.
      debugPrint('exact schedule failed (${e.code}) → 비정확 모드 폴백');
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );
    }
  }

  /// 정확 알람 예약이 가능한지(Android 12+ 권한 상태). 불가면 안내·폴백 판단에 사용.
  Future<bool> canScheduleExact() async {
    final android = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // iOS 등
    final ok = await android.canScheduleExactNotifications();
    return ok ?? true;
  }

  /// 현재 예약 대기 중인 알림 개수(진단용).
  Future<int> pendingCount() async {
    final p = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return p.length;
  }

  Future<void> cancel(int id) => flutterLocalNotificationsPlugin.cancel(id: id);

  Future<void> cancelAll() => flutterLocalNotificationsPlugin.cancelAll();
}

final notificationHelper = NotificationHelper();
