import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'attachment_preview.dart';
import 'db_helper.dart';
import 'library_attachment_picker.dart';

class CommunityChatPage extends StatefulWidget {
  final dynamic conversationId;
  final String title;
  final bool isGroup;

  const CommunityChatPage({
    super.key,
    required this.conversationId,
    required this.title,
    this.isGroup = false,
  });

  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _presenceTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _memberReadSubscription;

  final Map<String, String> _userCache = {};
  final Set<String> _loadingUserIds = {};
  bool _isUploading = false;
  String _roomSubtitle = '';
  bool _isPinned = false;
  List<Map<String, dynamic>> _otherMembers = [];
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  int _lastReadMessageIdSent = 0;
  late String _roomTitle;

  int get _convIdInt => int.tryParse(widget.conversationId.toString()) ?? 0;
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _memberReadSubscription?.cancel();
    _dbHelper.setMyPresence(false);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _roomTitle = widget.title;
    _dbHelper.setMyPresence(true);
    _loadRoomInfo();
    _memberReadSubscription = _supabase
        .from('conversation_members')
        .stream(primaryKey: ['conversation_id', 'user_id'])
        .eq('conversation_id', _convIdInt)
        .listen(
          _syncReadReceipts,
          // The periodic room refresh remains a safe fallback while a project
          // has not yet enabled this table in Supabase Realtime.
          onError: (_, __) {},
        );
    _presenceTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _dbHelper.setMyPresence(true);
      _loadRoomInfo();
    });
  }

  void _syncReadReceipts(List<Map<String, dynamic>> members) {
    if (!mounted) return;
    final others = members
        .where((member) => member['user_id']?.toString() != currentUserId)
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
    setState(() => _otherMembers = others);
  }

  void _markRoomRead(int messageId) {
    if (messageId <= _lastReadMessageIdSent) return;
    _lastReadMessageIdSent = messageId;
    _dbHelper.markConversationRead(_convIdInt, messageId).catchError((_) {
      _lastReadMessageIdSent = 0;
    });
  }

  Future<void> _loadRoomInfo() async {
    try {
      final members = await _supabase
          .from('conversation_members')
          .select(
            'user_id, last_read_message_id, user_presence(is_online, last_seen_at), conversation_member_settings(is_pinned)',
          )
          .eq('conversation_id', _convIdInt);
      final other = members
          .cast<Map<String, dynamic>>()
          .where((member) => member['user_id']?.toString() != currentUserId)
          .toList();
      final own = members
          .cast<Map<String, dynamic>>()
          .where((member) => member['user_id']?.toString() == currentUserId)
          .toList();
      if (!mounted) return;
      if (other.length == 1) {
        final rawPresence = other.first['user_presence'];
        final presence = rawPresence is List && rawPresence.isNotEmpty
            ? rawPresence.first
            : rawPresence;
        final online = presence is Map && presence['is_online'] == true;
        final seen = presence is Map
            ? DateTime.tryParse(presence['last_seen_at']?.toString() ?? '')
            : null;
        _roomSubtitle = online
            ? 'Online'
            : seen == null
            ? 'Offline'
            : 'Terakhir aktif ${_formatTime(seen)}';
      } else {
        _roomSubtitle = '${members.length} anggota';
      }
      _otherMembers = other;
      try {
        final profiles = await _dbHelper.getConversationMembers(_convIdInt);
        _memberProfiles = {
          for (final profile in profiles)
            profile['user_id']?.toString() ?? '': profile,
        };
      } catch (_) {
        // Read receipts still work with initials if profile lookup is blocked.
      }
      if (!mounted) return;
      final rawOwnSettings = own.isEmpty
          ? null
          : own.first['conversation_member_settings'];
      final ownSettings = rawOwnSettings is List && rawOwnSettings.isNotEmpty
          ? rawOwnSettings.first
          : rawOwnSettings;
      _isPinned = ownSettings is Map && ownSettings['is_pinned'] == true;
      setState(() {});
    } catch (_) {}
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}/${local.year}';
  }

  Future<void> _togglePin() async {
    try {
      await _dbHelper.setConversationPinned(_convIdInt, !_isPinned);
      if (mounted) setState(() => _isPinned = !_isPinned);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengatur pin: $e')));
    }
  }

  Future<void> _setNickname() async {
    final controller = TextEditingController(text: _roomTitle);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nama panggilan chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Contoh: Teman kuliah'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (save != true) {
      controller.dispose();
      return;
    }
    try {
      await _dbHelper.setConversationNickname(_convIdInt, controller.text);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama panggilan disimpan.')),
        );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: _roomTitle);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ubah nama grup'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final title = controller.text.trim();
    controller.dispose();
    if (saved != true || title.isEmpty) return;
    await _supabase
        .from('conversations')
        .update({'title': title})
        .eq('id', _convIdInt);
    if (!mounted) return;
    setState(() => _roomTitle = title);
  }

  /// Mengambil nama pengirim dari tabel users jika belum tersimpan di cache
  void _fetchSenderName(String senderId) {
    if (_userCache.containsKey(senderId) || _loadingUserIds.contains(senderId))
      return;

    _loadingUserIds.add(senderId);

    _supabase
        .from('users')
        .select('username')
        .eq('id', senderId)
        .maybeSingle()
        .then((response) {
          if (mounted) {
            setState(() {
              _userCache[senderId] = response != null
                  ? (response['username'] ?? 'User')
                  : 'User';
              _loadingUserIds.remove(senderId);
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              _userCache[senderId] = 'User';
              _loadingUserIds.remove(senderId);
            });
          }
        });
  }

  /// Mengirim pesan teks biasa
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await _supabase.from('messages').insert({
        'conversation_id': _convIdInt,
        'sender_id': currentUserId,
        'message_type': 'TEXT',
        'content': text,
        'status': 'SENT',
      });

      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _convIdInt);

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim pesan: $e')));
      }
    }
  }

  /// Lampiran chat selalu diambil dari Library agar file dan preview konsisten.
  Future<void> _pickAndSendFile() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      final attachment = await pickLibraryAttachment(context);
      if (attachment == null) return;
      final messageType = attachment.isImage ? 'IMAGE' : 'FILE';

      await _supabase.from('messages').insert({
        'conversation_id': _convIdInt,
        'sender_id': currentUserId,
        'message_type': messageType,
        'content': attachment.locator,
        'status': 'SENT',
      });

      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _convIdInt);

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengunggah file: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Modal Pilihan Jenis Lampiran
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.folder_copy_outlined,
                  color: Color(0xFF6C63FF),
                ),
                title: const Text('Kirim dari Library'),
                subtitle: const Text(
                  'Gambar, PDF, atau dokumen yang sudah disimpan',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRoomDetails({bool openMedia = false}) async {
    final media = await _dbHelper.getConversationMedia(_convIdInt);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: DefaultTabController(
            length: 3,
            initialIndex: openMedia ? 1 : 0,
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    child: Text(_roomTitle.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(
                    _roomTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _roomSubtitle.isEmpty ? 'Info percakapan' : _roomSubtitle,
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Info'),
                    Tab(text: 'Media'),
                    Tab(text: 'Dokumen'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.push_pin_outlined),
                            title: Text(_isPinned ? 'Chat dipin' : 'Pin chat'),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _togglePin();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: const Text('Nama panggilan'),
                            subtitle: const Text(
                              'Atur dari menu chat pada pembaruan berikutnya',
                            ),
                          ),
                        ],
                      ),
                      GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: media
                            .where((item) => item['message_type'] == 'IMAGE')
                            .length,
                        itemBuilder: (_, index) {
                          final item = media
                              .where((item) => item['message_type'] == 'IMAGE')
                              .elementAt(index);
                          final url = item['content']?.toString() ?? '';
                          return InkWell(
                            onTap: () =>
                                openAttachmentPreview(context, url: url),
                            child: FutureBuilder<String>(
                              future: resolveAttachmentUrl(url),
                              builder: (_, snapshot) => snapshot.hasData
                                  ? Image.network(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      ListView(
                        children: media
                            .where((item) => item['message_type'] == 'FILE')
                            .map(
                              (item) => ListTile(
                                leading: const Icon(Icons.description_outlined),
                                title: Text(
                                  attachmentName(
                                    item['content']?.toString() ?? '',
                                  ),
                                ),
                                subtitle: Text(
                                  _formatTime(
                                    DateTime.tryParse(
                                          item['created_at']?.toString() ?? '',
                                        ) ??
                                        DateTime.now(),
                                  ),
                                ),
                                onTap: () => openAttachmentPreview(
                                  context,
                                  url: item['content']?.toString() ?? '',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupMembers() async {
    try {
      final members = await _dbHelper.getConversationMembers(_convIdInt);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anggota $_roomTitle',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (_, index) {
                      final member = members[index];
                      final name =
                          member['full_name']?.toString().trim().isNotEmpty ==
                              true
                          ? member['full_name'].toString()
                          : member['username']?.toString() ?? 'User';
                      final isAdmin = member['role']?.toString() == 'ADMIN';
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(name.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(name),
                        subtitle: isAdmin ? const Text('Admin') : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat anggota: $error')));
    }
  }

  /// Modal Tambah Anggota Grup
  void _showAddMemberModal() async {
    List<String> existingMemberIds = [];
    try {
      existingMemberIds = await _dbHelper.getGroupMemberIds(_convIdInt);
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        List<Map<String, dynamic>> searchResults = [];
        List<Map<String, dynamic>> selectedUsers = [];
        bool isSearching = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 20,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tambah Anggota Grup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (selectedUsers.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        children: selectedUsers.map((u) {
                          return Chip(
                            label: Text(u['username']?.toString() ?? 'User'),
                            onDeleted: () {
                              setModalState(() {
                                selectedUsers.removeWhere(
                                  (item) => item['id'] == u['id'],
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Cari nama / username...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF6C63FF),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) async {
                        if (val.trim().isEmpty) {
                          setModalState(() => searchResults = []);
                          return;
                        }
                        setModalState(() => isSearching = true);
                        final results = await _dbHelper.searchUsers(val);
                        setModalState(() {
                          searchResults = List<Map<String, dynamic>>.from(
                            results,
                          );
                          isSearching = false;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                'Ketik nama untuk mencari anggota baru.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final u = searchResults[index];
                                final uId = u['id']?.toString() ?? '';
                                final isAlreadyMember = existingMemberIds
                                    .contains(uId);
                                final isSelected = selectedUsers.any(
                                  (item) => item['id'] == u['id'],
                                );

                                return ListTile(
                                  title: Text(
                                    u['username']?.toString() ?? 'User',
                                  ),
                                  subtitle: isAlreadyMember
                                      ? const Text(
                                          'Sudah bergabung',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: isAlreadyMember
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.grey,
                                        )
                                      : Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.add_circle_outline,
                                          color: isSelected
                                              ? Colors.green
                                              : const Color(0xFF6C63FF),
                                        ),
                                  onTap: isAlreadyMember
                                      ? null
                                      : () {
                                          setModalState(() {
                                            if (isSelected) {
                                              selectedUsers.removeWhere(
                                                (item) => item['id'] == u['id'],
                                              );
                                            } else {
                                              selectedUsers.add(u);
                                            }
                                          });
                                        },
                                );
                              },
                            ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: selectedUsers.isEmpty
                            ? null
                            : () async {
                                final newIds = selectedUsers
                                    .map((u) => u['id'].toString())
                                    .toList();
                                Navigator.pop(context);

                                try {
                                  await _dbHelper.addMembersToGroup(
                                    conversationId: _convIdInt,
                                    userIds: newIds,
                                  );

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Berhasil menambahkan anggota!',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal menambahkan anggota: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: const Text(
                          'Tambahkan Anggota',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Tampilan konten pesan berdasarkan tipe (TEXT, IMAGE, FILE)
  Widget _buildMessageContent(String content, String type, bool isMe) {
    if (type == 'IMAGE' || type == 'FILE') {
      return AttachmentPreviewTile(url: content, dark: isMe);
    }

    return Text(
      content,
      style: TextStyle(
        color: isMe ? Colors.white : Colors.black87,
        fontSize: 15,
      ),
    );
  }

  Widget _buildReadReceipt(int messageId) {
    final readers = _otherMembers.where((member) {
      final lastRead = int.tryParse(
        member['last_read_message_id']?.toString() ?? '',
      );
      return lastRead != null && lastRead >= messageId;
    }).toList();
    if (readers.isEmpty) return const SizedBox.shrink();

    if (!widget.isGroup) {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Text(
          'Seen',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Seen',
            style: TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(width: 4),
          ...readers.take(4).map((member) {
            final id = member['user_id']?.toString() ?? '';
            final profile = _memberProfiles[id] ?? const <String, dynamic>{};
            final name = profile['username']?.toString() ?? 'U';
            final avatar = profile['avatar_url']?.toString();
            return Padding(
              padding: const EdgeInsets.only(left: 2),
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white,
                backgroundImage: avatar == null || avatar.isEmpty
                    ? null
                    : NetworkImage(avatar),
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    : null,
              ),
            );
          }),
          if (readers.length > 4)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                '+${readers.length - 4}',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showRoomDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_roomTitle, style: const TextStyle(fontSize: 16)),
              if (_roomSubtitle.isNotEmpty)
                Text(_roomSubtitle, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Tambah Anggota',
              onPressed: _showAddMemberModal,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'pin') _togglePin();
              if (value == 'media') _showRoomDetails(openMedia: true);
              if (value == 'details') _showRoomDetails();
              if (value == 'nickname') _setNickname();
              if (value == 'rename_group') _renameGroup();
              if (value == 'members') _showGroupMembers();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pin',
                child: Text(_isPinned ? 'Lepas pin chat' : 'Pin chat'),
              ),
              const PopupMenuItem(
                value: 'media',
                child: Text('Media, link, dan dokumen'),
              ),
              if (widget.isGroup)
                const PopupMenuItem(
                  value: 'members',
                  child: Text('Lihat anggota'),
                ),
              if (widget.isGroup)
                const PopupMenuItem(
                  value: 'rename_group',
                  child: Text('Ubah nama grup'),
                )
              else
                const PopupMenuItem(
                  value: 'nickname',
                  child: Text('Atur nama panggilan'),
                ),
              const PopupMenuItem(
                value: 'details',
                child: Text('Info chat / grup'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('conversation_id', _convIdInt)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Terjadi kesalahan: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isNotEmpty) {
                  final id = int.tryParse(messages.last['id'].toString());
                  if (id != null) _markRoomRead(id);
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada pesan. Mulai percakapan!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final senderId = msg['sender_id']?.toString() ?? '';
                    final isMe = senderId == currentUserId;
                    final content = msg['content'] ?? '';
                    final messageType = msg['message_type'] ?? 'TEXT';
                    final createdAt =
                        DateTime.tryParse(msg['created_at'] ?? '') ??
                        DateTime.now();
                    final timeStr = _formatTime(createdAt);

                    if (!isMe && senderId.isNotEmpty) {
                      _fetchSenderName(senderId);
                    }

                    final senderName = _userCache[senderId] ?? 'Memuat...';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue.shade600
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              Text(
                                senderName,
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            _buildMessageContent(content, messageType, isMe),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.black54,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe &&
                                int.tryParse(msg['id']?.toString() ?? '') !=
                                    null)
                              _buildReadReceipt(
                                int.parse(msg['id'].toString()),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.blue,
                    ),
                    onPressed: _isUploading ? null : _showAttachmentOptions,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade200,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
