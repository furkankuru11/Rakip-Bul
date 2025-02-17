import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rakipbul/screens/anasayfa.dart';
import 'screens/registration_steps/step1_name.dart';
import 'firebase_options.dart';
import 'screens/registration_steps/step5_height_weight.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'services/chat_service.dart';
import 'package:flutter/services.dart';

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

  // Notification işlemlerini try-catch içine alalım
  try {
    if (Platform.isIOS) {
      print('iOS için bildirim izinleri isteniyor...');
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true, // Geçici izin ekledik
      );
      print('Bildirim izin durumu: ${settings.authorizationStatus}');
    }
  } catch (e) {
    print('Bildirim ayarları yapılırken hata: $e');
    // Bildirim hatası uygulamayı engellemeyecek
  }

  print('Uygulama arayüzü başlatılıyor...');
  runApp(const HaliSahaApp());
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
