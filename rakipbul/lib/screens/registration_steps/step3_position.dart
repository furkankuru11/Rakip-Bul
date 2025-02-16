import 'package:flutter/material.dart';
import 'step6_foot_preference.dart';

class PositionStep extends StatefulWidget {
  final String name;
  final String age;
  final String phone;
  final String height;
  final String weight;
  final String userId;
  final String deviceId;
  final String userCode;

  const PositionStep({
    super.key,
    required this.name,
    required this.age,
    required this.phone,
    required this.height,
    required this.weight,
    required this.userId,
    required this.deviceId,
    required this.userCode,
  });

  @override
  State<PositionStep> createState() => _PositionStepState();
}

class _PositionStepState extends State<PositionStep> {
  String? selectedPosition;

  Widget _buildPositionButton(String position, double top, double left) {
    bool isSelected = selectedPosition == position;
    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPosition = position;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade900 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.blue.shade900,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.blue.shade900.withOpacity(0.4)
                    : Colors.black.withOpacity(0.1),
                blurRadius: isSelected ? 15 : 8,
                spreadRadius: isSelected ? 3 : 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              position,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
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
                  "Pozisyonunu\nSeç",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 500,
                    decoration: BoxDecoration(
                      color: Colors.green.shade500,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Orta saha çemberi
                        Center(
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        // Yatay çizgiler - Sadece iki çizgi
                        Positioned(
                          top: 150,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        Positioned(
                          top: 350,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        // Pozisyon butonları - 3-2-1 dizilişi
                        // Forvet (en üstte)
                        _buildPositionButton('Forvet', 60,
                            MediaQuery.of(context).size.width / 2 - 54),

                        // Orta Saha (2 kişi)
                        _buildPositionButton('Orta Saha', 180,
                            MediaQuery.of(context).size.width / 3 - 54),
                        _buildPositionButton('Orta Saha', 180,
                            MediaQuery.of(context).size.width * 2 / 3 - 54),

                        // Defans (3 kişi)
                        _buildPositionButton('Defans', 300,
                            MediaQuery.of(context).size.width / 4 - 54),
                        _buildPositionButton('Defans', 300,
                            MediaQuery.of(context).size.width / 2 - 54),
                        _buildPositionButton('Defans', 300,
                            MediaQuery.of(context).size.width * 3 / 4 - 54),

                        // Kaleci (en altta)
                        _buildPositionButton('Kaleci', 400,
                            MediaQuery.of(context).size.width / 2 - 54),
                      ],
                    ),
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
                            backgroundColor: Colors.blue[900],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: selectedPosition == null
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FootPreferenceStep(
                                        name: widget.name,
                                        age: widget.age,
                                        phone: widget.phone,
                                        height: widget.height,
                                        weight: widget.weight,
                                        position: selectedPosition!,
                                        userId: widget.userId,
                                        deviceId: widget.deviceId,
                                        userCode: widget.userCode,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text(
                            "İleri",
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
