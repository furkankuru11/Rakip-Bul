import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;

  ChatService._internal() {
    // Platform'a göre IP adresi seç
    final serverUrl =
        Platform.isAndroid ? 'http://10.0.2.2:3001' : 'http://localhost:3001';

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'timeout': 60000,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionAttempts': 5,
      'forceNew': true,
      'path': '/socket.io'
    });

    // Stream controller'ları initialize et
    _messageStreamController =
        StreamController<Map<String, dynamic>>.broadcast();
    _onlineStatusController = StreamController<Map<String, bool>>.broadcast();
    _connectionController = StreamController<bool>.broadcast();

    _setupSocketListeners();
    initialize(); // Bağlantıyı başlat
  }

  String? currentUserId;
  Function(Map<String, dynamic>)? onMessageReceived;
  SharedPreferences? _prefs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Online kullanıcıları tutan Map
  static final Map<String, bool> onlineUsers = {};

  // Son görülme zamanlarını tutacak Map
  static final Map<String, DateTime> lastSeenTimes = {};

  bool _isDisposed = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // Mesaj stream controller'ı
  late final StreamController<Map<String, dynamic>> _messageStreamController;

  // Mesaj stream'ini dinlemek için
  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  // Online durumu stream'i
  late final StreamController<Map<String, bool>> _onlineStatusController;
  Stream<Map<String, bool>> get onlineStatusStream =>
      _onlineStatusController.stream;

  bool _initialized = false;
  IO.Socket? _socket;
  IO.Socket get socket => _socket!;

  // Tek bir bağlantı durumu değişkeni
  static bool isConnected = false;

  // Stream controller'ları late olarak tanımla
  late final StreamController<bool> _connectionController;

  Future<void> initialize() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      currentUserId = _prefs?.getString('device_id');
      print('👤 Current User ID: $currentUserId');

      // Socket'i yeniden oluştur
      final serverUrl =
          Platform.isAndroid ? 'http://10.0.2.2:3001' : 'http://localhost:3001';

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'userId': currentUserId})
            .setReconnectionAttempts(double.infinity)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .enableReconnection()
            .enableAutoConnect()
            .build(),
      );

      _setupSocketListeners();

      // Bağlantıyı başlat
      if (!_socket!.connected) {
        _socket!.connect();
        print('🔄 Socket bağlantısı başlatılıyor...');

        // Bağlantı kurulana kadar bekle
        await Future.delayed(const Duration(seconds: 2));

        if (_socket!.connected) {
          setOnline();
          _startHeartbeat();
          print('✅ Socket bağlantısı kuruldu ve çevrimiçi yapıldı');
        } else {
          print('❌ Socket bağlantısı kurulamadı');
        }
      }

      _initialized = true;
    } catch (e) {
      print('❌ Initialize hatası: $e');
      _initialized = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (socket.connected && currentUserId != null) {
        socket.emit('heartbeat', {'userId': currentUserId});
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_socket!.connected && !_isDisposed) {
        print('🔄 Yeniden bağlanmaya çalışılıyor...');
        reconnect();
      } else {
        _reconnectTimer?.cancel();
      }
    });
  }

  // Mesajları locale kaydet
  Future<void> _saveMessageToLocal(Map<String, dynamic> message) async {
    final chatId = _getChatId(message['senderId'], message['receiverId']);
    List<Map<String, dynamic>> messages = await getMessages(chatId);

    // Eğer mesaj zaten varsa, güncelle
    final index =
        messages.indexWhere((m) => m['messageId'] == message['messageId']);
    if (index != -1) {
      messages[index] = message;
    } else {
      messages.add(message);
    }

    await _prefs?.setString(chatId, jsonEncode(messages));
  }

  // Belirli bir sohbetin mesajlarını getir
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    try {
      final messagesJson = _prefs?.getString(chatId);
      if (messagesJson != null) {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        return List<Map<String, dynamic>>.from(decoded)
          ..sort((a, b) => DateTime.parse(b['timestamp'])
              .compareTo(DateTime.parse(a['timestamp'])));
      }
      return [];
    } catch (e) {
      print('Mesajlar getirilirken hata: $e');
      return [];
    }
  }

  // İki kullanıcı arasındaki sohbet ID'sini oluştur
  String _getChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return 'chat_${sortedIds[0]}_${sortedIds[1]}';
  }

  // Belirli bir kullanıcıyla olan tüm mesajları getir
  Future<List<Map<String, dynamic>>> getChatMessages(String friendId) async {
    if (currentUserId == null) return [];
    final chatId = _getChatId(currentUserId!, friendId);
    return await getMessages(chatId);
  }

  // Mesaj gönderme
  Future<void> sendMessage(String senderId, String receiverId, String message) async {
    try {
      if (!socket.connected) {
        print('❌ Socket bağlı değil, mesaj gönderilemedi');
        return;
      }

      final messageData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // WebSocket üzerinden mesajı gönder
      socket.emit('send_message', messageData);

      // Bildirim için alıcının FCM tokenını al
      DocumentSnapshot receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      String? receiverToken = receiverDoc.get('fcmToken');
      String senderName = (await _firestore.collection('users').doc(senderId).get()).get('name');

      // Bildirim gönder
      if (receiverToken != null) {
        await _sendNotification(
          token: receiverToken,
          title: senderName,
          body: message,
          data: {
            'type': 'message',
            'senderId': senderId,
            'senderName': senderName,
          },
        );
      }
    } catch (e) {
      print('Mesaj gönderilirken hata: $e');
      rethrow;
    }
  }

  Future<void> _sendNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=BURAYA_SERVER_KEY_GELECEK', // Firebase Console'dan aldığınız key
        },
        body: json.encode({
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data,
          'priority': 'high',
          'to': token,
        }),
      );
    } catch (e) {
      print('Bildirim gönderilirken hata: $e');
    }
  }

  // Dispose metodunda stream'i kapat
  void dispose() {
    if (_isDisposed) return;

    if (currentUserId != null && _socket!.connected) {
      _socket!.emit('user_offline', {'userId': currentUserId});
    }

    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (!_messageStreamController.isClosed) _messageStreamController.close();
    if (!_onlineStatusController.isClosed) _onlineStatusController.close();
    if (!_connectionController.isClosed) _connectionController.close();

    _socket!.disconnect();
    _isDisposed = true;
  }

  // Stream aboneliklerini iptal etmek için yeni metod
  void cancelSubscriptions() {
    _messageStreamController.stream.drain();
    _onlineStatusController.stream.drain();
    _connectionController.stream.drain();
  }

  // Yeniden bağlanma işlemi için
  void reconnect() {
    if (_isDisposed) return;

    try {
      _socket!.connect();
      _startHeartbeat();
      print('🔄 Socket yeniden bağlanıyor...');
    } catch (e) {
      print('❌ Yeniden bağlanma hatası: $e');
    }
  }

  // Socket dinleyicilerine son görülme zamanı kontrolünü ekle
  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      print('🔌 Socket bağlandı');
      isConnected = true;
      if (currentUserId != null) {
        setOnline();
      }
      _broadcastOnlineStatus();
    });

    _socket!.onDisconnect((_) {
      print('🔌 Socket bağlantısı kesildi');
      isConnected = false;
      _broadcastOnlineStatus();

      // Uygulama açıkken otomatik yeniden bağlan
      if (!_isDisposed) {
        _scheduleReconnect();
      }
    });

    _socket!.onError((error) {
      print('❌ Socket hatası: $error');
      if (!_isDisposed) {
        _scheduleReconnect();
      }
    });

    // Diğer dinleyicileri bir kere ekle
    if (!_initialized) {
      socket.on('users_online', (data) {
        try {
          print('👥 Active users: $data');
          final List<String> userIds = List<String>.from(data);

          // Online kullanıcıları güncelle
          onlineUsers.clear();
          for (var id in userIds) {
            onlineUsers[id] = true;
          }

          // Online durumunu yayınla
          _broadcastOnlineStatus();
        } catch (e) {
          print('❌ Online kullanıcı listesi hatası: $e');
        }
      });

      socket.on('user_connected', (userId) {
        try {
          print('👤 User connected: $userId');
          onlineUsers[userId.toString()] = true;
          _broadcastOnlineStatus();
        } catch (e) {
          print('❌ Kullanıcı bağlantı hatası: $e');
        }
      });

      socket.on('user_disconnected', (data) {
        try {
          final userId = data['userId'].toString();
          print('👤 User disconnected: $userId');
          onlineUsers[userId] = false;
          lastSeenTimes[userId] = DateTime.now();
          _broadcastOnlineStatus();
        } catch (e) {
          print('❌ Kullanıcı çıkış hatası: $e');
        }
      });

      socket.on('receive_message', (data) async {
        print('📩 Yeni mesaj alındı: $data');
        
        // Mesajı locale kaydet
        await _saveMessageToLocal(data);

        // Stream'e yeni mesajı gönder
        _messageStreamController.add(data);
        
        if (onMessageReceived != null) {
          onMessageReceived!(data);
        }
      });
    }

    socket.on('group_message', (data) async {
      print('📩 Grup mesajı alındı: $data');
      await _saveMessageToLocal(data);

      // Stream'e yeni mesajı gönder
      _safeEmit(_messageStreamController, data);

      if (onMessageReceived != null) {
        onMessageReceived!(data);
      }
    });
  }

  Future<String?> _getCurrentUserId() async {
    if (currentUserId != null) return currentUserId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  // Tüm sohbetleri getir
  Future<List<Map<String, dynamic>>> getAllChats() async {
    try {
      if (currentUserId == null) return [];

      // Kullanıcının dahil olduğu tüm sohbetleri al
      final querySnapshot = await _firestore
          .collection('chats')
          .where('members', arrayContains: currentUserId)
          .orderBy('lastMessage.timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> chats = [];

      for (var doc in querySnapshot.docs) {
        final chatData = doc.data();
        final members = List<String>.from(chatData['members'] ?? []);
        
        // Karşı tarafın ID'sini bul
        final otherUserId = members.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        // Karşı tarafın bilgilerini al
        final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (!otherUserDoc.exists) continue;

        final otherUserData = otherUserDoc.data() ?? {};

        chats.add({
          'chatId': doc.id,
          'lastMessage': chatData['lastMessage'] != null ? {
            'message': chatData['lastMessage']?['message'] ?? '',
            'senderId': chatData['lastMessage']?['senderId'] ?? '',
            'timestamp': chatData['lastMessage']?['timestamp'] != null 
                ? (chatData['lastMessage']?['timestamp'] as Timestamp).toDate().toIso8601String()
                : DateTime.now().toIso8601String(),
          } : {
            'message': '',
            'senderId': '',
            'timestamp': DateTime.now().toIso8601String(),
          },
          'type': chatData['type'] ?? 'private',
          'otherUser': {
            'id': otherUserId,
            'name': otherUserData['name'] ?? '',
            'profileImage': otherUserData['profileImage'],
          },
          'unreadCount': chatData['unreadCount'] is Map 
              ? ((chatData['unreadCount'] as Map<String, dynamic>)[currentUserId] ?? 0)
              : (chatData['unreadCount'] ?? 0),
        });
      }

      return chats;
    } catch (e) {
      print('Sohbetler getirilirken hata: $e');
      return [];
    }
  }

  // Online durumu kontrolü için basit getter
  bool isUserOnline(String userId) {
    final isOnline = onlineUsers[userId] == true && isConnected;
    print(
        '👤 Kullanıcı durumu kontrolü - $userId: ${isOnline ? "çevrimiçi" : "çevrimdışı"} (Bağlantı: ${isConnected ? "var" : "yok"})');
    return isOnline;
  }

  // Online durumu stream'i güncellendi
  Stream<bool> userStatusStream(String userId) {
    return _onlineStatusController.stream.map((statuses) {
      return statuses[userId] == true && isConnected;
    }).distinct();
  }

  // Bağlantı durumunu güncelle ve yayınla
  void _updateConnectionStatus(bool status) {
    isConnected = status;
    _safeEmit(_connectionController, status);
  }

  // Son görülme zamanını getir
  String getLastSeen(String userId) {
    if (isUserOnline(userId)) return 'çevrimiçi';

    final lastSeen = lastSeenTimes[userId];
    if (lastSeen == null) return 'son görülme bilgisi yok';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    // 1 dakikadan az
    if (difference.inMinutes < 1) {
      return 'az önce';
    }
    // 24 saatten az
    else if (difference.inHours < 24) {
      return 'son görülme ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
    }
    // 24 saatten fazla
    else {
      return 'son görülme ${lastSeen.day}/${lastSeen.month} ${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
    }
  }

  // Son görülme stream'i
  Stream<String> userLastSeenStream(String userId) {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return getLastSeen(userId);
    }).distinct();
  }

  // Bağlantı durumunu kontrol etmek için getter
  static bool get connected => isConnected;

  // Event gönderirken kontrol ekle
  void _safeEmit<T>(StreamController<T> controller, T event) {
    if (!_isDisposed && !controller.isClosed) {
      controller.add(event);
    }
  }

  // Stream'lere güvenli erişim için getter'lar
  Stream<bool> get connectionStream => _connectionController.stream;

  // Çevrimdışı duruma geç
  void setOffline() {
    if (currentUserId != null) {
      print('🔴 Kullanıcı çevrimdışı yapılıyor: $currentUserId');
      isConnected = false;
      onlineUsers.clear();
      if (socket.connected) {
        socket.emit('user_offline', {'userId': currentUserId});
      }
      _broadcastOnlineStatus();
    }
  }

  // Çevrimiçi duruma geç
  void setOnline() {
    if (currentUserId != null && _socket!.connected) {
      print('🟢 Kullanıcı çevrimiçi yapılıyor: $currentUserId');
      isConnected = true;
      onlineUsers[currentUserId!] = true;
      _socket!.emit('user_online', {'userId': currentUserId});
      _broadcastOnlineStatus();
    }
  }

  // Online durumu yayınlama metodu
  void _broadcastOnlineStatus() {
    if (!_isDisposed && !_onlineStatusController.isClosed) {
      final currentStatus = Map<String, bool>.from(onlineUsers);

      // Bağlantı yoksa tüm kullanıcıları offline yap
      if (!isConnected) {
        currentStatus.clear();
      } else {
        // Kendimizi her zaman doğru durumda tut
        if (currentUserId != null) {
          currentStatus[currentUserId!] = true;
        }
      }

      _onlineStatusController.add(currentStatus);
      print(
          '📢 Online durumu yayınlandı: $currentStatus (Bağlantı: ${isConnected ? "var" : "yok"})');
    }
  }

  // Chat ekranları için özel online durum kontrolü
  bool isChatUserOnline(String userId) {
    if (!isConnected) return false;
    if (userId == currentUserId) return true;
    return onlineUsers[userId] == true;
  }

  // Chat listesi için online durum stream'i
  Stream<Map<String, bool>> get chatOnlineStatusStream {
    return _onlineStatusController.stream.map((statuses) {
      if (!isConnected) {
        return Map<String, bool>.fromIterable(
          statuses.keys,
          value: (_) => false,
        );
      }
      return statuses;
    });
  }

  // Tek kullanıcı için online durum stream'i
  Stream<bool> chatUserStatusStream(String userId) {
    return _onlineStatusController.stream.map((statuses) {
      if (!isConnected) return false;
      if (userId == currentUserId) return true;
      return statuses[userId] == true;
    }).distinct();
  }

  // Sohbet listesi stream'i
  Stream<List<Map<String, dynamic>>> get chatsStream {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('members', arrayContains: currentUserId)
        .orderBy('lastMessage.timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> chats = [];
      
      for (var doc in snapshot.docs) {
        final chatData = doc.data();
        final members = List<String>.from(chatData['members'] ?? []);
        
        final otherUserId = members.firstWhere(
          (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherUserId.isEmpty) continue;

        final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (!otherUserDoc.exists) continue;

        final otherUserData = otherUserDoc.data() ?? {};

        chats.add({
          'chatId': doc.id,
          'lastMessage': chatData['lastMessage'] != null ? {
            'message': chatData['lastMessage']?['message'] ?? '',
            'senderId': chatData['lastMessage']?['senderId'] ?? '',
            'timestamp': chatData['lastMessage']?['timestamp'] != null 
                ? (chatData['lastMessage']?['timestamp'] as Timestamp).toDate().toIso8601String()
                : DateTime.now().toIso8601String(),
          } : {
            'message': '',
            'senderId': '',
            'timestamp': DateTime.now().toIso8601String(),
          },
          'type': chatData['type'] ?? 'private',
          'otherUser': {
            'id': otherUserId,
            'name': otherUserData['name'] ?? '',
            'profileImage': otherUserData['profileImage'],
          },
          'unreadCount': chatData['unreadCount'] is Map 
              ? ((chatData['unreadCount'] as Map<String, dynamic>)[currentUserId] ?? 0)
              : (chatData['unreadCount'] ?? 0),
        });
      }

      return chats;
    });
  }
}
