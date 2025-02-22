import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakipbul/models/user_model.dart';
import 'package:rakipbul/screens/other_profile.dart';

class SearchMatchScreen extends StatefulWidget {
  const SearchMatchScreen({super.key});

  @override
  State<SearchMatchScreen> createState() => _SearchMatchScreenState();
}

class _SearchMatchScreenState extends State<SearchMatchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? currentUserId;
  bool _sortByDistance = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentUserId = prefs.getString('device_id'));
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
          
          // Süresi geçmiş müsaitlikleri temizle
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

          // Aktif müsaitlikleri olan kullanıcıları döndür
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Arayanlar'),
      ),
      body: StreamBuilder<List<UserModel>>(
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

          // Konuma göre sıralama
          if (_sortByDistance) {
            players.sort((a, b) {
              final distanceA = a.distance ?? double.infinity;
              final distanceB = b.distance ?? double.infinity;
              return distanceA.compareTo(distanceB);
            });
          }

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
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _sortByDistance = !_sortByDistance;
                          });
                        },
                        child: Row(
                          children: [
                            Text(
                              'Konum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            if (_sortByDistance)
                              Icon(
                                Icons.arrow_downward,
                                size: 14,
                                color: Colors.grey.shade800,
                              ),
                          ],
                        ),
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
        },
      ),
    );
  }
}