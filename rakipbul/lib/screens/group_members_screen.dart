import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? currentUserId;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('device_id');

    // Yönetici kontrolü
    final groupDoc =
        await _firestore.collection('groups').doc(widget.groupId).get();
    setState(() {
      isAdmin = groupDoc.data()?['adminIds']?.contains(currentUserId) ?? false;
    });
  }

  Future<void> _toggleAdmin(String userId) async {
    if (!isAdmin) return; // Sadece yöneticiler yetki verebilir

    final groupRef = _firestore.collection('groups').doc(widget.groupId);
    final groupDoc = await groupRef.get();
    List<String> adminIds =
        List<String>.from(groupDoc.data()?['adminIds'] ?? []);

    if (adminIds.contains(userId)) {
      adminIds.remove(userId);
    } else {
      adminIds.add(userId);
    }

    await groupRef.update({'adminIds': adminIds});
    setState(() {}); // UI'ı yenile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.groupName} Üyeleri'),
        backgroundColor: Colors.green.shade50,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData = groupSnapshot.data?.data() as Map<String, dynamic>?;
          if (groupData == null) {
            return const Center(child: Text('Grup bilgileri bulunamadı'));
          }

          final members = List<String>.from(groupData['members'] ?? []);
          final adminIds = List<String>.from(groupData['adminIds'] ?? []);
          final creatorId = groupData['createdBy'];

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final memberId = members[index];
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(memberId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  if (userData == null) {
                    return const SizedBox();
                  }

                  final isCreator = memberId == creatorId;
                  final isMemberAdmin = adminIds.contains(memberId);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        (userData['name'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(userData['name'] ?? 'İsimsiz Kullanıcı'),
                        const SizedBox(width: 8),
                        if (isCreator)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Kurucu',
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                        else if (isMemberAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Yönetici',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    trailing: isAdmin && !isCreator && memberId != currentUserId
                        ? IconButton(
                            icon: Icon(
                              isMemberAdmin ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                            onPressed: () => _toggleAdmin(memberId),
                          )
                        : null,
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
