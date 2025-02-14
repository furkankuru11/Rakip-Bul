import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class DateScreen extends StatefulWidget {
  const DateScreen({super.key});

  @override
  State<DateScreen> createState() => _DateScreenState();
}

class _DateScreenState extends State<DateScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? currentUserId;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<dynamic>> _events = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('device_id');
    await _loadEvents();
    setState(() => isLoading = false);
  }

  Future<void> _loadEvents() async {
    if (currentUserId == null) return;

    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('participants', arrayContains: currentUserId)
          .get();

      final Map<DateTime, List<dynamic>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final key = DateTime(date.year, date.month, date.day);

        if (events[key] == null) events[key] = [];
        events[key]!.add(data);
      }

      setState(() => _events = events);
    } catch (e) {
      print('❌ Etkinlikler yüklenirken hata: $e');
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _getEventsForDay(_selectedDay).length,
              itemBuilder: (context, index) {
                final event = _getEventsForDay(_selectedDay)[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(event['title'] ?? 'Maç'),
                    subtitle: Text(
                      '${event['location'] ?? 'Konum belirtilmedi'}\n'
                      '${_formatDateTime(event['date'].toDate())}',
                      style: const TextStyle(height: 1.5),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showEventOptions(event),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}\n'
        'Saat: ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEventOptions(Map<String, dynamic> event) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Düzenle'),
            onTap: () {
              Navigator.pop(context);
              _showAddEventDialog(event: event);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Sil', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await _firestore.collection('matches').doc(event['id']).delete();
              if (mounted) {
                Navigator.pop(context);
                await _loadEvents();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEventDialog({Map<String, dynamic>? event}) async {
    final titleController = TextEditingController(text: event?['title']);
    final locationController = TextEditingController(text: event?['location']);
    TimeOfDay selectedTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event == null ? 'Yeni Maç Ekle' : 'Maçı Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Konum'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (time != null) {
                  selectedTime = time;
                }
              },
              child: const Text('Başlangıç Saati Seç'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final date = DateTime(
                _selectedDay.year,
                _selectedDay.month,
                _selectedDay.day,
                selectedTime.hour,
                selectedTime.minute,
              );

              if (event == null) {
                // Yeni etkinlik ekle
                await _firestore.collection('matches').add({
                  'title': titleController.text,
                  'location': locationController.text,
                  'date': date,
                  'participants': [currentUserId],
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                // Mevcut etkinliği güncelle
                await _firestore.collection('matches').doc(event['id']).update({
                  'title': titleController.text,
                  'location': locationController.text,
                  'date': date,
                });
              }

              if (mounted) {
                Navigator.pop(context);
                await _loadEvents();
              }
            },
            child: Text(event == null ? 'Ekle' : 'Güncelle'),
          ),
        ],
      ),
    );
  }
}
