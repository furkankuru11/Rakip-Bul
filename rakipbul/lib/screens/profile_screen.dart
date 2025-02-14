import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async'; // TimeoutException için bu import'u ekleyin

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class Availability {
  DateTime? date;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  double? latitude;
  double? longitude;

  Availability({
    this.date,
    this.startTime,
    this.endTime,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date?.toIso8601String(),
      'startTime':
          startTime != null ? '${startTime!.hour}:${startTime!.minute}' : null,
      'endTime': endTime != null ? '${endTime!.hour}:${endTime!.minute}' : null,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  factory Availability.fromMap(Map<String, dynamic> map) {
    return Availability(
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      startTime:
          map['startTime'] != null ? _parseTimeOfDay(map['startTime']) : null,
      endTime: map['endTime'] != null ? _parseTimeOfDay(map['endTime']) : null,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  @override
  String toString() {
    final dateStr = date?.toString().split(' ')[0] ?? '';
    final startTimeStr = startTime?.format(BuildContext as BuildContext) ?? '';
    final endTimeStr = endTime?.format(BuildContext as BuildContext) ?? '';
    return '$dateStr $startTimeStr - $endTimeStr';
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  String? profileImageUrl;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  List<Availability> selectedAvailabilities = [];

  // Form kontrolcülerini direkt başlat
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _preferredFootController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    // Kontrolcüleri temizle
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _positionController.dispose();
    _preferredFootController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId != null) {
        final docSnapshot =
            await _firestore.collection('users').doc(deviceId).get();

        if (docSnapshot.exists && mounted) {
          final data = docSnapshot.data();
          setState(() {
            userData = data;
            profileImageUrl = userData?['profileImage'];

            // Müsaitlik verilerini yükle
            final availabilityData =
                userData?['availability'] as List<dynamic>?;
            if (availabilityData != null) {
              selectedAvailabilities = availabilityData
                  .map((data) =>
                      Availability.fromMap(data as Map<String, dynamic>))
                  .toList();
            }

            isLoading = false;
          });
          _updateControllers();
        }
      }
    } catch (e) {
      print('❌ Kullanıcı yükleme hatası: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => isLoading = true);

      // Firebase Storage'a yükle
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${userData!['userId']}.jpg');

      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();

      // Firestore'da kullanıcı dokümanını güncelle
      await _firestore.collection('users').doc(userData!['userId']).update({
        'profileImage': downloadUrl,
      });

      setState(() {
        profileImageUrl = downloadUrl;
        isLoading = false;
      });
    } catch (e) {
      print('Resim yükleme hatası: $e');
      setState(() => isLoading = false);
    }
  }

  // Kullanıcı verilerini form kontrolcülerine yükle
  void _updateControllers() {
    _nameController.text = userData?['name'] ?? '';
    _ageController.text = userData?['age']?.toString() ?? '';
    _heightController.text = userData?['height']?.toString() ?? '';
    _weightController.text = userData?['weight']?.toString() ?? '';
    _positionController.text = userData?['position'] ?? '';
    _preferredFootController.text = userData?['preferredFoot'] ?? '';
  }

  // Verileri güncelle
  Future<void> _updateUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId != null) {
        await _firestore.collection('users').doc(deviceId).update({
          'name': _nameController.text,
          'age': int.parse(_ageController.text),
          'height': int.parse(_heightController.text),
          'weight': int.parse(_weightController.text),
          'position': _positionController.text,
          'preferredFoot': _preferredFootController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Düzenleme modundan çık
        setState(() {
          _isEditing = false;
          isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil başarıyla güncellendi')),
          );
        }
      }
    } catch (e) {
      print('Güncelleme hatası: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güncelleme sırasında bir hata oluştu')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userData == null) {
      return const Center(child: Text('Kullanıcı bilgileri bulunamadı'));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProfileAvatar(),
                  const SizedBox(height: 12),

                  // İsim
                  _isEditing
                      ? _buildEditField(
                          controller: _nameController,
                          label: 'İsim',
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'İsim gerekli' : null,
                        )
                      : Text(
                          userData!['name'] ?? 'Kullanıcı',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  const SizedBox(height: 8),

                  // Kullanıcı Kodu
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag, size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          userData!['userCode'] ?? 'Kod yok',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Kopyalama butonu
                        GestureDetector(
                          onTap: () {
                            final code = userData!['userCode'];
                            if (code != null) {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Kod kopyalandı!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isEditing
                      ? _buildEditField(
                          controller: _positionController,
                          label: 'Pozisyon',
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Pozisyon gerekli'
                              : null,
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            userData!['position'] ?? 'Pozisyon',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),

                  // Kişisel Bilgiler bölümü
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kişisel Bilgiler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isEditing) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditField(
                                  controller: _heightController,
                                  label: 'Boy (cm)',
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Boy gerekli'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildEditField(
                                  controller: _weightController,
                                  label: 'Kilo (kg)',
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Kilo gerekli'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditField(
                                  controller: _ageController,
                                  label: 'Yaş',
                                  keyboardType: TextInputType.number,
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Yaş gerekli'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildEditField(
                                  controller: _preferredFootController,
                                  label: 'Tercih Ayak',
                                  validator: (value) => value?.isEmpty ?? true
                                      ? 'Tercih ayak gerekli'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildInfoRow(
                                      Icons.height,
                                      'Boy',
                                      '${userData!['height']} cm',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      Icons.monitor_weight,
                                      'Kilo',
                                      '${userData!['weight']} kg',
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildInfoRow(
                                      Icons.numbers,
                                      'Yaş',
                                      '${userData!['age']} yaş',
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      Icons.sports_handball,
                                      'Tercih Ayak',
                                      userData!['preferredFoot'] ?? '-',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. BÖLÜM - İstatistikler
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İstatistikler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('23', 'Maç'),
                            _buildStatItem('15', 'Gol'),
                            _buildStatItem('8', 'Asist'),
                            _buildStatItem('12', 'Galibiyet'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. BÖLÜM - Değerlendirmeler
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Değerlendirmeler',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.star,
                                    color: Colors.yellow[700], size: 24),
                                const SizedBox(width: 4),
                                Text(
                                  '4.8',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellow[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildReviewItem('Harika bir oyuncu!', 5),
                        _buildReviewItem('Takım oyuncusu', 4),
                      ],
                    ),
                  ),
                  _buildAvailabilitySection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.green.withOpacity(0.2),
            ),
          ),
          child: Icon(icon, color: Colors.green.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String comment, int rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[100],
            child: Icon(
              Icons.person,
              color: Colors.green.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment,
                  style: const TextStyle(color: Colors.black),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star,
                      size: 14,
                      color:
                          index < rating ? Colors.amber[700] : Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 70,
          backgroundColor: Colors.green.shade600,
          child: profileImageUrl != null
              ? CircleAvatar(
                  radius: 67,
                  backgroundImage: NetworkImage(profileImageUrl!),
                )
              : CircleAvatar(
                  radius: 67,
                  backgroundColor: Colors.white,
                  child: Text(
                    (userData!['name'] ?? 'K')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: validator,
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.access_time, color: Colors.green.shade700),
            title: const Text(
              'Müsait Zamanlar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.green.shade700,
              onPressed: () => _showAvailabilityForm(context),
            ),
          ),
          const Divider(),
          if (selectedAvailabilities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Henüz müsait zaman eklenmemiş'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedAvailabilities.length,
              itemBuilder: (context, index) {
                final availability = selectedAvailabilities[index];
                return Dismissible(
                  key: Key(index.toString()),
                  background: Container(
                    color: Colors.red.shade100,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    setState(() {
                      selectedAvailabilities.removeAt(index);
                      _saveAvailability(selectedAvailabilities);
                    });
                  },
                  child: ListTile(
                    leading: const Icon(Icons.event_available),
                    title: Text(_formatDate(availability.date!)),
                    subtitle: Text(
                      '${_formatTime(availability.startTime!)} - ${_formatTime(availability.endTime!)}',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAvailabilityForm(BuildContext context) async {
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    Position? position;
    bool isLoadingLocation = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
                      child:
                          Icon(Icons.access_time, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Müsait Zaman Ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.green.shade700,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tarih',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDate != null
                                    ? _formatDate(selectedDate!)
                                    : 'Tarih Seç',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => startTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Başlangıç',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                startTime != null
                                    ? _formatTime(startTime!)
                                    : '--:--',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => endTime = time);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bitiş',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                endTime != null
                                    ? _formatTime(endTime!)
                                    : '--:--',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: isLoadingLocation
                      ? null
                      : () async {
                          setState(() => isLoadingLocation = true);
                          try {
                            position = await _getCurrentLocation();
                            setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          } finally {
                            setState(() => isLoadingLocation = false);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: position != null
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: position != null
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: position != null
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            position != null
                                ? 'Konum Alındı ✓'
                                : isLoadingLocation
                                    ? 'Konum Alınıyor...'
                                    : 'Konum Al',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: position != null
                                  ? Colors.green.shade700
                                  : null,
                            ),
                          ),
                        ),
                        if (isLoadingLocation)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'İptal',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (selectedDate != null &&
                            startTime != null &&
                            endTime != null) {
                          setState(() {
                            selectedAvailabilities.add(Availability(
                              date: selectedDate,
                              startTime: startTime,
                              endTime: endTime,
                              latitude: position?.latitude,
                              longitude: position?.longitude,
                            ));
                          });
                          _saveAvailability(selectedAvailabilities);
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Lütfen tarih ve saat bilgilerini doldurun'),
                            ),
                          );
                        }
                      },
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Position> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Lütfen konum servisini açın';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Konum izni reddedildi';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Konum izni kalıcı olarak reddedildi. Ayarlardan izin vermeniz gerekiyor.';
      }

      // Her iki platform için optimize edilmiş ayarlar
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw 'Konum alınamadı, internet bağlantınızı kontrol edin',
      );
    } on TimeoutException {
      throw 'Konum alınamadı, internet bağlantınızı kontrol edin';
    } on LocationServiceDisabledException {
      throw 'Konum servisi kapalı, lütfen açın';
    } on PermissionDeniedException {
      throw 'Konum izni reddedildi, ayarlardan izin vermeniz gerekiyor';
    } catch (e) {
      throw 'Konum alınamadı: $e';
    }
  }

  Future<void> _saveAvailability(List<Availability> availabilities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');

      if (deviceId != null) {
        // Önce userData'yı güncelle
        setState(() {
          if (userData != null) {
            userData!['availability'] =
                availabilities.map((a) => a.toMap()).toList();
          }
        });

        // Firestore'u güncelle
        await _firestore.collection('users').doc(deviceId).update({
          'availability': availabilities.map((a) => a.toMap()).toList(),
        });

        // Başarı mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Müsaitlik zamanları kaydedildi')),
          );
        }

        print(
            '✅ Müsaitlik zamanları kaydedildi: ${availabilities.length} zaman');
      }
    } catch (e) {
      print('❌ Müsaitlik kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e')),
        );
      }
    }
  }
}
