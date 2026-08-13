import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DbHelper {
  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _client = Supabase.instance.client;

  // ============================================================
  // AUTH
  // ============================================================

  User? get currentUser {
    return _client.auth.currentUser;
  }

  bool get isLoggedIn {
    return currentUser != null;
  }

  // ------------------------------------------------------------
  // SIGN UP
  // ------------------------------------------------------------

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    return response;
  }

  // ------------------------------------------------------------
  // SIGN IN
  // ------------------------------------------------------------

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ------------------------------------------------------------
  // SIGN OUT
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // GET OTHER PROFILE
  // ------------------------------------------------------------

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  // ============================================================
  // FULL PROFILE DATA (UNTUK PROFILE PAGE)
  // ============================================================

  Future<Map<String, dynamic>?> getFullProfileData() async {
    final user = currentUser;
    if (user == null) return null;

    // 1. Ambil Data User/Profile (Pastikan method getMyProfile() mengambil dari tabel 'users')
    final profile = await getMyProfile();

    // 2. Ambil Data Gamification (Streak, Tokens, XP, Rank)
    final gamification = await getMyGamification();

    // 3. Hitung Jumlah Total Notes dari Library
    int totalNotes = 0;
    try {
      final notesResponse = await _client
          .from('library_items')
          .select('id')
          .eq('user_id', user.id)
          .isFilter('deleted_at', null);
      totalNotes = (notesResponse as List).length;
    } catch (e) {
      print('Error hitung notes: $e');
    }

    // 4. Hitung Jumlah Discussion/Post di Forum
    int totalDiscussions = 0;
    try {
      final forumResponse = await _client
          .from('forum_posts')
          .select('id')
          .eq('user_id', user.id)
          .isFilter(
            'deleted_at',
            null,
          ); // <-- DITAMBAHKAN: Filter agar postingan terhapus tidak terhitung
      totalDiscussions = (forumResponse as List).length;
    } catch (e) {
      print('Error hitung forum: $e');
    }

    // 5. Ambil Daftar Achievements User
    List<Map<String, dynamic>> achievements = [];
    try {
      final achResponse = await _client
          .from('user_achievements')
          .select('*, achievements(*)')
          .eq('user_id', user.id);
      achievements = List<Map<String, dynamic>>.from(achResponse);
    } catch (e) {
      print('Error achievements: $e');
      achievements = [];
    }

    return {
      'profile': profile,
      'gamification': gamification,
      'total_notes': totalNotes,
      'total_discussions': totalDiscussions,
      'achievements': achievements,
    };
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

  Future<List<Map<String, dynamic>>> getPets() async =>
      List<Map<String, dynamic>>.from(
        await _client.from('pets').select().order('id'),
      );

  Future<void> choosePet(int petId) async {
    await _client.rpc('choose_pet', params: {'p_pet_id': petId});
  }

  Future<Map<String, dynamic>> claimLearningStreak() async =>
      Map<String, dynamic>.from(await _client.rpc('claim_learning_streak'));

  // ============================================================
  // HOME DATA
  // ============================================================

  Future<Map<String, dynamic>> getHomeData() async {
    final profile = await getMyProfile();

    final gamification = await getMyGamification();

    final pet = await getMyPet();

    return {'profile': profile, 'gamification': gamification, 'pet': pet};
  }

  // ============================================================
  // FORUM
  // ============================================================

  // ------------------------------------------------------------
  // GET FORUM POSTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getForumPosts() async {
    final response = await _client
        .from('forum_posts')
        .select('*, users(username, avatar_url)')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ------------------------------------------------------------
  // CREATE FORUM POST
  // ------------------------------------------------------------

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
  // FORUM - VOTE, ATTACHMENT, DAN LIBRARY
  // ============================================================

  Future<String?> getForumPostVote(int postId) async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from('forum_reactions')
        .select('reaction')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();
    return row?['reaction']?.toString();
  }

  Future<Map<String, dynamic>> setForumPostVote(
    int postId,
    String reaction,
  ) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    if (reaction != 'LIKE' && reaction != 'DISLIKE') {
      throw ArgumentError.value(reaction, 'reaction');
    }

    final result = await _client.rpc(
      'set_forum_post_vote',
      params: {'target_post_id': postId, 'target_reaction': reaction},
    );
    if (result is! Map) throw Exception('Respons vote tidak valid.');
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> getForumAttachments(int postId) async {
    final response = await _client
        .from('forum_attachments')
        .select('''
          id, post_id, file_id, uploaded_by, curation_status,
          curation_feedback, relevance_score, relevance_label, reviewed_at,
          files (id, storage_path, original_name, mime_type, extension, file_size)
        ''')
        .eq('post_id', postId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> uploadForumAttachment({
    required int postId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    final originalName = p.basename(fileName);
    var extension = p
        .extension(originalName)
        .replaceFirst('.', '')
        .toLowerCase();
    if (extension == 'jpeg') extension = 'jpg';
    if (extension.isEmpty) throw Exception('Ekstensi file tidak ditemukan.');

    final storagePath =
        'forum/' +
        user.id +
        '/attachments/' +
        const Uuid().v4() +
        '.' +
        extension;
    try {
      await _client.storage
          .from('chatatan-files')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: _getMimeType(extension)),
          );
      final file = await _client
          .from('files')
          .insert({
            'uploaded_by': user.id,
            'storage_provider': 'SUPABASE',
            'storage_path': storagePath,
            'original_name': originalName,
            'mime_type': _getMimeType(extension),
            'extension': extension,
            'file_size': bytes.length,
          })
          .select('id')
          .single();
      await _client.from('forum_attachments').insert({
        'post_id': postId,
        'file_id': file['id'],
        'uploaded_by': user.id,
        'curation_status': 'PENDING',
      });
    } catch (_) {
      try {
        await _client.storage.from('chatatan-files').remove([storagePath]);
      } catch (_) {}
      rethrow;
    }
  }

  /// Membagikan file yang sudah ada di Library tanpa mengunggah ulang ke Storage.
  Future<void> attachLibraryItemsToForum({
    required int postId,
    required List<int> libraryItemIds,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    if (libraryItemIds.isEmpty) return;

    final items = await _client
        .from('library_items')
        .select('id, file_id')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .inFilter('id', libraryItemIds);

    if (items.length != libraryItemIds.length) {
      throw Exception('Sebagian file Library tidak dapat dibagikan.');
    }

    final attachmentRows = <Map<String, dynamic>>[];
    for (final item in items) {
      final fileId = item['file_id'];
      if (fileId == null) {
        throw Exception('Item Library tanpa file tidak dapat dibagikan.');
      }
      attachmentRows.add({
        'post_id': postId,
        'file_id': fileId,
        'uploaded_by': user.id,
        'curation_status': 'PENDING',
      });
    }
    final attachments = await _client
        .from('forum_attachments')
        .insert(attachmentRows)
        .select('id');

    // Kurasi berjalan di server. Jika provider sedang limit, attachment tetap
    // PENDING dan dapat dicoba lagi tanpa menggagalkan post pengguna.
    for (final attachment in attachments) {
      try {
        await _client.functions.invoke(
          'curate-forum-attachment',
          body: {'attachmentId': attachment['id']},
        );
      } catch (_) {
        // Status PENDING sengaja dipertahankan untuk retry berikutnya.
      }
    }
  }

  /// Mengulang kurasi hanya untuk attachment milik pengguna yang sedang login.
  Future<void> retryForumAttachmentCuration(int attachmentId) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    await _client.functions.invoke(
      'curate-forum-attachment',
      body: {'attachmentId': attachmentId},
    );
  }

  Future<void> saveForumAttachmentToLibrary(
    int attachmentId, {
    String folderName = 'Dari Forum',
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    final attachment = await _client
        .from('forum_attachments')
        .select(
          'file_id, post_id, reply_id, curation_status, files(original_name, extension, mime_type)',
        )
        .eq('id', attachmentId)
        .single();
    if (attachment['curation_status']?.toString() != 'PASSED') {
      throw Exception('File belum tersedia untuk disimpan.');
    }
    final files = attachment['files'];
    if (files is! Map) throw Exception('File forum tidak ditemukan.');

    var folder = await _client
        .from('library_folders')
        .select('id')
        .eq('user_id', user.id)
        .eq('name', folderName)
        .maybeSingle();
    folder ??= await _client
        .from('library_folders')
        .insert({'user_id': user.id, 'name': folderName})
        .select('id')
        .single();

    final extension = files['extension']?.toString() ?? '';
    final mimeType = files['mime_type']?.toString() ?? _getMimeType(extension);
    final categoryId = await _libraryCategoryFromForumAttachment(attachment);
    await _client.from('library_items').insert({
      'user_id': user.id,
      'folder_id': folder['id'],
      'category_id': categoryId,
      'title': files['original_name']?.toString() ?? 'Dokumen dari Forum',
      'description': folderName == 'Dari Balasan Forum'
          ? 'Disimpan dari balasan Forum'
          : 'Disimpan dari Forum',
      'source_type': 'SHARED',
      'content_type': _getContentType(extension, mimeType),
      'file_id': attachment['file_id'],
      'visibility': 'PRIVATE',
      'is_favorite': false,
    });
  }

  /// Mengambil kategori Library berdasarkan hashtag/kategori post Forum.
  /// Jika post tidak punya kategori atau tidak ada kategori Library dengan nama
  /// yang sama, hasilnya null agar item tetap dapat disimpan.
  Future<int?> _libraryCategoryFromForumAttachment(
    Map<String, dynamic> attachment,
  ) async {
    var postId = attachment['post_id'];
    if (postId == null && attachment['reply_id'] != null) {
      final reply = await _client
          .from('forum_replies')
          .select('post_id')
          .eq('id', attachment['reply_id'])
          .maybeSingle();
      postId = reply?['post_id'];
    }
    if (postId == null) return null;

    final post = await _client
        .from('forum_posts')
        .select('category_id')
        .eq('id', postId)
        .maybeSingle();
    final forumCategoryId = post?['category_id'];
    if (forumCategoryId == null) return null;

    final forumCategory = await _client
        .from('forum_categories')
        .select('name')
        .eq('id', forumCategoryId)
        .maybeSingle();
    final name = forumCategory?['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;

    final libraryCategory = await _client
        .from('library_categories')
        .select('id')
        .ilike('name', name)
        .maybeSingle();
    return int.tryParse(libraryCategory?['id']?.toString() ?? '');
  }

  /// Lampiran reply berasal dari Library pemilik reply dan tidak melalui kurasi.
  Future<void> attachLibraryItemsToForumReply({
    required int replyId,
    required List<int> libraryItemIds,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    if (libraryItemIds.isEmpty) return;

    final items = await _client
        .from('library_items')
        .select('id, file_id')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .inFilter('id', libraryItemIds);
    if (items.length != libraryItemIds.length) {
      throw Exception('Sebagian file Library tidak dapat dibagikan.');
    }

    final rows = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item['file_id'] == null) {
        throw Exception('Item Library tanpa file tidak dapat dibagikan.');
      }
      rows.add({
        'reply_id': replyId,
        'file_id': item['file_id'],
        'uploaded_by': user.id,
        'curation_status': 'PASSED',
        'relevance_label': 'Lampiran balasan',
      });
    }
    await _client.from('forum_attachments').insert(rows);
  }

  Future<bool> canCurateForumAttachments() async {
    final user = currentUser;
    if (user == null) return false;
    final profile = await _client
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    final role = profile?['role']?.toString().toLowerCase();
    return role == 'admin' || role == 'dosen';
  }

  Future<void> curateForumAttachment(
    int attachmentId, {
    required String status,
    double? relevanceScore,
    String? relevanceLabel,
    String? feedback,
  }) async {
    if (!await canCurateForumAttachments()) {
      throw Exception('Hanya admin atau dosen yang dapat melakukan kurasi.');
    }
    if (status != 'PASSED' && status != 'FAILED') {
      throw ArgumentError.value(status, 'status');
    }
    await _client
        .from('forum_attachments')
        .update({
          'curation_status': status,
          'relevance_score': relevanceScore,
          'relevance_label': relevanceLabel?.trim().isEmpty ?? true
              ? null
              : relevanceLabel!.trim(),
          'curation_feedback': feedback?.trim().isEmpty ?? true
              ? null
              : feedback!.trim(),
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', attachmentId);
  }

  // ============================================================
  // CHAT - RECENT CHAT
  // ============================================================

  Future<List<Map<String, dynamic>>> getRecentChats({int limit = 3}) async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    // ----------------------------------------------------------
    // 1. GET USER MEMBERSHIPS
    // ----------------------------------------------------------

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

    // ----------------------------------------------------------
    // 2. GET CONVERSATIONS
    // ----------------------------------------------------------

    final conversations = await _client
        .from('conversations')
        .select()
        .inFilter('id', conversationIds)
        .eq('conversation_type', 'PRIVATE')
        .order('updated_at', ascending: false)
        .limit(limit);

    final result = <Map<String, dynamic>>[];

    // ----------------------------------------------------------
    // 3. GET DETAILS
    // ----------------------------------------------------------

    for (final conversation in conversations) {
      final conversationId = conversation['id'];

      // --------------------------------------------------------
      // LAST MESSAGE
      // --------------------------------------------------------

      final messages = await _client
          .from('messages')
          .select('id, sender_id, message_type, content, status, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1);

      Map<String, dynamic>? lastMessage;

      if (messages.isNotEmpty) {
        lastMessage = messages.first;
      }

      // --------------------------------------------------------
      // OTHER USER
      // --------------------------------------------------------

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
                .select('id, username, avatar_url')
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
    for (final item in result) {
      final settings = await _client
          .from('conversation_member_settings')
          .select('is_pinned, nickname, pinned_at')
          .eq('conversation_id', item['conversation']['id'])
          .eq('user_id', user.id)
          .maybeSingle();
      item['settings'] = settings ?? <String, dynamic>{};
    }
    result.sort((a, b) {
      final aPinned = a['settings']?['is_pinned'] == true;
      final bPinned = b['settings']?['is_pinned'] == true;
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      return 0;
    });
    return result;
  }

  // ============================================================
  // HOME - RECENT FORUMS
  // ============================================================

  Future<List<Map<String, dynamic>>> getRecentForums({int limit = 3}) async {
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

  // ============================================================
  // LIBRARY
  // ============================================================

  // ------------------------------------------------------------
  // GET LIBRARY ITEMS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getLibraryItems({
    String? search,
    int? categoryId,
    int? folderId,
  }) async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    var query = _client
        .from('library_items')
        .select('''
          id,
          user_id,
          folder_id,
          category_id,
          title,
          description,
          source_type,
          content_type,
          file_id,
          ai_scan_id,
          visibility,
          is_favorite,
          created_at,
          updated_at,
          files (
            id,
            storage_provider,
            storage_path,
            original_name,
            mime_type,
            extension,
            file_size,
            width,
            height
          )
        ''')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null);

    // ----------------------------------------------------------
    // SEARCH
    // ----------------------------------------------------------

    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('title', '%${search.trim()}%');
    }

    // ----------------------------------------------------------
    // CATEGORY FILTER
    // ----------------------------------------------------------

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    // ----------------------------------------------------------
    // FOLDER FILTER
    // ----------------------------------------------------------

    if (folderId != null) {
      query = query.eq('folder_id', folderId);
    }

    // ----------------------------------------------------------
    // RESULT
    // ----------------------------------------------------------

    final response = await query.order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Mengambil folder milik pengguna yang sedang masuk.
  Future<void> ensureDefaultLibraryFolders() async {
    final user = currentUser;
    if (user == null) return;

    for (final name in const ['Dari Forum', 'Dari Balasan Forum']) {
      final existing = await _client
          .from('library_folders')
          .select('id')
          .eq('user_id', user.id)
          .eq('name', name)
          .maybeSingle();
      if (existing == null) {
        await _client.from('library_folders').insert({
          'user_id': user.id,
          'name': name,
          'description': name == 'Dari Forum'
              ? 'File yang disimpan dari postingan Forum'
              : 'File yang disimpan dari balasan Forum',
        });
      }
    }
  }

  /// Mengambil folder milik pengguna yang sedang masuk.
  Future<List<Map<String, dynamic>>> getLibraryFolders() async {
    return getLibraryFoldersByParent();
  }

  Future<List<Map<String, dynamic>>> getLibraryFoldersByParent({
    int? parentFolderId,
  }) async {
    final user = currentUser;
    if (user == null) return [];

    var query = _client
        .from('library_folders')
        .select('id, parent_folder_id, name, description, color, icon')
        .eq('user_id', user.id);
    query = parentFolderId == null
        ? query.isFilter('parent_folder_id', null)
        : query.eq('parent_folder_id', parentFolderId);
    final response = await query.order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Kategori bersifat global sesuai skema database.
  Future<List<Map<String, dynamic>>> getLibraryCategories() async {
    final response = await _client
        .from('library_categories')
        .select('id, name, description, icon, color')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createLibraryFolder({
    required String name,
    String? description,
    int? parentFolderId,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');

    await _client.from('library_folders').insert({
      'user_id': user.id,
      'name': name.trim(),
      'parent_folder_id': parentFolderId,
      'description': description?.trim().isEmpty ?? true
          ? null
          : description!.trim(),
    });
  }

  Future<void> updateLibraryItem(
    int itemId, {
    required String title,
    String? description,
    int? folderId,
    int? categoryId,
    required bool isFavorite,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');

    await _client
        .from('library_items')
        .update({
          'title': title.trim(),
          'description': description?.trim().isEmpty ?? true
              ? null
              : description!.trim(),
          'folder_id': folderId,
          'category_id': categoryId,
          'is_favorite': isFavorite,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  Future<void> moveLibraryItem(int itemId, {int? folderId}) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');
    await _client
        .from('library_items')
        .update({
          'folder_id': folderId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  Future<void> setLibraryItemFavorite(int itemId, bool isFavorite) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');

    await _client
        .from('library_items')
        .update({
          'is_favorite': isFavorite,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  /// Soft delete menjaga file dan relasi lain tetap aman di database.
  Future<void> deleteLibraryItem(int itemId) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');

    await _client
        .from('library_items')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  // ============================================================
  // LIBRARY - UPLOAD GENERAL FILE
  // ============================================================

  Future<Map<String, dynamic>> uploadLibraryFile({
    required Uint8List bytes,
    required String fileName,
    required String title,
    String? description,
    String sourceType = 'UPLOAD',
    String? contentType,
    int? folderId,
    int? categoryId,
    int? aiScanId,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    // ============================================================
    // FILE INFO
    // ============================================================

    final originalName = p.basename(fileName);

    var extension = p
        .extension(originalName)
        .replaceFirst('.', '')
        .toLowerCase();

    if (extension == 'jpeg') {
      extension = 'jpg';
    }

    if (extension.isEmpty) {
      throw Exception('Ekstensi file tidak ditemukan.');
    }

    final fileSize = bytes.length;

    // ============================================================
    // MIME TYPE
    // ============================================================

    final mimeType = _getMimeType(extension);

    // ============================================================
    // CONTENT TYPE
    // ============================================================

    final finalContentType =
        contentType ?? _getContentType(extension, mimeType);

    // ============================================================
    // STORAGE FOLDER
    // ============================================================

    String storageFolder = 'documents';

    if (finalContentType == 'IMAGE') {
      storageFolder = 'images';
    } else if (finalContentType == 'PDF') {
      storageFolder = 'pdfs';
    } else if (sourceType == 'AI_SCAN') {
      storageFolder = 'scans';
    }

    // ============================================================
    // STORAGE PATH
    // ============================================================

    final fileUuid = const Uuid().v4();

    final storagePath =
        'library/${user.id}/'
        '$storageFolder/'
        '$fileUuid.$extension';

    try {
      // ==========================================================
      // 1. UPLOAD KE SUPABASE STORAGE
      // ==========================================================

      await _client.storage
          .from('chatatan-files')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      // ==========================================================
      // 2. INSERT KE TABLE files
      // ==========================================================

      final fileRecord = await _client
          .from('files')
          .insert({
            'uploaded_by': user.id,
            'storage_provider': 'SUPABASE',
            'storage_path': storagePath,
            'original_name': originalName,
            'mime_type': mimeType,
            'extension': extension,
            'file_size': fileSize,
          })
          .select()
          .single();

      final fileId = fileRecord['id'];

      // ==========================================================
      // 3. INSERT KE TABLE library_items
      // ==========================================================

      final libraryRecord = await _client
          .from('library_items')
          .insert({
            'user_id': user.id,
            'folder_id': folderId,
            'category_id': categoryId,
            'title': title,
            'description': description,
            'source_type': sourceType,
            'content_type': finalContentType,
            'file_id': fileId,
            'ai_scan_id': aiScanId,
            'visibility': 'PRIVATE',
            'is_favorite': false,
          })
          .select()
          .single();

      // ==========================================================
      // RETURN
      // ==========================================================

      return {'file': fileRecord, 'library_item': libraryRecord};
    } catch (e) {
      // ==========================================================
      // CLEANUP STORAGE
      // ==========================================================

      try {
        await _client.storage.from('chatatan-files').remove([storagePath]);
      } catch (_) {
        // Jangan menutupi error utama
      }

      rethrow;
    }
  }

  // ============================================================
  // LIBRARY - UPLOAD IMAGE
  // ============================================================

  Future<Map<String, dynamic>> uploadLibraryImage({
    required XFile image,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final Uint8List bytes = await image.readAsBytes();

    final originalName = image.name;

    var extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';

    if (extension == 'jpeg') {
      extension = 'jpg';
    }

    final mimeType = _getMimeType(extension);

    final fileUuid = const Uuid().v4();

    final storagePath =
        'library/${user.id}/'
        'images/'
        '$fileUuid.$extension';

    try {
      // ========================================================
      // 1. STORAGE
      // ========================================================

      await _client.storage
          .from('chatatan-files')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      // ========================================================
      // 2. FILES
      // ========================================================

      final fileRecord = await _client
          .from('files')
          .insert({
            'uploaded_by': user.id,
            'storage_provider': 'SUPABASE',
            'storage_path': storagePath,
            'original_name': originalName,
            'mime_type': mimeType,
            'extension': extension,
            'file_size': bytes.length,
          })
          .select()
          .single();

      final fileId = fileRecord['id'];

      // ========================================================
      // 3. LIBRARY ITEMS
      // ========================================================

      final libraryRecord = await _client
          .from('library_items')
          .insert({
            'user_id': user.id,
            'title': originalName,
            'description': 'Image uploaded to Library',
            'source_type': 'UPLOAD',
            'content_type': 'IMAGE',
            'file_id': fileId,
            'visibility': 'PRIVATE',
            'is_favorite': false,
          })
          .select()
          .single();

      return {'file': fileRecord, 'library_item': libraryRecord};
    } catch (e) {
      // ========================================================
      // CLEANUP
      // ========================================================

      try {
        await _client.storage.from('chatatan-files').remove([storagePath]);
      } catch (_) {}

      rethrow;
    }
  }

  // ============================================================
  // LIBRARY - SIGNED URL
  // ============================================================

  Future<String> getLibraryFileUrl(
    String storagePath, {
    int expiresIn = 3600,
  }) async {
    try {
      return await _client.storage
          .from('chatatan-files')
          .createSignedUrl(storagePath, expiresIn);
    } catch (e) {
      throw Exception('Gagal membuat URL file: $e');
    }
  }

  /// A signed link that forces browser downloads for seven days by default.
  Future<String> getLibraryDownloadUrl(
    String storagePath, {
    int expiresIn = 60 * 60 * 24 * 7,
  }) async {
    try {
      return await _client.storage
          .from('chatatan-files')
          .createSignedUrl(
            storagePath,
            expiresIn,
            download: DownloadBehavior.withOriginalName,
          );
    } catch (e) {
      throw Exception('Gagal membuat link unduhan: $e');
    }
  }

  // ============================================================
  // LIBRARY - MIME TYPE
  // ============================================================

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'gif':
        return 'image/gif';

      case 'pdf':
        return 'application/pdf';

      case 'txt':
        return 'text/plain';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'xls':
        return 'application/vnd.ms-excel';

      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';

      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // LIBRARY - CONTENT TYPE
  // ============================================================

  String _getContentType(String extension, String mimeType) {
    // IMAGE
    if (mimeType.startsWith('image/')) {
      return 'IMAGE';
    }

    // PDF
    if (extension == 'pdf') {
      return 'PDF';
    }

    // DOCUMENT
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(extension)) {
      return 'DOCUMENT';
    }

    // TEXT
    if (extension == 'txt') {
      return 'TEXT';
    }

    // Default
    return 'DOCUMENT';
  }

  // ============================================================
  // PENCARIAN USER & PRIVATE CHAT
  // ============================================================

  /// 1. Cari user berdasarkan username/nama
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final user = currentUser;
    if (user == null || query.trim().isEmpty) return [];

    final response = await _client
        .from('users')
        .select('id, username, avatar_url')
        .neq('id', user.id) // Jangan tampilkan diri sendiri
        .ilike('username', '%${query.trim()}%')
        .limit(10);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> searchForumPosts(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return [];
    final response = await _client
        .from('forum_posts')
        .select('id, title, content, created_at')
        .or('title.ilike.%$keyword%,content.ilike.%$keyword%')
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(response);
  }

  /// 2. Ambil ID percakapan PRIVATE yang ada, atau buat baru jika belum pernah chat
  Future<int> getOrCreatePrivateConversation(String targetUserId) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');

    // Cek membership user saat ini & target user
    final myMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', user.id);

    final targetMemberships = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', targetUserId);

    final myIds = myMemberships.map((e) => e['conversation_id']).toSet();
    final targetIds = targetMemberships
        .map((e) => e['conversation_id'])
        .toSet();
    final sharedConvIds = myIds.intersection(targetIds);

    // Jika sudah ada ruang chat bersama
    if (sharedConvIds.isNotEmpty) {
      final existingPrivate = await _client
          .from('conversations')
          .select('id')
          .inFilter('id', sharedConvIds.toList())
          .eq('conversation_type', 'PRIVATE')
          .maybeSingle();

      if (existingPrivate != null) {
        return existingPrivate['id'] as int;
      }
    }

    // Jika belum ada, buat percakapan PRIVATE baru
    final newConv = await _client
        .from('conversations')
        .insert({
          'conversation_type': 'PRIVATE',
          'title': 'Private Chat',
          'created_by': user.id,
        })
        .select('id')
        .single();

    final newConvId = newConv['id'] as int;

    // Daftarkan kedua user ke conversation_members
    await _client.from('conversation_members').insert([
      {'conversation_id': newConvId, 'user_id': user.id},
      {'conversation_id': newConvId, 'user_id': targetUserId},
    ]);

    return newConvId;
  }

  // ============================================================
  // CHAT & COMMUNITY (TAMBAHAN UNTUK COMMUNITY CHAT)
  // ============================================================

  /// 1. Mengambil daftar semua percakapan/grup
  Future<List<Map<String, dynamic>>> getConversations() async {
    final response = await _client
        .from('conversations')
        .select('id, title, conversation_type, updated_at')
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// 2. Stream Realtime pesan berdasarkan ID Percakapan
  Stream<List<Map<String, dynamic>>> getMessagesStream(int conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  Future<void> setMyPresence(bool isOnline) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('user_presence').upsert({
      'user_id': user.id,
      'is_online': isOnline,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> markConversationRead(int conversationId, int messageId) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('conversation_members')
        .update({'last_read_message_id': messageId})
        .eq('conversation_id', conversationId)
        .eq('user_id', user.id);
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('entity_type', 'CONVERSATION')
          .eq('entity_id', conversationId)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<Map<int, int>> getConversationUnreadCounts() async {
    final user = currentUser;
    if (user == null) return {};
    final response = await _client.rpc('get_my_conversation_unreads');
    final result = <int, int>{};
    for (final row in response as List) {
      final id = int.tryParse(row['conversation_id'].toString());
      final count = int.tryParse(row['unread_count'].toString()) ?? 0;
      if (id != null && count > 0) result[id] = count;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 100}) async {
    final user = currentUser;
    if (user == null) return [];
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> getUnreadNotificationCount() async {
    final user = currentUser;
    if (user == null) return 0;
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);
    return response.length;
  }

  Future<void> markNotificationRead(int notificationId) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId)
        .eq('user_id', user.id);
  }

  Future<void> markAllNotificationsRead() async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from('notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  Future<void> setConversationPinned(int conversationId, bool pinned) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('conversation_member_settings').upsert({
      'conversation_id': conversationId,
      'user_id': user.id,
      'is_pinned': pinned,
      'pinned_at': pinned ? DateTime.now().toUtc().toIso8601String() : null,
    });
  }

  Future<void> setConversationNickname(
    int conversationId,
    String? nickname,
  ) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('conversation_member_settings').upsert({
      'conversation_id': conversationId,
      'user_id': user.id,
      'nickname': nickname?.trim().isEmpty ?? true ? null : nickname!.trim(),
    });
  }

  Future<List<Map<String, dynamic>>> getConversationMedia(
    int conversationId,
  ) async {
    final response = await _client
        .from('messages')
        .select('id, sender_id, message_type, content, created_at')
        .eq('conversation_id', conversationId)
        .inFilter('message_type', ['IMAGE', 'FILE'])
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// 3. Mengirim pesan baru ke percakapan
  Future<void> sendMessage({
    required int conversationId,
    required String content,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login.');

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'message_type': 'TEXT',
      'content': content,
      'status': 'SENT',
    });

    await _client
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  // ============================================================
  // GRUB CHAT
  // ============================================================

  /// 1. Membuat Percakapan Grup Baru beserta Anggotanya
  Future<int> createGroupConversation({
    required String title,
    required List<String> selectedUserIds,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User belum login');

    // Buat baris baru di tabel conversations (tipe GROUP)
    final newConv = await _client
        .from('conversations')
        .insert({
          'conversation_type': 'GROUP',
          'title': title,
          'created_by': user.id,
        })
        .select('id')
        .single();

    final int conversationId = newConv['id'] as int;

    // Pastikan pembuat grup juga masuk ke daftar anggota (tanpa duplikat)
    final Set<String> allMemberIds = {user.id, ...selectedUserIds};

    // Format data untuk batch insert ke conversation_members
    final membersData = allMemberIds
        .map((userId) => {'conversation_id': conversationId, 'user_id': userId})
        .toList();

    await _client.from('conversation_members').insert(membersData);

    return conversationId;
  }

  /// 2. Mengambil Daftar Grup yang Diikuti User
  Future<List<Map<String, dynamic>>> getGroupConversations() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('conversation_members')
        .select('''
          conversation:conversations!inner (
            id,
            title,
            conversation_type,
            created_at,
            updated_at,
            conversation_members ( count )
          )
        ''')
        .eq('user_id', user.id)
        .eq('conversations.conversation_type', 'GROUP');

    List<Map<String, dynamic>> groups = [];
    for (var item in (response as List)) {
      if (item['conversation'] != null) {
        groups.add(Map<String, dynamic>.from(item['conversation']));
      }
    }

    return groups;
  }

  Future<String> getFileSignedUrl(int fileId) async {
    final response = await _client
        .from('files')
        .select('storage_path')
        .eq('id', fileId)
        .single();

    final storagePath = response['storage_path']?.toString();

    if (storagePath == null || storagePath.isEmpty) {
      throw Exception('Storage path file tidak ditemukan');
    }

    final signedUrl = await _client.storage
        .from('chatatan-files')
        .createSignedUrl(storagePath, 60 * 60);

    return signedUrl;
  }

  /// 1. Menambahkan anggota baru ke grup yang sudah ada
  Future<void> addMembersToGroup({
    required dynamic conversationId,
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) return;

    final convIdInt = int.tryParse(conversationId.toString()) ?? conversationId;

    final membersData = userIds
        .map((userId) => {'conversation_id': convIdInt, 'user_id': userId})
        .toList();

    await _client.from('conversation_members').insert(membersData);
  }

  /// 2. Mengambil daftar ID anggota yang sudah ada dalam grup
  Future<List<String>> getGroupMemberIds(dynamic conversationId) async {
    final convIdInt = int.tryParse(conversationId.toString()) ?? conversationId;

    final response = await _client
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', convIdInt);

    return (response as List)
        .map((item) => item['user_id'].toString())
        .toList();
  }

  Future<List<Map<String, dynamic>>> getConversationMembers(
    int conversationId,
  ) async {
    final memberships = await _client
        .from('conversation_members')
        .select('user_id, role, joined_at')
        .eq('conversation_id', conversationId)
        .order('joined_at');
    final ids = memberships
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];
    final users = await _client
        .from('users')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', ids);
    final byId = <String, Map<String, dynamic>>{
      for (final user in users)
        user['id'].toString(): Map<String, dynamic>.from(user),
    };
    return memberships.map<Map<String, dynamic>>((member) {
      final id = member['user_id'].toString();
      return {...Map<String, dynamic>.from(member), ...(byId[id] ?? {})};
    }).toList();
  }

  // ------------------------------------------------------------
  // UPDATE AVATAR / PROFILE PICTURE
  // ------------------------------------------------------------

  // 1. Ubah return type menjadi Future<String?> (pakai tanda tanya ?)
  Future<String?> uploadAvatar(XFile image) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User belum login.');
      }

      final Uint8List bytes = await image.readAsBytes();
      final originalName = image.name;

      var extension = originalName.contains('.')
          ? originalName.split('.').last.toLowerCase()
          : 'jpg';
      if (extension == 'jpeg') extension = 'jpg';

      // Path penyimpanan file di bucket 'avatars'
      final storagePath = '${user.id}/avatar_${const Uuid().v4()}.$extension';

      // 1. Upload file gambar ke bucket 'avatars' di Supabase Storage
      await _client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(extension),
              upsert: true,
            ),
          );

      // 2. Dapatkan URL publik dari gambar yang baru diupload
      final avatarUrl = _client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      // 3. Update kolom 'avatar_url' pada tabel 'users' milik user ini
      await _client
          .from('users')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);

      return avatarUrl;
    } catch (e) {
      // 2. Jika terjadi error (koneksi, storage policy, dll), kembalikan null
      print('Error uploadAvatar: $e');
      return null;
    }
  }

  // ============================================================
  // BOOKMARK POSTINGAN FORUM
  // ============================================================

  /// 1. Cek status bookmark postingan forum
  Future<bool> isForumPostBookmarked(int postId) async {
    final user = currentUser;
    if (user == null) return false;

    final response = await _client
        .from('forum_bookmarks')
        .select('id')
        .eq('user_id', user.id)
        .eq('post_id', postId)
        .maybeSingle();

    return response != null;
  }

  /// 2. Toggle simpan/batal simpan bookmark postingan forum
  Future<bool> toggleForumBookmark(int postId, bool currentlyBookmarked) async {
    final user = currentUser;
    if (user == null) throw Exception("User belum terautentikasi.");

    if (currentlyBookmarked) {
      await _client
          .from('forum_bookmarks')
          .delete()
          .eq('user_id', user.id)
          .eq('post_id', postId);
      return false;
    } else {
      await _client.from('forum_bookmarks').insert({
        'user_id': user.id,
        'post_id': postId,
      });
      return true;
    }
  }

  /// Mengambil semua postingan forum yang di-bookmark oleh pengguna aktif
  Future<List<Map<String, dynamic>>> getBookmarkedForumPosts() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('forum_bookmarks')
        .select(', forum_posts(, users(*))')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
