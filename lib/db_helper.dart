import 'package:supabase_flutter/supabase_flutter.dart';

class DbHelper {
  final SupabaseClient _client = Supabase.instance.client;

  // Get User saat ini yang sedang login
  User? get currentUser => _client.auth.currentUser;

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  // Registrasi User Baru
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  // Login User
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // USER PROFILE
  // ---------------------------------------------------------------------------

  // Ambil data profil user yang sedang aktif
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  // ---------------------------------------------------------------------------
  // FORUM & CHAT (Contoh Query Data)
  // ---------------------------------------------------------------------------

  // Ambil daftar postingan forum
  Future<List<Map<String, dynamic>>> getForumPosts() async {
    final response = await _client
        .from('forum_posts')
        .select('*, users(username, avatar_url)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Buat postingan forum baru
  Future<void> createForumPost({
    required String title,
    required String content,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User belum login!');

    await _client.from('forum_posts').insert({
      'user_id': userId,
      'title': title,
      'content': content,
    });
  }
}