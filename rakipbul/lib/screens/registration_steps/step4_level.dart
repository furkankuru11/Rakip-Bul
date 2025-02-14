import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../anasayfa.dart';

class LevelStep extends StatefulWidget {
  final String name;
  final String age;
  final String position;
  final String phone;
  final String height;
  final String weight;
  final String userId;
  final String deviceId;
  final String userCode;
  final String preferredFoot;

  const LevelStep({
    super.key,
    required this.name,
    required this.age,
    required this.position,
    required this.phone,
    required this.height,
    required this.weight,
    required this.userId,
    required this.deviceId,
    required this.userCode,
    required this.preferredFoot,
  });

  @override
  State<LevelStep> createState() => _LevelStepState();
}

class _LevelStepState extends State<LevelStep> {
  double _skillLevel = 50;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getSkillText(double value) {
    if (value < 20) return 'Yeni Başlayan';
    if (value < 40) return 'Amatör';
    if (value < 60) return 'Orta Seviye';
    if (value < 80) return 'İyi Seviye';
    return 'Profesyonel';
  }

  Color _getSkillColor(double value) {
    if (value < 20) {
      return const Color(0xFFD32F2F); // Koyu Kırmızı (Yeni Başlayan)
    }
    if (value < 40) {
      return const Color(0xFFE65100); // Çok Koyu Turuncu (Amatör)
    }
    if (value < 60) {
      return const Color(0xFFF9A825); // Koyu Altın Sarısı (Orta Seviye)
    }
    if (value < 80) {
      return const Color(0xFF1565C0); // Lacivert (İyi Seviye)
    }
    return const Color(0xFF1B5E20); // Çok Koyu Yeşil (Profesyonel)
  }

  // Arka plan rengi için ayrı bir metod
  Color _getBackgroundColor(double value) {
    if (value < 20) {
      return const Color(0xFFFFCDD2); // Kırmızı arka plan
    }
    if (value < 40) {
      return const Color(0xFFFFE0B2); // Turuncu arka plan
    }
    if (value < 60) {
      return const Color(0xFFFFF3E0); // Sarı arka plan
    }
    if (value < 80) {
      return const Color(0xFFBBDEFB); // Lacivert arka plan
    }
    return const Color(0xFFC8E6C9); // Yeşil arka plan
  }

  void _saveUserData() async {
    setState(() => _isLoading = true);

    try {
      // deviceId'yi kullanarak yeni bir döküman ID'si oluştur
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.deviceId); // deviceId'yi doküman ID'si olarak kullan

      // Kullanıcı verilerini kaydet
      await docRef.set({
        'userId': widget.deviceId, // deviceId'yi userId olarak da kullan
        'name': widget.name,
        'phone': widget.phone,
        'age': widget.age,
        'height': widget.height,
        'weight': widget.weight,
        'position': widget.position,
        'level': _skillLevel,
        'deviceId': widget.deviceId,
        'userCode': widget.userCode,
        'preferredFoot': widget.preferredFoot,
        'createdAt': FieldValue.serverTimestamp(),
        'stats': {
          'matches': 0,
          'wins': 0,
          'losses': 0,
          'goals': 0,
          'assists': 0,
          'rating': 0.0,
        },
        'preferences': {
          'notifications': true,
          'privateProfile': false,
          'matchRequests': true,
        },
        'friends': [],
        'teams': [],
        'reviews': [],
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AnaSayfa()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Son Adım!\nTecrübeni Değerlendir",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 60),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getSkillColor(_skillLevel).withOpacity(0.1),
                        _getBackgroundColor(_skillLevel),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: _getSkillColor(_skillLevel).withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _getSkillColor(_skillLevel),
                                width: 3,
                              ),
                              color: Colors.white,
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${_skillLevel.toInt()}',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _getSkillColor(_skillLevel),
                                ),
                              ),
                              Text(
                                _getSkillText(_skillLevel),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: _getSkillColor(_skillLevel),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _getSkillColor(_skillLevel),
                          inactiveTrackColor: Colors.grey.shade200,
                          thumbColor: Colors.white,
                          trackHeight: 8,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12,
                            pressedElevation: 8,
                          ),
                          overlayColor:
                              _getSkillColor(_skillLevel).withOpacity(0.2),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 24,
                          ),
                        ),
                        child: Slider(
                          value: _skillLevel,
                          min: 0,
                          max: 100,
                          onChanged: (value) {
                            setState(() {
                              _skillLevel = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Seviyeni belirlemek için kaydır',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Geri'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getSkillColor(_skillLevel),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _saveUserData,
                          child: const Text(
                            "Kayıtı Tamamla",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
}
