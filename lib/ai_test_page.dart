import 'package:flutter/material.dart';
import 'chatatan_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiTestPage extends StatefulWidget {
  const AiTestPage({super.key});

  @override
  State<AiTestPage> createState() => _AiTestPageState();
}

class _AiTestPageState extends State<AiTestPage> {
  final _promptController = TextEditingController(
    text: 'Jelaskan singkat apa itu algoritma dalam bahasa Indonesia.',
  );
  bool _isLoading = false;
  String? _answer;
  String? _provider;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _testAi() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isLoading = true;
      _answer = null;
      _provider = null;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'smart-action',
        body: {'message': prompt, 'history': <Map<String, String>>[]},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Respons AI tidak valid.');
      }
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      if (!mounted) return;
      setState(() {
        _answer = data['answer']?.toString() ?? 'AI tidak memberi jawaban.';
        _provider = data['provider']?.toString();
      });
    } on FunctionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.details?.toString() ?? e.reasonPhrase);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('AI Connection Test')),
      body: ChatatanAmbientBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tes ini memanggil Edge Function smart-action. API key tetap tersimpan di Supabase.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Prompt uji',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _testAi,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_rounded),
              label: Text(_isLoading ? 'Menghubungkan...' : 'Test AI'),
            ),
            if (_provider != null) ...[
              const SizedBox(height: 24),
              Chip(label: Text('Provider: $_provider')),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_answer!),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Gagal: $_error'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
