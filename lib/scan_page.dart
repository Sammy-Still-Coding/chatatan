import 'package:flutter/material.dart';
import 'ai_test_page.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Scan'), elevation: 0),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              width: 100,
              height: 100,

              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.camera_alt_rounded,
                size: 48,
                color: Colors.deepPurple,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'AI Scan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Scan your notes and learn with AI.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiTestPage()),
              ),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Test koneksi AI'),
            ),
          ],
        ),
      ),
    );
  }
}
