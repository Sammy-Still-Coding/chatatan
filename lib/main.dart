import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const AplikasiTes());
}

class AplikasiTes extends StatelessWidget {
  const AplikasiTes({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              const Text(
                'Hai',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30), 
              ElevatedButton(
                onPressed: () {
                  // Perintah ini yang akan menutup aplikasi saat tombol ditekan
                  SystemNavigator.pop(); 
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 80), 
                  shape: const CircleBorder(), 
                ),
                child: const Text(
                  '1',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}