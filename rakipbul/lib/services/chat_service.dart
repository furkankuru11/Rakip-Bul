import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'dart:async';

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
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }

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
    final messagesJson = _prefs?.getString(chatId);
    if (messagesJson != null) {
      final List<dynamic> decoded = jsonDecode(messagesJson);
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
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
  Future<void> sendMessage(String receiverId, String message) async {
    try {
      if (currentUserId == null) return;

      final messageData = {
        'messageId': const Uuid().v4(),
        'message': message,
        'senderId': currentUserId,
        'receiverId': receiverId,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'sent'
      };

      // Locale kaydet
      await _saveMessageToLocal(messageData);

      // WebSocket ile gönder
      if (_socket != null && _socket!.connected) {
        _socket!.emit('message', messageData);
        print('📤 Mesaj gönderildi: $messageData');

        // Stream'e yeni mesajı ekle
        _messageStreamController.add(messageData);
      } else {
        print('❌ WebSocket bağlantısı yok, sadece locale kaydedildi');
      }
    } catch (e) {
      print('❌ Mesaj gönderme hatası: $e');
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

      socket.on('receive_message', _handleReceiveMessage);
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

  void _handleReceiveMessage(dynamic data) async {
    print('📩 Yeni mesaj alındı: $data');
    await _saveMessageToLocal(data);
    // Stream'e yeni mesajı gönder
    _safeEmit(_messageStreamController, data);
    if (onMessageReceived != null) {
      onMessageReceived!(data);
    }
  }

  Future<String?> _getCurrentUserId() async {
    if (currentUserId != null) return currentUserId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  Future<List<Map<String, dynamic>>> getAllChats() async {
    if (currentUserId == null) return [];

    try {
      final List<Map<String, dynamic>> chatPreviews = [];
      final allKeys = _prefs?.getKeys() ?? <String>{};

      // Sadece mevcut kullanıcının sohbetlerini filtrele
      final userChatKeys = allKeys.where(
          (key) => key.startsWith('chat_') && key.contains(currentUserId!));

      for (var key in userChatKeys) {
        final messages = await getMessages(key);
        if (messages.isNotEmpty) {
          // Son mesajı bul
          final lastMessage = messages.reduce((a, b) =>
              DateTime.parse(a['timestamp'])
                      .isAfter(DateTime.parse(b['timestamp']))
                  ? a
                  : b);

          // Karşı tarafın ID'sini bul
          final friendId = lastMessage['senderId'] == currentUserId
              ? lastMessage['receiverId']
              : lastMessage['senderId'];

          // Karşı tarafın bilgilerini Firestore'dan al
          final friendDoc = await _firestore
              .collection('users')
              .where('deviceId', isEqualTo: friendId)
              .get();

          if (friendDoc.docs.isNotEmpty) {
            final friendData = friendDoc.docs.first.data();

            // Okunmamış mesaj sayısını hesapla
            final unreadCount = messages
                .where((m) =>
                    m['senderId'] != currentUserId && m['status'] != 'read')
                .length;

            chatPreviews.add({
              'friendId': friendId,
              'friendName': friendData['name'] ?? 'İsimsiz Kullanıcı',
              'profileImage': friendData['profileImage'],
              'lastMessage': lastMessage,
              'unreadCount': unreadCount,
            });
          }
        }
      }

      // Son mesaja göre sırala
      chatPreviews.sort((a, b) => DateTime.parse(b['lastMessage']['timestamp'])
          .compareTo(DateTime.parse(a['lastMessage']['timestamp'])));

      return chatPreviews;
    } catch (e) {
      print('Sohbetler yüklenirken hata: $e');
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

  // Mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String friendId) async {
    if (currentUserId == null) return;

    final chatId = _getChatId(currentUserId!, friendId);
    final messages = await getMessages(chatId);

    bool hasChanges = false;

    // Karşı taraftan gelen okunmamış mesajları işaretle
    for (var message in messages) {
      if (message['senderId'] == friendId && message['status'] != 'read') {
        message['status'] = 'read';
        hasChanges = true;
      }
    }

    // Değişiklik varsa kaydet
    if (hasChanges) {
      await _prefs?.setString(chatId, jsonEncode(messages));
    }
  }

  // Okunmamış mesaj sayısını getir
  Future<int> getUnreadMessagesCount() async {
    if (currentUserId == null) return 0;

    try {
      final allChats = await getAllChats();
      int totalUnread = 0;

      for (var chat in allChats) {
        totalUnread += chat['unreadCount'] as int;
      }

      return totalUnread;
    } catch (e) {
      print('Okunmamış mesaj sayısı hesaplanırken hata: $e');
      return 0;
    }
  }

  // Mesaj geldiğinde dinleyicileri bilgilendir
  Stream<int> get unreadMessagesStream {
    return Stream.periodic(const Duration(seconds: 1), (_) async {
      return await getUnreadMessagesCount();
    }).asyncMap((event) async => await event);
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
}
