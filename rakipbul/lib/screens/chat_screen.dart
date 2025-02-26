import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakipbul/services/chat_service.dart';
import 'dart:async';
import 'package:rakipbul/screens/group_members_screen.dart';
import 'package:rakipbul/screens/other_profile.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;

  const ChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  StreamSubscription? _onlineStatusSubscription;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupOnlineStatus();
    _chatService.onMessageReceived = _handleNewMessage;
  }

  void _setupOnlineStatus() {
    _onlineStatusSubscription =
        _chatService.onlineStatusStream.listen((statuses) {
      if (mounted) {
        setState(() {
          _isOnline = statuses[widget.friendId] ?? false;
        });
      }
    });
    // İlk durumu kontrol et
    _isOnline = _chatService.isUserOnline(widget.friendId);
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final messages = await _chatService.getChatMessages(widget.friendId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: false);
      });
    }
    await _chatService.markMessagesAsRead(widget.friendId);
  }

  void _handleNewMessage(Map<String, dynamic> message) {
    if (message['senderId'] == widget.friendId ||
        message['receiverId'] == widget.friendId) {
      setState(() {
        _messages.add(message);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: true);
      });

      if (message['senderId'] == widget.friendId) {
        _chatService.markMessagesAsRead(widget.friendId);
      }
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Klavyeyi kapat
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leadingWidth: 40,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20, color: Colors.grey.shade800),
            onPressed: () => Navigator.pop(context),
          ),
          title: InkWell(
            onTap: () async {
              // Kullanıcı bilgilerini Firestore'dan al
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .where('deviceId', isEqualTo: widget.friendId)
                  .get();

              if (userDoc.docs.isNotEmpty && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherProfileScreen(
                      userData: {
                        ...userDoc.docs.first.data(),
                        'userId': widget.friendId,
                      },
                    ),
                  ),
                );
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green.shade50,
                  child: Text(
                    widget.friendName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.friendName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          Text(
                            _isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessageList(),
            ),
            Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Mesaj yazın...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sendMessage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _sendMessage(_messageController.text),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
        final messages = await _chatService.getChatMessages(widget.friendId);
        return messages;
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!;

        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Henüz mesaj yok',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message['senderId'] == _chatService.currentUserId;
            return _buildMessage(message, isMe);
          },
        );
      },
    );
  }

  Widget _buildMessage(Map<String, dynamic> message, bool isMe) {
    String timeStr = '';
    if (message['timestamp'] != null) {
      timeStr = _formatTime(DateTime.parse(message['timestamp']));
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 24),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.green.shade500 : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message['message'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 24),
        ],
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
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty || !mounted) return;

    try {
      // WebSocket ile mesaj gönder
      await _chatService.sendMessage(widget.friendId, text);

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Mesaj gönderme hatası: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _onlineStatusSubscription?.cancel();
    super.dispose();
  }
}
