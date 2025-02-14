import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_search_screen.dart';
import 'join_team_screen.dart';
import 'create_match_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _updateFCMToken();
    _checkTodayMatch();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      // currentUserId'yi ayarla
      setState(() {
        currentUserId = deviceId;
      });

      if (deviceId != null) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('deviceId', isEqualTo: deviceId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            userData = querySnapshot.docs.first.data();
          });
        }
      }
    } catch (e) {
      print('Kullanıcı yükleme hatası: $e');
    }
  }

  Future<void> _updateFCMToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (deviceId != null && fcmToken != null) {
        await _firestore.collection('users').doc(deviceId).update({
          'fcmToken': fcmToken,
        });
      }
    } catch (e) {
      print('FCM token güncelleme hatası: $e');
    }
  }

  Future<void> sendFriendRequest(String targetUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myDeviceId = prefs.getString('device_id');

      // Hedef kullanıcının FCM token'ını al
      final targetUser =
          await _firestore.collection('users').doc(targetUserId).get();
      final targetFcmToken = targetUser.data()?['fcmToken'];

      if (targetFcmToken != null) {
        // Bildirim gönder
        await FirebaseMessaging.instance.sendMessage(
          to: targetFcmToken,
          data: {
            'type': 'friend_request',
            'senderId': myDeviceId ?? '',
            'senderName': userData?['name'] ?? 'Bir kullanıcı',
          },
        );

        // Arkadaşlık isteğini Firestore'a kaydet
        await _firestore.collection('friendRequests').add({
          'senderId': myDeviceId,
          'receiverId': targetUserId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Arkadaşlık isteği gönderme hatası: $e');
    }
  }

  Future<void> _checkTodayMatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final matchQuery = await FirebaseFirestore.instance
          .collection('matches')
          .where('creatorId', isEqualTo: deviceId)
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .get();

      if (matchQuery.docs.isNotEmpty) {
        // Bugün maç varsa maçlarım tab'ına yönlendir
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMatchScreen(initialTab: 1),
            ),
          );
        }
      } else {
        // Bugün maç yoksa maç oluşturma tab'ına yönlendir
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMatchScreen(initialTab: 0),
            ),
          );
        }
      }
    } catch (e) {
      print('Maç kontrolü hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Center(child: Text('Kullanıcı bilgileri bulunamadı'));
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Üst Kısım - Logo ve Profil
              Row(
                children: [
                  // Logo Container
                  Container(
                    height: 45,
                    width: 150,
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/images/logo.png'),
                        fit: BoxFit.contain,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const Spacer(),

                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationScreen()),
                      );
                    },
                    icon: const Icon(Icons.notifications),
                  ),
                  // Profil Avatar
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: userData!['profileImage'] != null
                          ? CircleAvatar(
                              radius: 19,
                              backgroundImage:
                                  NetworkImage(userData!['profileImage']),
                            )
                          : Text(
                              (userData!['name'] ?? 'K')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Saha Görüntüsü ve Kullanıcı Bilgileri
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: const DecorationImage(
                          image: NetworkImage(
                              'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?ixlib=rb-4.0.3'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildProfileItem(Icons.sports_soccer, 'Ayak',
                              userData!['preferredFoot'] ?? 'Belirtilmedi'),
                          _buildProfileItem(Icons.person, 'Mevki',
                              userData!['position'] ?? 'Belirtilmedi'),
                          _buildProfileItem(
                              Icons.height, 'Boy', '${userData!['height']} cm'),
                          _buildProfileItem(Icons.monitor_weight, 'Kilo',
                              '${userData!['weight']} kg'),
                          _buildProfileItem(Icons.numbers, 'Yaş',
                              userData!['age'] ?? 'Belirtilmedi'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // İstatistikler
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('29', 'Gol'),
                  _buildStatItem('23', 'Maç'),
                  _buildStatItem('38', 'Asist'),
                  _buildStatItem('33', 'Galibiyet'),
                ],
              ),
              const SizedBox(height: 20),

              // Tarih Seçici
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFormattedDate(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final date =
                              DateTime.now().add(Duration(days: index - 2));
                          final isToday = date.day == DateTime.now().day;
                          return _buildDateCircle(date, isToday);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ana Butonlar
              _buildMenuItem(
                'Oyuncu Ara',
                Icons.search,
                Colors.green,
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                'Takıma Katıl',
                Icons.group_add,
                Colors.grey[800]!,
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                'Maç Oluştur',
                Icons.add_circle_outline,
                Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () async {
        switch (title) {
          case 'Oyuncu Ara':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PlayerSearchScreen()),
            );
            break;
          case 'Takıma Katıl':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const JoinTeamScreen()),
            );
            break;
          case 'Maç Oluştur':
            await _checkTodayMatch();
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Çevrimiçi Oyuncular',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBox(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTimeBox(String time, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    final days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year} ${days[date.weekday - 1]}';
  }

  Widget _buildDateCircle(DateTime date, bool isToday) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 45,
      child: Column(
        children: [
          Text(
            _getShortDayName(date.weekday),
            style: TextStyle(
              fontSize: 12,
              color: isToday ? Colors.green : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? Colors.green : Colors.transparent,
              border: Border.all(
                color: isToday ? Colors.green : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.black,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getShortDayName(int weekday) {
    final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
