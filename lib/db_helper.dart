import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DbHelper {
  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _client =
      Supabase.instance.client;

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
      data: {
        'username': username,
      },
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

  Future<Map<String, dynamic>?> getProfile(
    String userId,
  ) async {
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

    final gamification =
        await getMyGamification();

    if (gamification == null) {
      return null;
    }

    final petId =
        gamification['pet_id'];

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
    final profile =
        await getMyProfile();

    final gamification =
        await getMyGamification();

    final pet =
        await getMyPet();

    return {
      'profile': profile,
      'gamification': gamification,
      'pet': pet,
    };
  }

  // ============================================================
  // FORUM
  // ============================================================

  // ------------------------------------------------------------
  // GET FORUM POSTS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      getForumPosts() async {
    final response = await _client
        .from('forum_posts')
        .select(
          '*, users(username, avatar_url)',
        )
        .order(
          'created_at',
          ascending: false,
        );

    return List<Map<String, dynamic>>.from(
      response,
    );
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
      throw Exception(
        'User belum login.',
      );
    }

    await _client
        .from('forum_posts')
        .insert({
      'user_id': user.id,
      'title': title,
      'content': content,
    });
  }

  // ============================================================
  // CHAT - RECENT CHAT
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getRecentChats({
    int limit = 3,
  }) async {
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
        .eq(
          'user_id',
          user.id,
        );

    if (memberships.isEmpty) {
      return [];
    }

    final conversationIds =
        memberships
            .map(
              (item) =>
                  item['conversation_id'],
            )
            .where(
              (id) => id != null,
            )
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
        .inFilter(
          'id',
          conversationIds,
        )
        .order(
          'updated_at',
          ascending: false,
        )
        .limit(limit);

    final result =
        <Map<String, dynamic>>[];

    // ----------------------------------------------------------
    // 3. GET DETAILS
    // ----------------------------------------------------------

    for (final conversation
        in conversations) {
      final conversationId =
          conversation['id'];

      // --------------------------------------------------------
      // LAST MESSAGE
      // --------------------------------------------------------

      final messages = await _client
          .from('messages')
          .select(
            'id, sender_id, message_type, content, status, created_at',
          )
          .eq(
            'conversation_id',
            conversationId,
          )
          .order(
            'created_at',
            ascending: false,
          )
          .limit(1);

      Map<String, dynamic>?
          lastMessage;

      if (messages.isNotEmpty) {
        lastMessage = messages.first;
      }

      // --------------------------------------------------------
      // OTHER USER
      // --------------------------------------------------------

      Map<String, dynamic>?
          otherUser;

      if (conversation[
              'conversation_type'] ==
          'PRIVATE') {
        final members = await _client
            .from('conversation_members')
            .select('user_id')
            .eq(
              'conversation_id',
              conversationId,
            )
            .neq(
              'user_id',
              user.id,
            )
            .limit(1);

        if (members.isNotEmpty) {
          final otherUserId =
              members.first['user_id'];

          if (otherUserId != null) {
            otherUser = await _client
                .from('users')
                .select(
                  'id, username, avatar_url',
                )
                .eq(
                  'id',
                  otherUserId,
                )
                .maybeSingle();
          }
        }
      }

      result.add({
        'conversation':
            conversation,
        'last_message':
            lastMessage,
        'other_user':
            otherUser,
      });
    }

    return result;
  }

  // ============================================================
  // HOME - RECENT FORUMS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getRecentForums({
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
        .order(
          'created_at',
          ascending: false,
        )
        .limit(limit);

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================================
  // LIBRARY
  // ============================================================

  // ------------------------------------------------------------
  // GET LIBRARY ITEMS
  // ------------------------------------------------------------

  Future<List<Map<String, dynamic>>>
      getLibraryItems({
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
        .eq(
          'user_id',
          user.id,
        )
        .isFilter(
          'deleted_at',
          null,
        );

    // ----------------------------------------------------------
    // SEARCH
    // ----------------------------------------------------------

    if (search != null &&
        search.trim().isNotEmpty) {
      query = query.ilike(
        'title',
        '%${search.trim()}%',
      );
    }

    // ----------------------------------------------------------
    // CATEGORY FILTER
    // ----------------------------------------------------------

    if (categoryId != null) {
      query = query.eq(
        'category_id',
        categoryId,
      );
    }

    // ----------------------------------------------------------
    // FOLDER FILTER
    // ----------------------------------------------------------

    if (folderId != null) {
      query = query.eq(
        'folder_id',
        folderId,
      );
    }

    // ----------------------------------------------------------
    // RESULT
    // ----------------------------------------------------------

    final response = await query.order(
      'updated_at',
      ascending: false,
    );

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================================
  // LIBRARY - UPLOAD GENERAL FILE
  // ============================================================

  Future<Map<String, dynamic>>
      uploadLibraryFile({
    required File file,
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
      throw Exception(
        'User belum login.',
      );
    }

    // ----------------------------------------------------------
    // FILE INFO
    // ----------------------------------------------------------

    final originalName =
        p.basename(file.path);

    var extension = p
        .extension(file.path)
        .replaceFirst(
          '.',
          '',
        )
        .toLowerCase();

    if (extension == 'jpeg') {
      extension = 'jpg';
    }

    final fileSize =
        await file.length();

    // ----------------------------------------------------------
    // MIME TYPE
    // ----------------------------------------------------------

    final mimeType =
        _getMimeType(extension);

    // ----------------------------------------------------------
    // CONTENT TYPE
    // ----------------------------------------------------------

    final finalContentType =
        contentType ??
            _getContentType(
              extension,
              mimeType,
            );

    // ----------------------------------------------------------
    // STORAGE FOLDER
    // ----------------------------------------------------------

    String storageFolder =
        'documents';

    if (finalContentType ==
        'IMAGE') {
      storageFolder = 'images';
    } else if (finalContentType ==
        'PDF') {
      storageFolder = 'pdfs';
    } else if (sourceType ==
        'AI_SCAN') {
      storageFolder = 'scans';
    }

    // ----------------------------------------------------------
    // STORAGE PATH
    // ----------------------------------------------------------

    final fileUuid =
        const Uuid().v4();

    final storagePath =
        'library/${user.id}/'
        '$storageFolder/'
        '$fileUuid.$extension';

    try {
      // ========================================================
      // 1. UPLOAD KE STORAGE
      // ========================================================

      await _client.storage
          .from('chatatan-files')
          .upload(
            storagePath,
            file,
            fileOptions:
                FileOptions(
              contentType:
                  mimeType,
              upsert: false,
            ),
          );

      // ========================================================
      // 2. INSERT FILE METADATA
      // ========================================================

      final fileRecord =
          await _client
              .from('files')
              .insert({
        'uploaded_by':
            user.id,
        'storage_provider':
            'SUPABASE',
        'storage_path':
            storagePath,
        'original_name':
            originalName,
        'mime_type':
            mimeType,
        'extension':
            extension,
        'file_size':
            fileSize,
      }).select().single();

      final fileId =
          fileRecord['id'];

      // ========================================================
      // 3. INSERT LIBRARY ITEM
      // ========================================================

      final libraryRecord =
          await _client
              .from('library_items')
              .insert({
        'user_id':
            user.id,
        'folder_id':
            folderId,
        'category_id':
            categoryId,
        'title':
            title,
        'description':
            description,
        'source_type':
            sourceType,
        'content_type':
            finalContentType,
        'file_id':
            fileId,
        'ai_scan_id':
            aiScanId,
        'visibility':
            'PRIVATE',
        'is_favorite':
            false,
      }).select().single();

      return {
        'file':
            fileRecord,
        'library_item':
            libraryRecord,
      };
    } catch (e) {
      // ========================================================
      // CLEANUP STORAGE
      // ========================================================

      try {
        await _client.storage
            .from('chatatan-files')
            .remove([
          storagePath,
        ]);
      } catch (_) {
        // Jangan menutupi error utama
      }

      rethrow;
    }
  }

  // ============================================================
  // LIBRARY - UPLOAD IMAGE
  // ============================================================

  Future<Map<String, dynamic>>
      uploadLibraryImage({
    required XFile image,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception(
        'User belum login.',
      );
    }

    final Uint8List bytes =
        await image.readAsBytes();

    final originalName =
        image.name;

    var extension = originalName
        .contains('.')
        ? originalName
            .split('.')
            .last
            .toLowerCase()
        : 'jpg';

    if (extension == 'jpeg') {
      extension = 'jpg';
    }

    final mimeType =
        _getMimeType(extension);

    final fileUuid =
        const Uuid().v4();

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
            fileOptions:
                FileOptions(
              contentType:
                  mimeType,
              upsert: false,
            ),
          );

      // ========================================================
      // 2. FILES
      // ========================================================

      final fileRecord =
          await _client
              .from('files')
              .insert({
        'uploaded_by':
            user.id,
        'storage_provider':
            'SUPABASE',
        'storage_path':
            storagePath,
        'original_name':
            originalName,
        'mime_type':
            mimeType,
        'extension':
            extension,
        'file_size':
            bytes.length,
      }).select().single();

      final fileId =
          fileRecord['id'];

      // ========================================================
      // 3. LIBRARY ITEMS
      // ========================================================

      final libraryRecord =
          await _client
              .from('library_items')
              .insert({
        'user_id':
            user.id,
        'title':
            originalName,
        'description':
            'Image uploaded to Library',
        'source_type':
            'UPLOAD',
        'content_type':
            'IMAGE',
        'file_id':
            fileId,
        'visibility':
            'PRIVATE',
        'is_favorite':
            false,
      }).select().single();

      return {
        'file':
            fileRecord,
        'library_item':
            libraryRecord,
      };
    } catch (e) {
      // ========================================================
      // CLEANUP
      // ========================================================

      try {
        await _client.storage
            .from('chatatan-files')
            .remove([
          storagePath,
        ]);
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
          .createSignedUrl(
            storagePath,
            expiresIn,
          );
    } catch (e) {
      throw Exception(
        'Gagal membuat URL file: $e',
      );
    }
  }

  // ============================================================
  // LIBRARY - MIME TYPE
  // ============================================================

  String _getMimeType(
    String extension,
  ) {
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
        return
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'xls':
        return 'application/vnd.ms-excel';

      case 'xlsx':
        return
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';

      case 'pptx':
        return
            'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================
  // LIBRARY - CONTENT TYPE
  // ============================================================

  String _getContentType(
    String extension,
    String mimeType,
  ) {
    // IMAGE
    if (mimeType.startsWith(
      'image/',
    )) {
      return 'IMAGE';
    }

    // PDF
    if (extension == 'pdf') {
      return 'PDF';
    }

    // DOCUMENT
    if ([
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
    ].contains(extension)) {
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
    final targetIds = targetMemberships.map((e) => e['conversation_id']).toSet();
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
    final newConv = await _client.from('conversations').insert({
      'conversation_type': 'PRIVATE',
      'title': 'Private Chat',
      'created_by' : user.id,
    }).select('id').single();

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
    final newConv = await _client.from('conversations').insert({
      'conversation_type': 'GROUP',
      'title': title,
      'created_by': user.id,
    }).select('id').single();

    final int conversationId = newConv['id'] as int;

    // Pastikan pembuat grup juga masuk ke daftar anggota (tanpa duplikat)
    final Set<String> allMemberIds = {user.id, ...selectedUserIds};

    // Format data untuk batch insert ke conversation_members
    final membersData = allMemberIds.map((userId) => {
      'conversation_id': conversationId,
      'user_id': userId,
    }).toList();

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

    final storagePath =
        response['storage_path']?.toString();

    if (storagePath == null || storagePath.isEmpty) {
      throw Exception(
        'Storage path file tidak ditemukan',
      );
    }

    final signedUrl = await _client.storage
        .from('chatatan-files')
        .createSignedUrl(
          storagePath,
          60 * 60,
        );

    return signedUrl;
  }
}