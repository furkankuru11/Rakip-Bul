import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'step3_position.dart';

class HeightWeightStep extends StatefulWidget {
  final String name;
  final String age;
  final String phone;
  final String userId;
  final String userCode;
  final String deviceId;

  const HeightWeightStep({
    super.key,
    required this.name,
    required this.age,
    required this.phone,
    required this.userId,
    required this.userCode,
    required this.deviceId,
  });

  @override
  State<HeightWeightStep> createState() => _HeightWeightStepState();
}

class _HeightWeightStepState extends State<HeightWeightStep> {
  int _currentHeight = 170;
  int _currentWeight = 70;
  bool _isLoading = false;

  Future<void> _saveHeightWeight() async {
    setState(() => _isLoading = true);

    try {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PositionStep(
              name: widget.name,
              age: widget.age,
              phone: widget.phone,
              height: _currentHeight.toString(),
              weight: _currentWeight.toString(),
              userId: widget.userId,
              deviceId: widget.deviceId,
              userCode: widget.userCode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Boy ve Kilo\nBilgileriniz",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Boy (cm)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          NumberPicker(
                            value: _currentHeight,
                            minValue: 140,
                            maxValue: 220,
                            step: 1,
                            haptics: true,
                            itemHeight: 60,
                            selectedTextStyle: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                            onChanged: (value) =>
                                setState(() => _currentHeight = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            "Kilo (kg)",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          NumberPicker(
                            value: _currentWeight,
                            minValue: 40,
                            maxValue: 150,
                            step: 1,
                            haptics: true,
                            itemHeight: 60,
                            selectedTextStyle: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                            onChanged: (value) =>
                                setState(() => _currentWeight = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
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
                          onPressed: _isLoading ? null : _saveHeightWeight,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
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
