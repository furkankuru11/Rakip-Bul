import 'package:flutter/material.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedPosition;
  String? selectedLevel;

  // Form değerleri
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Oyuncu Kaydı',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen ad soyad giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Yaş',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen yaşınızı giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen telefon numaranızı giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedPosition,
                    decoration: const InputDecoration(
                      labelText: 'Pozisyon',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Kaleci', child: Text('Kaleci')),
                      DropdownMenuItem(value: 'Defans', child: Text('Defans')),
                      DropdownMenuItem(
                          value: 'Orta Saha', child: Text('Orta Saha')),
                      DropdownMenuItem(value: 'Forvet', child: Text('Forvet')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedPosition = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Lütfen pozisyon seçiniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Seviye',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Amatör', child: Text('Amatör')),
                      DropdownMenuItem(value: 'Orta', child: Text('Orta')),
                      DropdownMenuItem(value: 'İyi', child: Text('İyi')),
                      DropdownMenuItem(
                          value: 'Profesyonel', child: Text('Profesyonel')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedLevel = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Lütfen seviye seçiniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // TODO: Form verilerini Firebase'e kaydet
                        print('Ad Soyad: ${_nameController.text}');
                        print('Yaş: ${_ageController.text}');
                        print('Telefon: ${_phoneController.text}');
                        print('Pozisyon: $selectedPosition');
                        print('Seviye: $selectedLevel');
                      }
                    },
                    child: const Text('Kayıt Ol'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Geri Dön'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
