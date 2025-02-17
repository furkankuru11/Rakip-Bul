import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    try {
      // iOS için özel kontrol
      if (Platform.isIOS) {
        // iOS bildirim izinlerini iste
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // FCM izinleri
      final notificationSettings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.authorized) {
        // Token'ı al ve kaydet
        String? token;
        if (Platform.isIOS) {
          // iOS için önce APNS token'ı kontrol et
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            token = await _messaging.getToken();
          }
        } else {
          // Android için direkt token al
          token = await _messaging.getToken();
        }

        if (token != null) {
          await saveUserToken(token);
          print('📱 FCM Token: $token');
        }
      }

      // Local bildirim ayarları
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings =
          InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details);
        },
      );

      // Arka plan mesajları
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Uygulama açıkken gelen mesajlar
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      print('❌ Bildirim servisi başlatma hatası: $e');
    }
  }

  static Future<DocumentSnapshot?> getCurrentUser() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
  }

  static Future<void> saveUserToken(String token) async {
    final user = await getCurrentUser();
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({'fcmToken': token});
    }
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (message.data['type'] == 'message') {
      await _showMessageNotification(
        title: message.data['senderName'] ?? 'Yeni Mesaj',
        body: message.data['message'] ?? '',
        chatId: message.data['chatId'],
      );
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.data['type'] == 'message') {
      await _showMessageNotification(
        title: message.data['senderName'] ?? 'Yeni Mesaj',
        body: message.data['message'] ?? '',
        chatId: message.data['chatId'],
      );
    }
  }

  static Future<void> _showMessageNotification({
    required String title,
    required String body,
    required String chatId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Mesajlar',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      chatId.hashCode,
      title,
      body,
      details,
      payload: chatId,
    );

    // Badge sayısını güncelle
    await _updateBadgeCount();
  }

  static Future<void> _updateBadgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('device_id');

    if (currentUserId == null) return;

    // Tüm okunmamış mesajları say
    final unreadCount = await _getUnreadMessageCount(currentUserId);

    // Badge'i güncelle
    await _notifications.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(defaultPresentBadge: true),
      ),
    );

    if (Platform.isIOS) {
      await _notifications.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(defaultPresentBadge: true),
        ),
      );
    }
  }

  static Future<int> _getUnreadMessageCount(String userId) async {
    final chats = await _firestore
        .collection('chats')
        .where('members', arrayContains: userId)
        .get();

    int total = 0;
    for (var chat in chats.docs) {
      final data = chat.data();
      total += (data['unreadCount'] ?? 0) as int;
    }

    return total;
  }

  static void _handleNotificationTap(NotificationResponse details) {
    // Bildirime tıklandığında sohbet ekranına yönlendir
    if (details.payload != null) {
      // Navigator ile sohbet ekranına git
    }
  }

  static Future<void> resetBadge() async {
    if (Platform.isIOS) {
      await _notifications.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(defaultPresentBadge: true),
        ),
      );
    }
  }
}
