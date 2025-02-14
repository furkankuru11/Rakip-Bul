import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'step2_age.dart';

class NameStep extends StatefulWidget {
  const NameStep({Key? key}) : super(key: key);

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> {
  final TextEditingController nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _navigateToNextStep() async {
    if (_formKey.currentState!.validate()) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Benzersiz ID'ler oluştur
        final deviceId = const Uuid().v4();
        final userCode = nameController.text.substring(0, 3).toUpperCase() +
            DateTime.now().millisecondsSinceEpoch.toString().substring(9, 13);

        print('✅ Yeni device_id oluşturuldu: $deviceId');

        // Bilgileri locale kaydet
        await prefs.setString('device_id', deviceId);
        await prefs.setString('user_name', nameController.text);
        await prefs.setString('user_code', userCode);

        // Kayıt kontrolü
        final savedDeviceId = prefs.getString('device_id');
        if (savedDeviceId != deviceId) {
          print('❌ Device ID kaydedilemedi');
          throw 'Device ID kaydedilemedi';
        }
        print('✅ Device ID başarıyla kaydedildi');

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgeStep(
                name: nameController.text,
                phone: '',
                userId: '',
                deviceId: deviceId,
                userCode: userCode,
              ),
            ),
          );
        }
      } catch (e) {
        print('❌ Kayıt hatası: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
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
                  "Merhaba,\nSeni Tanıyalım",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Başlamak için adını gir",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Adınızı ve soyadınızı girin',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.blue.shade800, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 3) {
                        return "En az 3 karakter giriniz";
                      }
                      return null;
                    },
                    style: const TextStyle(fontSize: 16),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
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
                    onPressed: _navigateToNextStep,
                    child: const Text(
                      "İleri",
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }
}
