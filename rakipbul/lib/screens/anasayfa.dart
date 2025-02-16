import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'chat_list_screen.dart';
import '../services/chat_service.dart';
import 'date_screen.dart';
import 'dart:async';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WidgetsBindingObserver {
  int _selectedIndex = 2;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _loadCurrentUser();
      await _chatService.initialize();
    } catch (e) {
      print('❌ Initialize hatası: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId != null) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('deviceId', isEqualTo: deviceId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            userData = querySnapshot.docs.first.data();
            isLoading = false;
            currentUserId = deviceId;
          });
        }
      }
    } catch (e) {
      print('❌ Kullanıcı yükleme hatası: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print('🟢 Uygulama ön planda');
        _chatService.initialize();
        break;
      case AppLifecycleState.inactive:
        print('⚪️ Uygulama inactive');
        break;
      case AppLifecycleState.paused:
        print('🟡 Uygulama arka planda');
        _chatService.setOffline();
        break;
      case AppLifecycleState.detached:
        print('🔴 Uygulama sonlandırıldı');
        _chatService.dispose();
        break;
      case AppLifecycleState.hidden:
        print('⚫️ Uygulama gizlendi');
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const DateScreen(),
    const MapScreen(),
    const HomeScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('friendRequests')
            .where('receiverId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          int badgeCount = 0;
          if (snapshot.hasData) {
            badgeCount = snapshot.data!.docs.length;
          }

          return BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 20,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.date_range_outlined),
                activeIcon: Icon(Icons.date_range),
                label: 'Takvim',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Harita',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Ana Sayfa',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.message_outlined),
                activeIcon: const Icon(Icons.message),
                label: 'Mesajlar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          );
        },
      ),
    );
  }
}
