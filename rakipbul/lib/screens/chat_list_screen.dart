import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  bool _mounted = true;
  StreamSubscription? _messageSubscription;
  bool _isUpdating = false;
  StreamSubscription? _onlineStatusSubscription;
  Map<String, bool> _onlineStatuses = {};
  late TabController _tabController;
  String? currentUserId;
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _filteredFriends = [];
  String _searchQuery = '';
  Timer? _debounce;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadChats();
    _setupOnlineStatus();
    _setupMessageListener();
    _loadCurrentUser();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('device_id');
      _isLoading = false;
    });
  }

  void _setupMessageListener() {
    _messageSubscription = _chatService.messageStream.listen((message) {
      if (_mounted && !_isUpdating) {
        _quickUpdate();
      }
    });
  }

  void _setupOnlineStatus() {
    _onlineStatusSubscription =
        _chatService.onlineStatusStream.listen((statuses) {
      if (_mounted) {
        setState(() {
          _onlineStatuses = statuses;
        });
      }
    });
  }

  Future<void> _quickUpdate() async {
    if (!_mounted || _isUpdating) return;

    _isUpdating = true;
    try {
      final newChats = await _chatService.getAllChats();
      if (_mounted) {
        setState(() {
          _chats = newChats;
        });
      }
    } catch (e) {
      print('Hızlı güncelleme hatası: $e');
    } finally {
      _isUpdating = false;
    }
  }

  Future<void> _loadChats() async {
    if (!_mounted) return;

    setState(() => _isLoading = true);
    try {
      final chats = await _chatService.getAllChats();
      if (_mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Sohbetler yüklenirken hata: $e');
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    _mounted = false;
    _messageSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            padding: EdgeInsets.all(5),
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            tabs: [
              Tab(text: 'Tümü'),
              Tab(text: 'Yeni Sohbet'),
              Tab(text: 'Grup Oluştur'),
              Tab(text: 'Gruplar'),
            ],
          ),
          title: const Text('Mesajlar'),
        ),
        body: TabBarView(
          children: [
            _buildChatList(),
            _buildNewChat(),
            _buildCreateGroup(),
            _buildGroupList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('type', isEqualTo: 'group')
          .where('members', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: groups.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final groupData = groups[index].data() as Map<String, dynamic>;

            // Güvenli veri çekme
            final lastMessageData = groupData['lastMessage'];
            String messageText = 'Henüz mesaj yok';
            String timeStr = '';

            if (lastMessageData != null &&
                lastMessageData is Map<String, dynamic>) {
              messageText = lastMessageData['message']?.toString() ?? '';

              final timestamp = lastMessageData['timestamp'];
              if (timestamp is Timestamp) {
                timeStr = _formatTime(timestamp.toDate());
              }
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.group, color: Colors.green.shade700),
                ),
                title: Text(
                  groupData['name']?.toString() ?? 'İsimsiz Grup',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  timeStr.isNotEmpty ? '$messageText • $timeStr' : messageText,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        friendId: groups[index].id,
                        friendName:
                            groupData['name']?.toString() ?? 'İsimsiz Grup',
                        isGroup: true,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNewChat() {
    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get()
              .then((doc) => FirebaseFirestore.instance
                  .collection('users')
                  .where('deviceId',
                      whereIn: List<String>.from(doc.data()?['friends'] ?? []))
                  .get()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            final friends = snapshot.data?.docs ?? [];

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Oyuncu Ara',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 2000), () {
                        setState(() {
                          _filteredFriends = friends.where((doc) {
                            final friend = doc.data() as Map<String, dynamic>;
                            final name =
                                friend['name'].toString().toLowerCase();
                            final position = (friend['position'] ?? '')
                                .toString()
                                .toLowerCase();
                            final searchLower = value.toLowerCase();
                            return name.contains(searchLower) ||
                                position.contains(searchLower);
                          }).toList();
                          _searchQuery = value;
                        });
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchQuery.isEmpty
                        ? friends.length
                        : _filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = (_searchQuery.isEmpty
                              ? friends[index]
                              : _filteredFriends[index])
                          .data() as Map<String, dynamic>;
                      final isOnline =
                          _chatService.isUserOnline(friend['deviceId']);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.green.shade50,
                            child: Text(
                              friend['name'][0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          title: Text(
                            friend['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(friend['position'] ?? ''),
                              ],
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  friendId: friend['deviceId'],
                                  friendName: friend['name'],
                                  isGroup: false,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCreateGroup() {
    List<String> selectedFriends = [];

    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get()
              .then((doc) => FirebaseFirestore.instance
                  .collection('users')
                  .where('deviceId',
                      whereIn: List<String>.from(doc.data()?['friends'] ?? []))
                  .get()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            final friends = snapshot.data?.docs ?? [];

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selectedFriends.length} kişi seçildi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (selectedFriends.isNotEmpty)
                        ElevatedButton(
                          onPressed: () {
                            // Grup oluştur
                            _createGroup(selectedFriends);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Grup Oluştur'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend =
                          friends[index].data() as Map<String, dynamic>;
                      final isSelected =
                          selectedFriends.contains(friend['deviceId']);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade50,
                            child: Text(
                              friend['name'][0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(friend['name']),
                          subtitle: Text(friend['position'] ?? ''),
                          trailing: Checkbox(
                            value: isSelected,
                            activeColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedFriends.add(friend['deviceId']);
                                } else {
                                  selectedFriends.remove(friend['deviceId']);
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup(List<String> members) async {
    try {
      final TextEditingController nameController = TextEditingController();
      // Grup adını al
      final groupName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Grup Adı'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Grup adını girin'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Oluştur'),
            ),
          ],
        ),
      );

      if (groupName == null || groupName.isEmpty) return;

      // Grup bilgilerini oluştur
      final groupData = {
        'name': groupName,
        'members': [...members, currentUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'lastMessage': {
          'message': 'Grup oluşturuldu',
          'senderId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'system'
        },
        'type': 'group',
        'unreadCount': 0,
      };

      // Grubu oluştur
      final groupRef =
          await FirebaseFirestore.instance.collection('chats').add(groupData);

      // Grup mesajları koleksiyonunu oluştur
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(groupRef.id)
          .collection('chat_messages')
          .add({
        'message': 'Grup oluşturuldu',
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system'
      });

      // Tüm üyelerin chats koleksiyonuna grubu ekle
      for (String memberId in [...members, currentUserId ?? '']) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .collection('chats')
            .doc(groupRef.id)
            .set({
          'chatId': groupRef.id,
          'type': 'group',
          'lastMessage': {
            'message': 'Grup oluşturuldu',
            'senderId': currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
          },
          'unreadCount': memberId == currentUserId ? 0 : 1,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup oluşturuldu')),
        );
        // Ana sekmeye dön
        _tabController.animateTo(0);
      }
    } catch (e) {
      print('Grup oluşturma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grup oluşturulurken hata oluştu')),
        );
      }
    }
  }

  Widget _buildChatList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadChats,
            child: _chats.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.1,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.message_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz mesajınız yok',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _chats.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      final lastMessage = chat['lastMessage'];
                      final time =
                          DateTime.parse(lastMessage['timestamp']).toLocal();
                      final timeStr = _formatTime(time);
                      final isOnline =
                          _onlineStatuses[chat['friendId']] ?? false;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                friendId: chat['friendId'],
                                friendName: chat['friendName'],
                                isGroup: chat['type'] == 'group',
                              ),
                            ),
                          ).then((_) {
                            if (_mounted) {
                              _loadChats();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.green.shade50,
                                    child: Text(
                                      chat['friendName'][0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                  StreamBuilder<bool>(
                                    stream: _chatService
                                        .userStatusStream(chat['friendId']),
                                    initialData: _chatService
                                        .isUserOnline(chat['friendId']),
                                    builder: (context, snapshot) {
                                      final isOnline = snapshot.data ?? false;
                                      if (!isOnline) return const SizedBox();
                                      return Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          chat['friendName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            color: chat['unreadCount'] > 0
                                                ? Colors.green.shade700
                                                : Colors.grey.shade500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMessage['message'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: chat['unreadCount'] > 0
                                                  ? Colors.black87
                                                  : Colors.grey.shade600,
                                              fontWeight:
                                                  chat['unreadCount'] > 0
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (chat['unreadCount'] > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade500,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              chat['unreadCount'].toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isOnline
                                          ? 'çevrimiçi'
                                          : _chatService
                                              .getLastSeen(chat['friendId']),
                                      style: TextStyle(
                                        color: isOnline
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}';
    }
  }
}
