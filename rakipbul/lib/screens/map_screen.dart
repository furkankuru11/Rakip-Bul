import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          Text(
            'Yakındaki Sahalar',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          // Harita entegrasyonu buraya gelecek
        ],
      ),
    );
  }
}
