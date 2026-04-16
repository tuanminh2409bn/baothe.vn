import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_card_model.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;
    
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  Future<void> schedulePaymentReminders(UserCard card) async {
    if (kIsWeb) return;
    
    // Nhắc trước ngày chốt sao kê 1 ngày
    await _scheduleNotification(
      id: card.id.hashCode,
      title: 'Sắp đến ngày chốt sao kê',
      body: 'Thẻ ${card.cardName} sẽ chốt sao kê vào ngày ${card.statementDay}. Hãy kiểm tra lại các khoản chi tiêu.',
      day: card.statementDay - 1 > 0 ? card.statementDay - 1 : 28, // Giả định đơn giản cho tháng 2
    );

    // Nhắc trước ngày hạn thanh toán 3 ngày
    await _scheduleNotification(
      id: card.id.hashCode + 1,
      title: 'Nhắc thanh toán thẻ tín dụng',
      body: 'Thẻ ${card.cardName} sắp đến hạn thanh toán vào ngày ${card.dueDay}. Đừng quên thanh toán để tránh phí phạt nhé!',
      day: card.dueDay - 3 > 0 ? card.dueDay - 3 : 25,
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int day,
  }) async {
    if (kIsWeb) return;
    
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, day, 9, 0); // 9:00 AM

    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, day, 9, 0);
    }

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_reminders',
          'Nhắc nhở thanh toán',
          channelDescription: 'Thông báo nhắc nhở chốt sao kê và thanh toán thẻ tín dụng',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }
}

final notificationServiceProvider = Provider((ref) => NotificationService());
