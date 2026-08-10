import 'package:supabase_flutter/supabase_flutter.dart';

class DbHelper {
  final SupabaseClient _client = Supabase.instance.client;

  // ============================================================
  // AUTH
  // ============================================================

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
      },
    );

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    final response = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }
  // ============================================================
  // HOME - GAMIFICATION
  // ============================================================

  Future<Map<String, dynamic>?> getMyGamification() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    final response = await _client
        .from('user_gamification')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return response;
  }

  // ============================================================
  // HOME - PET
  // ============================================================

  Future<Map<String, dynamic>?> getMyPet() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    final gamification = await getMyGamification();

    if (gamification == null) {
      return null;
    }

    final petId = gamification['pet_id'];

    if (petId == null) {
      return null;
    }

    final response = await _client
        .from('pets')
        .select()
        .eq('id', petId)
        .maybeSingle();

    return response;
  }

  // ============================================================
  // HOME DATA
  // ============================================================

  Future<Map<String, dynamic>> getHomeData() async {
    final profile = await getMyProfile();
    final gamification = await getMyGamification();
    final pet = await getMyPet();

    return {
      'profile': profile,
      'gamification': gamification,
      'pet': pet,
    };
  }

  // ============================================================
  // FORUM
  // ============================================================

  Future<List<Map<String, dynamic>>> getForumPosts() async {
    final response = await _client
        .from('forum_posts')
        .select('*, users(username, avatar_url)')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createForumPost({
    required String title,
    required String content,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    await _client.from('forum_posts').insert({
      'user_id': user.id,
      'title': title,
      'content': content,
    });
  }

  // ============================================================
  // CHAT
  // ============================================================

  Future<List<Map<String, dynamic>>> getRecentChats({
    int limit = 3,
  }) async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    // Ambil conversation yang user ikuti
    final memberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', user.id);

    if (memberships.isEmpty) {
      return [];
    }

    final conversationIds = memberships
        .map((item) => item['conversation_id'])
        .where((id) => id != null)
        .toList();

    if (conversationIds.isEmpty) {
      return [];
    }

    // Ambil conversation
    final conversations = await _client
        .from('conversations')
        .select()
        .inFilter('id', conversationIds)
        .order('updated_at', ascending: false)
        .limit(limit);

    final result = <Map<String, dynamic>>[];

    for (final conversation in conversations) {
      final conversationId = conversation['id'];

      // Ambil message terakhir
      final messages = await _client
          .from('messages')
          .select(
            'id, sender_id, message_type, content, status, created_at',
          )
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1);

      Map<String, dynamic>? lastMessage;

      if (messages.isNotEmpty) {
        lastMessage = messages.first;
      }

      // Ambil member lain untuk private chat
      Map<String, dynamic>? otherUser;

      if (conversation['conversation_type'] == 'PRIVATE') {
        final members = await _client
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', conversationId)
            .neq('user_id', user.id)
            .limit(1);

        if (members.isNotEmpty) {
          final otherUserId = members.first['user_id'];

          if (otherUserId != null) {
            otherUser = await _client
                .from('users')
                .select(
                  'id, username, avatar_url',
                )
                .eq('id', otherUserId)
                .maybeSingle();
          }
        }
      }

      result.add({
        'conversation': conversation,
        'last_message': lastMessage,
        'other_user': otherUser,
      });
    }

    return result;
  }

  // ============================================================
  // HOME - RECENT FORUMS
  // ============================================================

  Future<List<Map<String, dynamic>>> getRecentForums({
    int limit = 3,
  }) async {
    final response = await _client
        .from('forum_posts')
        .select('''
          id,
          user_id,
          category_id,
          title,
          content,
          like_count,
          dislike_count,
          reply_count,
          created_at
        ''')
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

}