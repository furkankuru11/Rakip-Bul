import 'package:flutter/material.dart';
import 'step4_level.dart';

class FootPreferenceStep extends StatefulWidget {
  final String name;
  final String age;
  final String phone;
  final String height;
  final String weight;
  final String position;
  final String userId;
  final String deviceId;
  final String userCode;

  const FootPreferenceStep({
    super.key,
    required this.name,
    required this.age,
    required this.phone,
    required this.height,
    required this.weight,
    required this.position,
    required this.userId,
    required this.deviceId,
    required this.userCode,
  });

  @override
  State<FootPreferenceStep> createState() => _FootPreferenceStepState();
}

class _FootPreferenceStepState extends State<FootPreferenceStep> {
  String? selectedFoot;
  bool _isLoading = false;

  Future<void> _saveFoot() async {
    setState(() => _isLoading = true);

    try {
      if (mounted && selectedFoot != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LevelStep(
              name: widget.name,
              age: widget.age,
              phone: widget.phone,
              height: widget.height,
              weight: widget.weight,
              position: widget.position,
              userId: widget.userId,
              deviceId: widget.deviceId,
              userCode: widget.userCode,
              preferredFoot: selectedFoot!,
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFootButton(String foot) {
    bool isSelected = selectedFoot == foot;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFoot = foot;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        height: 180,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: foot == 'Sol' ? -0.2 : 0.2,
              child: Icon(
                Icons.directions_walk,
                size: 80,
                color: isSelected ? Colors.white : Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              foot,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.blue.shade900,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
                  "Hangi Ayağını\nKullanıyorsun?",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFootButton('Sol'),
                    _buildFootButton('Sağ'),
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
                          onPressed: selectedFoot == null || _isLoading
                              ? null
                              : _saveFoot,
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
