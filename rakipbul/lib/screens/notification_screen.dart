import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'player_search_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? currentUserId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('device_id');
    setState(() => isLoading = false);
  }

  Future<void> _acceptFriendRequest(String requestId, String senderId) async {
    try {
      // İsteği kabul et
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
      });

      // Her iki kullanıcının friends array'ini güncelle
      final currentUserDoc = await _firestore
          .collection('users')
          .where('deviceId', isEqualTo: currentUserId)
          .get();

      if (currentUserDoc.docs.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentUserDoc.docs.first.id)
            .update({
          'friends': FieldValue.arrayUnion([senderId])
        });
      }

      final senderDoc = await _firestore
          .collection('users')
          .where('deviceId', isEqualTo: senderId)
          .get();

      if (senderDoc.docs.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(senderDoc.docs.first.id)
            .update({
          'friends': FieldValue.arrayUnion([currentUserId])
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arkadaşlık isteği kabul edildi')),
      );

      // PlayerSearchScreen'i yenile
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PlayerSearchScreen()),
        );
      }
    } catch (e) {
      print('Arkadaşlık isteği kabul hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'rejected',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Arkadaşlık isteği reddedildi')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('friendRequests')
            .where('receiverId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return const Center(child: Text('Bildirim bulunmuyor'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final senderId = request['senderId'];

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(senderId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final senderData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final senderName =
                      senderData['name'] ?? 'Bilinmeyen Kullanıcı';

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          senderName[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: const Text(
                        'Size Arkadaşlık İsteği Gönderdi',
                        style: TextStyle(fontSize: 14),
                      ),
                      trailing: SizedBox(
                        width: 96, // İkonlar için sabit genişlik
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check),
                              color: Colors.green,
                              iconSize: 28,
                              onPressed: () =>
                                  _acceptFriendRequest(request.id, senderId),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              color: Colors.red,
                              iconSize: 28,
                              onPressed: () => _rejectFriendRequest(request.id),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
