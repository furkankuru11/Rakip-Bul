import 'package:flutter/material.dart';

class JoinTeamScreen extends StatelessWidget {
  const JoinTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takıma Katıl'),
      ),
      body: const Center(
        child: Text('Takıma Katılma Sayfası'),
      ),
    );
  }
}
