import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'step3_position.dart';
import 'step5_height_weight.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeStep extends StatefulWidget {
  final String name;
  final String phone;
  final String userId;
  final String userCode;
  final String deviceId;

  const AgeStep({
    super.key,
    required this.name,
    required this.phone,
    required this.userId,
    required this.userCode,
    required this.deviceId,
  });

  @override
  State<AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends State<AgeStep> {
  int _currentAge = 18;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Yaşını\nÖğrenelim",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: NumberPicker(
                    value: _currentAge,
                    minValue: 10,
                    maxValue: 120,
                    step: 1,
                    haptics: true,
                    itemHeight: 90,
                    selectedTextStyle: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 24,
                      color: Colors.grey,
                    ),
                    onChanged: (value) => setState(() => _currentAge = value),
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
                          onPressed: _saveAndNavigate,
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

  Future<void> _saveAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();

    // Yaşı locale kaydet
    await prefs.setInt('user_age', _currentAge);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HeightWeightStep(
            name: widget.name,
            age: _currentAge.toString(),
            phone: widget.phone,
            userId: widget.userId,
            deviceId: widget.deviceId,
            userCode: widget.userCode,
          ),
        ),
      );
    }
  }
}
