import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'chat_list_screen.dart';
import '../services/chat_service.dart';
import 'date_screen.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'search_match_screen.dart';

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
  StreamSubscription? _unreadSubscription;
  int _unreadCount = 0;

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
      _listenToUnreadMessages();
    } catch (e) {
      print('❌ Initialize hatası: $e');
    }
  }
  Future<void> _requestLocationPermission() async {
  final status = await Permission.location.request();
  
  if (status.isDenied) {
    // Kullanıcı izni reddetti
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konum izni gerekli')),
    );
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

  void _listenToUnreadMessages() {
    _unreadSubscription = _chatService.unreadMessagesStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });
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
    _unreadSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const DateScreen(),
    const SearchMatchScreen(),
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
                icon: Icon(Icons.sports_soccer_outlined),
                activeIcon: Icon(Icons.sports_soccer),
                label: 'Maç Arayanlar',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Ana Sayfa',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.message_outlined),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            _unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  children: [
                    const Icon(Icons.message),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            _unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
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
