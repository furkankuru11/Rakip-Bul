import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakipbul/models/user_model.dart';
import 'package:table_calendar/table_calendar.dart';

class CreateMatchScreen extends StatefulWidget {
  final int initialTab;

  const CreateMatchScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _fieldNameController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<UserModel> _selectedPlayers = [];
  List<UserModel> _friends = [];
  String? currentUserId;
  bool _hasMatchToday = false;
  List<Map<String, dynamic>> _userMatches = [];
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadFriends(),
        _checkTodayMatch(),
        _loadUserMatches(),
      ]);
    } catch (e) {
      print('Veri yükleme hatası: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('device_id');

    if (currentUserId == null) return;

    final friendRequests = await FirebaseFirestore.instance
        .collection('friendRequests')
        .where('status', isEqualTo: 'accepted')
        .where('senderId', isEqualTo: currentUserId)
        .get();

    final friendIds =
        friendRequests.docs.map((doc) => doc['receiverId'] as String).toList();

    for (var friendId in friendIds) {
      final friendDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('deviceId', isEqualTo: friendId)
          .get();

      if (friendDoc.docs.isNotEmpty) {
        final friendData = friendDoc.docs.first.data();
        friendData['userId'] = friendData['deviceId'];
        setState(() {
          _friends.add(UserModel.fromMap(friendData));
        });
      }
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

      if (mounted) {
        setState(() {
          _hasMatchToday = matchQuery.docs.isNotEmpty;
          if (_hasMatchToday && matchQuery.docs.isNotEmpty) {
            final todayMatch = matchQuery.docs.first;
            final matchData = todayMatch.data();
            _userMatches.insert(0, {
              ...matchData,
              'id': todayMatch.id,
              'date': matchData['date'],
              'time': matchData['time'],
              'players':
                  List<Map<String, dynamic>>.from(matchData['players'] ?? []),
            });
          }
        });
      }

      // Debug için
      print('Bugün maç var mı: $_hasMatchToday');
      if (_hasMatchToday) {
        print('Bugünkü maç: ${_userMatches.first}');
      }
    } catch (e) {
      print('Maç kontrolü hatası: $e');
      setState(() {
        _hasMatchToday = false;
      });
    }
  }

  Future<void> _loadUserMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId == null) return;

      final matchQuery = await FirebaseFirestore.instance
          .collection('matches')
          .where('creatorId', isEqualTo: deviceId)
          .orderBy('date', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _userMatches = matchQuery.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'date': data['date'], // ISO string formatında
              'time': data['time'],
              'players': List<Map<String, dynamic>>.from(data['players'] ?? []),
            };
          }).toList();
        });
      }

      // Debug için
      print('Yüklenen maçlar: ${_userMatches.length}');
      for (var match in _userMatches) {
        print('Maç detayı: ${match['fieldName']} - ${match['date']}');
      }
    } catch (e) {
      print('Maçları yükleme hatası: $e');
    }
  }

  void _showPlayerSelectionDialog() {
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
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.group_add, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Oyuncu Ekle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final isSelected = _selectedPlayers.contains(friend);

                    return CheckboxListTile(
                      title: Text(friend.name),
                      subtitle: Text(friend.position),
                      value: isSelected,
                      activeColor: Colors.green,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedPlayers.add(friend);
                          } else {
                            _selectedPlayers.remove(friend);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Tamam',
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createMatch() async {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null &&
        _selectedTime != null) {
      try {
        await _checkTodayMatch();
        if (_hasMatchToday) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bugün için zaten bir maç oluşturdunuz'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        final matchData = {
          'creatorId': currentUserId,
          'city': _cityController.text,
          'district': _districtController.text,
          'fieldName': _fieldNameController.text,
          'date': _selectedDate!.toIso8601String(),
          'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
          'players': _selectedPlayers
              .map((player) => {
                    'userId': player.userId,
                    'name': player.name,
                    'position': player.position,
                  })
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active',
        };

        // Firestore'a kaydet
        final docRef = await FirebaseFirestore.instance
            .collection('matches')
            .add(matchData);

        // State'i güncelle
        setState(() {
          _hasMatchToday = true;
          _userMatches.insert(0, {...matchData, 'id': docRef.id});
        });

        // Yükleniyor göstergesini kapat
        Navigator.pop(context);

        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maç başarıyla oluşturuldu')),
        );

        // Sayfayı yeniden yükle
        setState(() {});
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maç Oluştur'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle_outline),
              text: 'Yeni Maç',
            ),
            Tab(
              icon: Icon(Icons.sports_soccer),
              text: 'Maçlarım',
            ),
          ],
          labelColor: Colors.green.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green.shade700,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateMatchTab(),
          _buildMyMatchesTab(),
        ],
      ),
    );
  }

  Widget _buildCreateMatchTab() {
    if (_hasMatchToday) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bugün için zaten bir maç oluşturdunuz',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTodayMatchCard(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İl ve İlçe yan yana
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: 'İl',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen il giriniz';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _districtController,
                    decoration: InputDecoration(
                      labelText: 'İlçe',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.place),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen ilçe giriniz';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Saha Adı
            TextFormField(
              controller: _fieldNameController,
              decoration: InputDecoration(
                labelText: 'Saha Adı',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.sports_soccer),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen saha adı giriniz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Tarih ve Saat Seçimi
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate == null
                                ? 'Tarih Seç'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            style: TextStyle(
                              color: _selectedDate == null
                                  ? Colors.grey.shade600
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() => _selectedTime = time);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime == null
                                ? 'Saat Seç'
                                : _selectedTime!.format(context),
                            style: TextStyle(
                              color: _selectedTime == null
                                  ? Colors.grey.shade600
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Oyuncular Başlığı ve Ekleme Butonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Oyuncular',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                IconButton(
                  onPressed: _showPlayerSelectionDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Seçili Oyuncular
            if (_selectedPlayers.isEmpty)
              Center(
                child: Text(
                  'Henüz oyuncu eklenmedi',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedPlayers.length,
                  itemBuilder: (context, index) {
                    final player = _selectedPlayers[index];
                    return ListTile(
                      title: Text(player.name),
                      subtitle: Text(player.position),
                      trailing: IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.red.shade400),
                        onPressed: () {
                          setState(() {
                            _selectedPlayers.remove(player);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Maç Oluştur Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _createMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Maç Oluştur',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyMatchesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userMatches.isEmpty) {
      return Center(
        child: Text(
          'Henüz maç oluşturmadınız',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
          ),
        ),
      );
    }

    // Maçları tarihe göre grupla
    final today = DateTime.now();
    final todayMatches = <Map<String, dynamic>>[];
    final upcomingMatches = <Map<String, dynamic>>[];
    final pastMatches = <Map<String, dynamic>>[];

    for (var match in _userMatches) {
      final matchDate = DateTime.parse(match['date']);
      if (isSameDay(matchDate, today)) {
        todayMatches.add(match);
      } else if (matchDate.isAfter(today)) {
        upcomingMatches.add(match);
      } else {
        pastMatches.add(match);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (todayMatches.isNotEmpty) ...[
          _buildMatchSection('Bugünkü Maç', todayMatches),
          const SizedBox(height: 24),
        ],
        if (upcomingMatches.isNotEmpty) ...[
          _buildMatchSection('Gelecek Maçlar', upcomingMatches),
          const SizedBox(height: 24),
        ],
        if (pastMatches.isNotEmpty)
          _buildMatchSection('Geçmiş Maçlar', pastMatches),
      ],
    );
  }

  Widget _buildMatchSection(String title, List<Map<String, dynamic>> matches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        ...matches.map((match) => _buildMatchCard(match)),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final matchDate = DateTime.parse(match['date']);
    final players = List<Map<String, dynamic>>.from(match['players']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_soccer, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  match['fieldName'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${match['city']}, ${match['district']}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${matchDate.day}/${matchDate.month}/${matchDate.year} - ${match['time']}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            if (players.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Oyuncular',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: players.map((player) {
                  return Chip(
                    label: Text(player['name']),
                    backgroundColor: Colors.green.shade50,
                    side: BorderSide(color: Colors.green.shade200),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayMatchCard() {
    if (_userMatches.isEmpty) return const SizedBox();
    return _buildMatchCard(_userMatches.first);
  }
}
