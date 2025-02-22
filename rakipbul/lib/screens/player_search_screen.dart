import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rakipbul/models/user_model.dart';
import 'package:rakipbul/screens/chat_screen.dart';
import 'package:rakipbul/screens/friend_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakipbul/services/chat_service.dart';
import 'package:rakipbul/screens/other_profile.dart';
import 'package:geolocator/geolocator.dart';


class PlayerSearchScreen extends StatefulWidget {
  final int initialTabIndex;
  
  const PlayerSearchScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<PlayerSearchScreen> createState() => _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends State<PlayerSearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  String? currentUserId;
  List<UserModel> friends = [];
  List<UserModel> searchResults = [];
  List<UserModel> matchSeekers = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUser();
    await _loadFriends();
    await _loadMatchSeekers();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId == null) {
        print('❌ SharedPreferences\'da device_id bulunamadı');
        // Device ID'yi kontrol et
        final userDoc = await _firestore
            .collection('users')
            .where('deviceId', isNotEqualTo: null)
            .get();

        if (userDoc.docs.isNotEmpty) {
          final foundDeviceId = userDoc.docs.first.data()['deviceId'];
          await prefs.setString('device_id', foundDeviceId);
          setState(() => currentUserId = foundDeviceId);
          print('✅ Device ID Firestore\'dan alındı: $foundDeviceId');
        } else {
          print('❌ Firestore\'da da kullanıcı bulunamadı');
        }
      } else {
        setState(() => currentUserId = deviceId);
        print('✅ Device ID başarıyla yüklendi: $deviceId');
      }
    } catch (e) {
      print('❌ Kullanıcı yükleme hatası: $e');
    }
  }

  Future<void> _loadFriends() async {
    if (currentUserId == null) {
      print('❌ currentUserId bulunamadı, arkadaşlar yüklenemedi');
      return;
    }

    try {
      print('🔍 Arkadaşlar yükleniyor... CurrentUserId: $currentUserId');

      // Kabul edilmiş arkadaşlık isteklerini kontrol et
      final acceptedRequestsAsSender = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final acceptedRequestsAsReceiver = await _firestore
          .collection('friendRequests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      // Arkadaş ID'lerini topla
      final Set<String> friendIds = {};

      // Gönderilen isteklerden arkadaşları ekle
      for (var doc in acceptedRequestsAsSender.docs) {
        friendIds.add(doc['receiverId']);
        print('👥 Gönderilen istekten arkadaş bulundu: ${doc['receiverId']}');
      }

      // Alınan isteklerden arkadaşları ekle
      for (var doc in acceptedRequestsAsReceiver.docs) {
        friendIds.add(doc['senderId']);
        print('👥 Alınan istekten arkadaş bulundu: ${doc['senderId']}');
      }

      print('📊 Toplam arkadaş sayısı: ${friendIds.length}');
      if (friendIds.isEmpty) {
        print('ℹ️ Hiç arkadaş bulunamadı');
        setState(() => friends = []);
        return;
      }

      // Her bir arkadaşın detaylı bilgilerini al
      final friendsList = <UserModel>[];
      for (var friendId in friendIds) {
        print('🔍 Arkadaş bilgileri alınıyor... ID: $friendId');

        final friendDoc = await _firestore
            .collection('users')
            .where('deviceId', isEqualTo: friendId)
            .get();

        if (friendDoc.docs.isNotEmpty) {
          final friendData = friendDoc.docs.first.data();
          friendData['userId'] = friendData['deviceId'];
          print('✅ Arkadaş detayları bulundu: ${friendData['name']}');
          friendsList.add(UserModel.fromMap(friendData));
        } else {
          print('❌ Arkadaş bilgileri bulunamadı: $friendId');
        }
      }

      if (mounted) {
        setState(() {
          friends = friendsList;
          print('✅ Arkadaş listesi güncellendi. Toplam: ${friends.length}');
          for (var friend in friends) {
            print('  👤 ${friend.name} (${friend.userCode})');
          }
        });
      }
    } catch (e) {
      print('❌ Arkadaşları yükleme hatası: $e');
    }
  }

  Future<void> _loadMatchSeekers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('availability', isNull: false)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final availabilities = List<Map<String, dynamic>>.from(data['availability'] ?? []);
        
        if (availabilities.isNotEmpty) {
          // Her müsaitlik için son tarihi hesapla ve Firestore'a kaydet
          for (var availability in availabilities) {
            final date = DateTime.parse(availability['date']);
            final endTime = availability['endTime'].split(':');
            final endDateTime = DateTime(
              date.year, date.month, date.day,
              int.parse(endTime[0]), int.parse(endTime[1]),
            );

            await _firestore.collection('users').doc(doc.id).update({
              'availabilityEndTime': endDateTime.toIso8601String(),
              'availabilityStartTime': DateTime(
                date.year, date.month, date.day,
                int.parse(availability['startTime'].split(':')[0]),
                int.parse(availability['startTime'].split(':')[1]),
              ).toIso8601String(),
              'availabilityLocation': {
                'latitude': availability['latitude'],
                'longitude': availability['longitude'],
              },
              'isAvailable': true,
            });
          }
        }
      }

      // Kullanıcıları müsaitlik zamanlarına göre al
      final seekers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['userId'] = doc.id;
        return UserModel.fromMap({...data, 'availabilities': data['availability'] ?? []});
      }).toList();

      setState(() => matchSeekers = seekers);
    } catch (e) {
      print('❌ Maç arayanları yükleme hatası: $e');
    }
  }

  Future<void> _searchUser(String query) async {
    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    try {
      // Mevcut kullanıcı hariç tüm kullanıcıları getir
      var snapshot = await _firestore
          .collection('users')
          .where('deviceId', isNotEqualTo: currentUserId) // Kendisi hariç
          .get();

      setState(() {
        searchResults = snapshot.docs.map((doc) {
          final data = doc.data();
          data['userId'] = doc.id;
          return UserModel.fromMap(data);
        }).where((user) {
          // İsim veya kod ile filtreleme
          final name = user.name.toLowerCase();
          final userCode = user.userCode.toLowerCase();
          final searchQuery = query.toLowerCase();
          return name.contains(searchQuery) || userCode.contains(searchQuery);
        }).toList();
      });

      print('Bulunan kullanıcı sayısı: ${searchResults.length}');
    } catch (e) {
      print('Arama hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arama sırasında bir hata oluştu: $e')),
        );
      }
    }
  }

  Future<void> _addFriend(String friendId) async {
    if (currentUserId == null) return;

    await _firestore.collection('users').doc(currentUserId).update({
      'friends': FieldValue.arrayUnion([friendId])
    });

    await _loadFriends();
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    if (currentUserId == null) return;

    try {
      // İstek zaten var mı kontrol et
      final existingRequest = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zaten bir istek gönderilmiş')),
        );
        return;
      }

      // Yeni istek oluştur
      await _firestore.collection('friendRequests').add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arkadaşlık isteği gönderildi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  Future<void> _cancelFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arkadaşlık isteği geri çekildi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  @override
  bool get wantKeepAlive => true; // Tab değişiminde state'i koru

  // Online durumu için stream controller
  Stream<bool> _getOnlineStatus(String userId) {
    return Stream.periodic(const Duration(milliseconds: 500), (_) {
      return _chatService.isUserOnline(userId);
    }).distinct(); // Sadece değişiklik olduğunda güncelle
  }

  // Arkadaş listesi widget'ı
  Widget _buildFriendItem(UserModel friend) {
    return StreamBuilder<bool>(
      stream: _chatService.userStatusStream(friend.userId),
      initialData: _chatService.isUserOnline(friend.userId),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OtherProfileScreen(
                    userData: friend.toMap(),
                  ),
                ),
              );
            },
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    friend.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Online/Offline durumu
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.red,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isOnline ? Colors.green : Colors.red)
                              .withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            title: Text(friend.name),
            subtitle: Text(friend.position),
            trailing: IconButton(
              icon: Icon(
                Icons.message_rounded,
                color: Colors.green.shade700,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      friendId: friend.userId,
                      friendName: friend.name,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Maç arayanlar sekmesinin görünümünü güncelle
  Widget _buildMatchSeekersTab(List<UserModel> players) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('İsim',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
              Expanded(
                child: Text('Mevki',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
              Expanded(
                child: Text('Puan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
              Expanded(
                child: Text('Müsaitlik',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
              Expanded(
                child: Text('Konum',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final user = players[index];
              final availabilityLocation = user.availabilityLocation;
              final hasLocation = availabilityLocation != null && 
                  availabilityLocation['latitude'] != null && 
                  availabilityLocation['longitude'] != null;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherProfileScreen(
                        userData: {
                          ...user.toMap(),
                          'userId': user.userId,
                          'availabilityStartTime': user.availabilityStartTime,
                          'availabilityEndTime': user.availabilityEndTime,
                          'availabilityLocation': user.availabilityLocation,
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          user.position,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          user.rating > 0 ? '★${user.rating.toStringAsFixed(1)}' : '-',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showAvailabilityDetails(context, user),
                          child: Icon(
                            Icons.access_time_filled,
                            color: Colors.green.shade700,
                            size: 22,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          hasLocation ? '${(user.distance ?? 0).toStringAsFixed(1)} km' : '-',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAvailabilityDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.access_time,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Müsait Zamanlar',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Müsaitlik listesi
              if (user.availabilities.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Müsait zaman bulunmuyor',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...user.availabilities.map((a) {
                  final date = DateTime.parse(a['date']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.shade100,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Tarih
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Saat
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.shade200,
                            ),
                          ),
                          child: Text(
                            '${a['startTime']} - ${a['endTime']}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              const SizedBox(height: 16),
              // Kapat butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvailabilityDetails(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${user.name} - Müsaitlik Zamanları',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      user.availabilityStartTime != null ? 
                      '${DateTime.parse(user.availabilityStartTime!).hour}:00 - ${DateTime.parse(user.availabilityEndTime!).hour}:00' 
                      : 'Belirtilmemiş',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Kapat', style: TextStyle(color: Colors.grey.shade700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAvailabilities(List<Map<String, dynamic>> availabilities) {
    if (availabilities.isEmpty) return 'Belirtilmedi';
    final availability = availabilities.first;
    final date = DateTime.parse(availability['date']);
    return '${date.day}/${date.month} ${availability['startTime']} - ${availability['endTime']}';
  }

  Stream<List<UserModel>> _getFilteredPlayersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('isSearchingMatch', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .where('deviceId', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          
          // Her bir dokümanı kontrol et ve süresi geçenleri temizle
          snapshot.docs.forEach((doc) async {
            final data = doc.data();
            if (data['availabilityEndTime'] != null) {
              final endTime = DateTime.parse(data['availabilityEndTime']);
              
              if (endTime.isBefore(now)) {
                await _firestore.collection('users').doc(doc.id).update({
                  'availability': [],
                  'isSearchingMatch': false,
                  'isAvailable': false,
                  'availabilityEndTime': null,
                  'availabilityStartTime': null,
                  'availabilityLocation': null,
                });
              }
            }
          });

          // Sadece aktif müsaitlikleri olan kullanıcıları döndür
          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                if (data['availabilityEndTime'] == null) return false;
                
                final endTime = DateTime.parse(data['availabilityEndTime']);
                return endTime.isAfter(now);
              })
              .map((doc) => UserModel.fromMap({...doc.data(), 'userId': doc.id}))
              .toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Oyuncu Ara'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Arkadaşlarım'),
              Tab(text: 'Oyuncu Ara'),
              Tab(text: 'Maç Arayanlar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Arkadaşlar
            ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) => _buildFriendItem(friends[index]),
            ),
            // Oyuncu Arama
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Ahmet veya AHM1234',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: _searchUser,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      final bool isFriend =
                          friends.any((friend) => friend.userId == user.userId);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImage != null
                              ? NetworkImage(user.profileImage!)
                              : null,
                          child: user.profileImage == null
                              ? Text(user.name[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user.name),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Kod: ${user.userCode}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(user.position),
                          ],
                        ),
                        trailing: isFriend
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('friendRequests')
                                    .where('senderId', isEqualTo: currentUserId)
                                    .where('receiverId', isEqualTo: user.userId)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    );
                                  }

                                  final requests = snapshot.data?.docs ?? [];
                                  if (requests.isEmpty) {
                                    return IconButton(
                                      icon: const Icon(Icons.person_add),
                                      style: IconButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        backgroundColor:
                                            Colors.blue.withOpacity(0.1),
                                        padding: const EdgeInsets.all(8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _sendFriendRequest(user.userId),
                                    );
                                  }

                                  final request = requests.first;
                                  final status = request.get('status');

                                  if (status == 'pending') {
                                    return IconButton(
                                      icon: const Icon(Icons.pending_outlined),
                                      style: IconButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      onPressed: () =>
                                          _cancelFriendRequest(request.id),
                                      tooltip: 'İsteği geri çek',
                                    );
                                  } else if (status == 'accepted') {
                                    return const Icon(Icons.check_circle,
                                        color: Colors.green);
                                  }

                                  return IconButton(
                                    icon: const Icon(Icons.person_add),
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      backgroundColor:
                                          Colors.blue.withOpacity(0.1),
                                      padding: const EdgeInsets.all(8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _sendFriendRequest(user.userId),
                                  );
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Maç Arayanlar
            StreamBuilder<List<UserModel>>(
              stream: _getFilteredPlayersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hata oluştu: ${snapshot.error}'));
                }

                final players = snapshot.data ?? [];

                if (players.isEmpty) {
                  return const Center(child: Text('Müsait oyuncu bulunmuyor'));
                }

                return _buildMatchSeekersTab(players);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Hiçbir şeyi iptal etme veya dispose etme
    super.dispose();
  }
}
