const express = require("express");
const app = express();
const server = require("http").createServer(app);
const io = require("socket.io")(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    allowedHeaders: ["*"],
    credentials: true
  },
  path: '/socket.io',
  transports: ['websocket', 'polling'],
  pingTimeout: 60000, // 60 saniye ping timeout
  pingInterval: 25000, // 25 saniye ping aralığı
  connectTimeout: 30000, // 30 saniye bağlantı timeout
});

// Aktif kullanıcıları tut
const activeUsers = new Map();

// Offline mesajları saklamak için Map
const offlineMessages = new Map();

// Son görülme zamanlarını tut
const lastSeenTimes = new Map();

io.on("connection", (socket) => {
  const userId = socket.handshake.query.userId;
  console.log(`🟢 User connected: ${userId}`);
  activeUsers.set(userId, socket.id);

  // Yeni kullanıcı bağlandığında tüm kullanıcılara bildir
  io.emit('user_connected', userId);
  
  // Tüm aktif kullanıcıları yeni bağlanan kullanıcıya bildir
  socket.emit('users_online', Array.from(activeUsers.keys()));

  socket.on("disconnect", () => {
    activeUsers.delete(userId);
    const disconnectData = {
      userId: userId,
      timestamp: new Date()
    };
    io.emit('user_disconnected', disconnectData);
    console.log(`❌ User disconnected: ${userId}`);
  });

  // Heartbeat kontrolü
  socket.on("heartbeat", (data) => {
    const userId = data.userId;
    if (userId) {
      activeUsers.set(userId, socket.id);
      io.emit('user_connected', userId);
    }
  });

  // Bağlantıda bekleyen mesajları gönder
  const pendingMessages = getPendingMessages(userId);
  if (pendingMessages.length > 0) {
    console.log(`📨 ${pendingMessages.length} bekleyen mesaj gönderiliyor...`);
    pendingMessages.forEach(message => {
      socket.emit("receive_message", message);
    });
  }

  // Mesaj geldiğinde
  socket.on("message", (messageData) => {
    console.log('📨 Yeni mesaj:', messageData);
    
    // Hemen "sent" durumunu gönder
    socket.emit("message_status", {
      messageId: messageData.messageId,
      status: 'sent',
      timestamp: new Date().toISOString()
    });

    const targetSocket = activeUsers.get(messageData.receiverId);
    if (targetSocket) {
      io.to(targetSocket).emit('receive_message', messageData);
      console.log('✅ Mesaj iletildi');
    } else {
      storeOfflineMessage(messageData);
      console.log('⏳ Mesaj saklandı (alıcı offline)');
    }
  });

  // Kullanıcı bağlandığında bekleyen mesajları gönder
  socket.on("connect", () => {
    const userId = socket.handshake.query.userId;
    const pendingMessages = getPendingMessages(userId);
    
    pendingMessages.forEach(message => {
      socket.emit("receive_message", message);
    });
  });

  // Son görülme zamanını istemcilere gönder
  socket.on("get_last_seen", (targetUserId) => {
    const lastSeen = lastSeenTimes.get(targetUserId);
    socket.emit('last_seen_response', {
      userId: targetUserId,
      lastSeen: lastSeen || null
    });
  });

  // Bağlantı durumunu kontrol et
  socket.conn.on("packet", (packet) => {
    if (packet.type === "pong") {
      console.log(`💓 Heartbeat from ${userId}`);
    }
  });

  // Grup mesajı geldiğinde
  socket.on("group_message", async (messageData) => {
    try {
      console.log('📨 Grup mesajı:', messageData);

      // Firestore'a kaydet
      await admin.firestore().collection('messages')
        .doc(messageData.chatId)
        .collection('chat_messages')
        .add({
          ...messageData,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

      // Grup bilgilerini güncelle
      await admin.firestore().collection('chats')
        .doc(messageData.chatId)
        .update({
          'lastMessage': {
            'message': messageData.message,
            'senderId': messageData.senderId,
            'timestamp': admin.firestore.FieldValue.serverTimestamp(),
          }
        });

      // Grup üyelerine mesajı ilet
      const groupDoc = await admin.firestore()
        .collection('chats')
        .doc(messageData.chatId)
        .get();

      if (groupDoc.exists) {
        const members = groupDoc.data().members || [];
        members.forEach((memberId) => {
          const memberSocket = activeUsers.get(memberId);
          if (memberSocket && memberSocket !== socket.id) {
            io.to(memberSocket).emit('group_message', messageData);
          }
        });
      }

      // Gönderene onay gönder
      socket.emit("message_status", {
        messageId: messageData.messageId,
        status: 'sent',
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('❌ Grup mesajı hatası:', error);
      socket.emit("message_error", {
        messageId: messageData.messageId,
        error: error.message
      });
    }
  });
});

// Tüm IP adreslerinden gelen bağlantıları dinle
const PORT = 3001;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

// Offline mesajı sakla
function storeOfflineMessage(messageData) {
  const receiverId = messageData.receiverId;
  if (!offlineMessages.has(receiverId)) {
    offlineMessages.set(receiverId, []);
  }
  offlineMessages.get(receiverId).push(messageData);
  console.log('⏳ Offline mesaj saklandı:', messageData);
}

// Bekleyen mesajları getir
function getPendingMessages(userId) {
  const messages = offlineMessages.get(userId) || [];
  offlineMessages.delete(userId); // Mesajları aldıktan sonra sil
  return messages;
}

// Firestore'a mesaj kaydetme fonksiyonu
async function saveMessageToFirestore(messageData) {
  try {
    const messagesRef = admin.firestore().collection('messages');
    await messagesRef.add({
      ...messageData,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Mesaj Firestore\'a kaydedildi');
  } catch (error) {
    console.error('❌ Firestore kayıt hatası:', error);
  }
} 