import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rakipbul/screens/anasayfa.dart';
import 'screens/registration_steps/step1_name.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/chat_service.dart';
import 'services/firebase_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert' show json;
import 'screens/chat_screen.dart';  // Chat ekranı import'u

// Global değişken olarak tanımla
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  print('Uygulama başlatılıyor...');
  WidgetsFlutterBinding.ensureInitialized();

  print('Firebase başlatılıyor...');
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    print('Firebase başarıyla başlatıldı');
  } catch (e) {
    print('Firebase başlatılırken hata: $e');
    return; // Firebase başlatılamazsa uygulamayı başlatma
  }

  // Bildirimleri başlat
  await _initNotifications();
  
  // Bildirim izinlerini iste
  await _requestNotificationPermissions();
  
  // Arka plan mesaj işleyicisini ayarla
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Ön plan mesaj işleyicisini ayarla
  await _setupForegroundMessaging();

  print('Uygulama arayüzü başlatılıyor...');
  runApp(const HaliSahaApp());
}

// Bildirimleri başlatma
Future<void> _initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // Bildirime tıklama işleyicisi
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      if (details.payload != null) {
        final payloadData = json.decode(details.payload!);
        if (payloadData['type'] == 'message') {
          // Global navigator key kullanarak yönlendirme
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                friendId: payloadData['senderId'],
                friendName: payloadData['senderName'],
                friendImage: payloadData['senderImage'],
                isGroup: false,
                
                  
              ),
            ),
          );
        }
      }
    },
  );
}

// İzinleri isteme
Future<void> _requestNotificationPermissions() async {
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
}

// Arka plan mesaj işleyicisi
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Arka plan bildirimi alındı: ${message.notification?.title}');
  _showNotification(message);
}

// Ön plan mesaj ayarları
Future<void> _setupForegroundMessaging() async {
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Ön plan bildirimi alındı: ${message.notification?.title}');
    _showNotification(message);
  });
}

// Bildirimi gösterme
Future<void> _showNotification(RemoteMessage message) async {
  if (message.data['type'] == 'message') {
    const AndroidNotificationDetails messageChannelSpecifics =
        AndroidNotificationDetails(
      'messages',
      'Mesajlar',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Profil resmi
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: messageChannelSpecifics);

    // Payload'a tıklama için gerekli bilgileri ekle
    final payload = json.encode({
      'type': 'message',
      'senderId': message.data['senderId'],
      'senderName': message.notification?.title,
      'senderImage': message.data['senderImage'],
    });

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Yeni Mesaj',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: payload,
    );
  } else {
    // Diğer bildirimler için mevcut kanal
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'friend_requests',
      'Arkadaşlık İstekleri',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Yeni Bildirim',
      message.notification?.body ?? '',
      platformChannelSpecifics,
    );
  }
}

class HaliSahaApp extends StatefulWidget {
  const HaliSahaApp({super.key});

  @override
  State<HaliSahaApp> createState() => _HaliSahaAppState();
}

class _HaliSahaAppState extends State<HaliSahaApp> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _errorMessage = '';
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    print('InitialScreen initState çağrıldı');
    WidgetsBinding.instance.addObserver(this);
    _checkDeviceRegistration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.dispose(); // Sadece uygulama kapanırken dispose et
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _chatService.setOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Uygulama arka planda veya kapatıldığında
        break;
    }
  }

  Future<void> _checkDeviceRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');

      // Firestore'da bu device_id ile kullanıcı var mı kontrol et
      final userDoc = await _firestore.collection('users').doc(deviceId).get();

      if (mounted) {
        if (userDoc.exists) {
          // Kullanıcı zaten kayıtlı, ana sayfaya yönlendir
          print('Kullanıcı kaydı bulundu, ana sayfaya yönlendiriliyor...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnaSayfa()),
          );
        } else {
          // Kullanıcı kayıtlı değil, kayıt ekranına yönlendir
          print(
              'Kullanıcı kaydı bulunamadı, kayıt ekranına yönlendiriliyor...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NameStep()),
          );
        }
      }
    } catch (e) {
      print('Hata oluştu: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';
        });
      }
    }
    FirebaseService.instance.getDeviceToken();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    
      debugShowCheckedModeBanner: false,
      title: 'Halı Saha Bul',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    print('InitialScreen initState çağrıldı');
    _checkDeviceRegistration();
  }

  Future<void> _checkDeviceRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');

      // Firestore'da bu device_id ile kullanıcı var mı kontrol et
      final userDoc = await _firestore.collection('users').doc(deviceId).get();

      if (mounted) {
        if (userDoc.exists) {
          // Kullanıcı zaten kayıtlı, ana sayfaya yönlendir
          print('Kullanıcı kaydı bulundu, ana sayfaya yönlendiriliyor...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AnaSayfa()),
          );
        } else {
          // Kullanıcı kayıtlı değil, kayıt ekranına yönlendir
          print(
              'Kullanıcı kaydı bulunamadı, kayıt ekranına yönlendiriliyor...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NameStep()),
          );
        }
      }
    } catch (e) {
      print('Hata oluştu: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Bir hata oluştu. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Uygulama Başlatılıyor...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else if (_errorMessage.isNotEmpty) ...[
              Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = '';
                  });
                  _checkDeviceRegistration();
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
