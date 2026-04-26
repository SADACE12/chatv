import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'dart:io';
import 'dart:async';
import 'dart:math' as Math; // Для анимации печатающего собеседника
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

enum MessageType { text, image, video, file, audio }

class ChatItem {
  final String id; 
  final String name;
  final Color avatarColor;
  final String emoji;

  ChatItem({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.emoji,
  });
}

class MessagesScreen extends StatefulWidget {
  final ChatItem? initialChat; 

  const MessagesScreen({super.key, this.initialChat});
  
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  ChatItem? selectedChat;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final ImagePicker _picker = ImagePicker();
  
  final supabase = Supabase.instance.client;
  User? get currentUser => supabase.auth.currentUser;
  
  String myName = "Вы"; 

  List<ChatItem> chats = [];
  bool _isLoadingChats = true; 
  bool _isUploading = false; 
  bool _isComposing = false; 

  // --- ГОЛОСОВЫЕ СООБЩЕНИЯ ---
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedAudioPath; 
  Timer? _recordTimer;
  int _recordDuration = 0; 

  Stream<List<Map<String, dynamic>>>? _messagesStream;
  Map<String, dynamic>? _replyingToMessage;

  RealtimeChannel? _chatChannel;
  bool _isPeerOnline = false;
  bool _isPeerTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadMyName();
    _loadUsers(); 

    if (widget.initialChat != null) {
      selectedChat = widget.initialChat;
      _messagesStream = supabase.from('messages').stream(primaryKey: ['id']).order('created_at', ascending: false);
      _joinChannel();
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _searchController.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose(); 
    _leaveChannel(); 
    super.dispose();
  }

  void _joinChannel() {
    if (selectedChat == null || currentUser == null) return;
    final ids = [currentUser!.id, selectedChat!.id]..sort();
    final channelName = 'room_${ids[0]}_${ids[1]}';

    _chatChannel = supabase.channel(channelName);

    _chatChannel!.onPresenceSync((payload) {
      final states = _chatChannel!.presenceState();
      bool peerFound = false;
      for (final state in states) {
        for (final presence in state.presences) {
          if (presence.payload != null && presence.payload['user_id'] == selectedChat!.id) peerFound = true;
        }
      }
      if (mounted) setState(() => _isPeerOnline = peerFound);
    }).onBroadcast(
      event: 'typing',
      callback: (payload) {
        if (payload['user_id'] == selectedChat!.id) {
          if (mounted) setState(() => _isPeerTyping = payload['typing'] ?? false);
        }
      },
    ).subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _chatChannel!.track({'user_id': currentUser!.id, 'online_at': DateTime.now().toIso8601String()});
      }
    });
  }

  void _leaveChannel() {
    if (_chatChannel != null) {
      supabase.removeChannel(_chatChannel!);
      _chatChannel = null;
    }
  }

  void _onTypingChanged() {
    if (_chatChannel == null) return;
    _chatChannel!.sendBroadcastMessage(event: 'typing', payload: {'user_id': currentUser!.id, 'typing': true});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatChannel?.sendBroadcastMessage(event: 'typing', payload: {'user_id': currentUser!.id, 'typing': false});
    });
  }

  Future<void> _loadMyName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => myName = prefs.getString('userName') ?? currentUser?.email?.split('@')[0] ?? "Вы");
  }

  Future<void> _loadUsers() async {
    if (currentUser == null) return;
    try {
      final myId = currentUser!.id;
      final Set<String> relevantUserIds = {};

      final msgData = await supabase
          .from('messages')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId');

      for (var row in msgData) {
        if (row['sender_id'] != myId) relevantUserIds.add(row['sender_id']);
        if (row['receiver_id'] != myId) relevantUserIds.add(row['receiver_id']);
      }

      try {
        final followData = await supabase.from('followers').select('following_id').eq('follower_id', myId);
        for (var row in followData) { relevantUserIds.add(row['following_id']); }
      } catch (e) {}

      if (relevantUserIds.isEmpty) {
        if (mounted) setState(() { chats = []; _isLoadingChats = false; });
        return;
      }

      final data = await supabase.from('profiles').select().filter('id', 'in', relevantUserIds.toList()); 

      if (mounted) {
        setState(() {
          chats = (data as List).map((user) => ChatItem(
              id: user['id'], name: user['username'] ?? 'Пользователь', 
              avatarColor: Colors.blueAccent, emoji: user['emoji'] ?? '👤', 
          )).toList();
          _isLoadingChats = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  Future<void> _sendMessage() async {
    final rawText = _msgController.text.trim();
    final myId = currentUser?.id;
    final peerId = selectedChat?.id;

    if (rawText.isEmpty || myId == null || peerId == null) return;

    String finalText = rawText;
    if (_replyingToMessage != null) {
      final replyText = _replyingToMessage!['text'] ?? '';
      final shortReply = replyText.length > 40 ? '${replyText.substring(0, 40)}...' : replyText;
      finalText = "↳ Ответ на: $shortReply\n\n$rawText";
    }

    _msgController.clear(); 
    setState(() {
      _replyingToMessage = null;
      _isComposing = false; 
    });

    try {
      await supabase.from('messages').insert({
        'sender_id': myId, 'receiver_id': peerId, 'sender_email': myName, 'text': finalText, 'is_read': false,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String path = '';
        if (!kIsWeb) {
          path = '${Directory.systemTemp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет доступа к микрофону')));
      }
    } catch (e) {
      print('Ошибка записи: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty) {
          _recordedAudioPath = path; 
        }
      });
    } catch (e) {
      print('Ошибка остановки записи: $e');
    }
  }

  void _cancelRecording() {
    _audioRecorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordedAudioPath = null;
      _recordDuration = 0;
    });
  }

  Future<void> _sendRecordedAudio() async {
    if (_recordedAudioPath == null) return;
    final path = _recordedAudioPath!;
    setState(() {
      _isUploading = true;
      _recordedAudioPath = null; 
    }); 

    try {
      final bytes = await XFile(path).readAsBytes();
      final myId = currentUser?.id;
      final peerId = selectedChat?.id;
      if (myId == null || peerId == null) return;

      final fileExt = kIsWeb ? 'webm' : 'm4a'; 
      final safeName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = '$myId/$safeName'; 

      await supabase.storage.from('chat_media').uploadBinary(
        storagePath, bytes, fileOptions: FileOptions(contentType: 'audio/$fileExt'),
      );

      final audioUrl = supabase.storage.from('chat_media').getPublicUrl(storagePath);

      await supabase.from('messages').insert({
        'sender_id': myId, 'receiver_id': peerId, 'sender_email': myName,
        'text': '🎤 Голосовое сообщение', 'audio_url': audioUrl, 'is_read': false,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки аудио: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false); 
    }
  }

  Future<void> _markAsRead() async {
    final myId = currentUser?.id;
    final peerId = selectedChat?.id;
    if (myId == null || peerId == null) return;
    try {
      await supabase.from('messages').update({'is_read': true}).eq('receiver_id', myId).eq('sender_id', peerId).eq('is_read', false);
    } catch (e) {}
  }

  Future<void> _sendImage() async {
    final myId = currentUser?.id;
    final peerId = selectedChat?.id;
    if (myId == null || peerId == null) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true); 

    try {
      final bytes = await image.readAsBytes();
      final mimeType = image.mimeType ?? 'image/jpeg';
      String fileExt = 'jpg';
      if (mimeType.contains('/')) fileExt = mimeType.split('/').last;
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$myId/$fileName'; 

      await supabase.storage.from('chat_media').uploadBinary(filePath, bytes, fileOptions: FileOptions(contentType: mimeType));
      final imageUrl = supabase.storage.from('chat_media').getPublicUrl(filePath);

      await supabase.from('messages').insert({
        'sender_id': myId, 'receiver_id': peerId, 'sender_email': myName,
        'text': '📷 Фотография', 'image_url': imageUrl, 'is_read': false,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false); 
    }
  }

  Future<void> _sendFile() async {
    final myId = currentUser?.id;
    final peerId = selectedChat?.id;
    if (myId == null || peerId == null) return;

    FilePickerResult? result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true); 

    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Не удалось прочитать файл');

      final fileExt = file.extension ?? '';
      final safeName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$myId/$safeName'; 

      await supabase.storage.from('chat_media').uploadBinary(filePath, bytes, fileOptions: const FileOptions(contentType: 'application/octet-stream'));
      final fileUrl = supabase.storage.from('chat_media').getPublicUrl(filePath);

      await supabase.from('messages').insert({
        'sender_id': myId, 'receiver_id': peerId, 'sender_email': myName,
        'text': '📁 Файл', 'file_url': fileUrl, 'file_name': file.name, 'is_read': false,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false); 
    }
  }

  void _showMsgMenu(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 10),
          
          ListTile(leading: const Icon(Icons.reply, color: Colors.white), title: const Text('Ответить', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); setState(() => _replyingToMessage = msg); }),
          
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white), title: const Text('Копировать текст', style: TextStyle(color: Colors.white)),
            onTap: () { Clipboard.setData(ClipboardData(text: msg['text'] ?? '')); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован'))); },
          ),
          
          ListTile(
            leading: Icon(msg['is_pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined, color: Colors.orange), 
            title: Text(msg['is_pinned'] == true ? 'Открепить' : 'Закрепить', style: const TextStyle(color: Colors.white)), 
            onTap: () async { 
              Navigator.pop(context); 
              await supabase.from('messages').update({'is_pinned': !(msg['is_pinned'] == true)}).eq('id', msg['id']); 
            }
          ),

          ListTile(
            leading: const Icon(Icons.forward, color: Colors.blueAccent), title: const Text('Переслать', style: TextStyle(color: Colors.white)), 
            onTap: () { Navigator.pop(context); _showForwardMenu(msg); }
          ),

          if (isMe && msg['text'] != '📷 Фотография' && msg['text'] != '📁 Файл' && msg['text'] != '🎤 Голосовое сообщение')
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white), title: const Text('Изменить', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _editMessageDialog(msg); },
            ),

          if (isMe) 
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent), title: const Text('Удалить у всех', style: TextStyle(color: Colors.redAccent)),
              onTap: () async { Navigator.pop(context); try { await supabase.from('messages').delete().eq('id', msg['id']); } catch (e) {} },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _editMessageDialog(Map<String, dynamic> msg) {
    TextEditingController editController = TextEditingController(text: msg['text']);
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Изменить сообщение', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFF333333), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              if (editController.text.trim().isNotEmpty && editController.text != msg['text']) {
                await supabase.from('messages').update({'text': editController.text.trim(), 'is_edited': true}).eq('id', msg['id']);
              }
            }, 
            child: const Text('Сохранить', style: TextStyle(color: Colors.white))
          )
        ],
      )
    );
  }

  void _showForwardMenu(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Переслать в...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (ctx, i) => ListTile(
                leading: CircleAvatar(backgroundColor: chats[i].avatarColor.withOpacity(0.2), child: Text(chats[i].emoji)),
                title: Text(chats[i].name, style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await supabase.from('messages').insert({
                    'sender_id': currentUser!.id, 'receiver_id': chats[i].id, 'sender_email': myName,
                    'text': 'Пересланное сообщение:\n${msg['text']}', 'is_read': false,
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Переслано в ${chats[i].name}')));
                }
              )
            )
          )
        ]
      )
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(leading: const Icon(Icons.image, color: Colors.blueAccent), title: const Text('Фотография', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _sendImage(); }),
          ListTile(leading: const Icon(Icons.description, color: Colors.orange), title: const Text('Документ', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _sendFile(); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black, child: selectedChat == null ? _buildList() : _buildRoom());
  }

  Widget _buildList() {
    List<ChatItem> filtered = chats.where((chat) => chat.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController, onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: 'Поиск...', prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
            ),
          ),
          Expanded(
            child: _isLoadingChats 
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : chats.isEmpty 
                  ? const Center(child: Text("Нет доступных чатов.\nПодпишитесь на кого-то!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: CircleAvatar(backgroundColor: filtered[i].avatarColor.withOpacity(0.2), child: Text(filtered[i].emoji, style: const TextStyle(fontSize: 18))),
                        title: Text(filtered[i].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onTap: () {
                          setState(() {
                            selectedChat = filtered[i]; _searchQuery = ""; _searchController.clear();
                            _messagesStream = supabase.from('messages').stream(primaryKey: ['id']).order('created_at', ascending: false);
                            _joinChannel(); 
                          });
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedBanner(Map<String, dynamic> msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A), 
        border: Border(bottom: BorderSide(color: Colors.white10))
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Закреплённое сообщение', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  msg['text']?.replaceAll('\n', ' ') ?? 'Файл/Изображение', 
                  maxLines: 1, overflow: TextOverflow.ellipsis, 
                  style: const TextStyle(color: Colors.white70, fontSize: 14)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoom() {
    final myId = currentUser?.id;
    final peerId = selectedChat?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Row(
          children: [
            CircleAvatar(radius: 16, backgroundColor: selectedChat!.avatarColor.withOpacity(0.2), child: Text(selectedChat!.emoji, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedChat!.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(_isPeerTyping ? 'печатает...' : (_isPeerOnline ? 'в сети' : 'был(а) недавно'), style: TextStyle(color: _isPeerTyping || _isPeerOnline ? Colors.blueAccent : Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () {
          _leaveChannel(); 
          if (widget.initialChat != null) {
            Navigator.pop(context); 
          } else {
            setState(() { selectedChat = null; _messagesStream = null; _replyingToMessage = null; }); 
          }
        }),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                
                final chatMessages = snapshot.data!.where((m) {
                  return (m['sender_id'] == myId && m['receiver_id'] == peerId) || (m['sender_id'] == peerId && m['receiver_id'] == myId);
                }).toList();

                final unreadMessages = chatMessages.where((m) => m['receiver_id'] == myId && m['is_read'] == false).toList();
                if (unreadMessages.isNotEmpty) Future.microtask(() => _markAsRead());

                final pinnedMessages = chatMessages.where((m) => m['is_pinned'] == true).toList();
                final latestPinned = pinnedMessages.isNotEmpty ? pinnedMessages.first : null;

                return Column(
                  children: [
                    if (latestPinned != null) _buildPinnedBanner(latestPinned),
                    Expanded(
                      child: ListView.builder(
                        reverse: true, padding: const EdgeInsets.all(16), 
                        itemCount: chatMessages.length + (_isPeerTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isPeerTyping && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Align(alignment: Alignment.centerLeft, child: TypingIndicator()),
                            );
                          }
                          
                          final msg = chatMessages[_isPeerTyping ? index - 1 : index];
                          
                          return GestureDetector(
                            onTap: () => _showMsgMenu(msg, msg['sender_id'] == myId), 
                            child: _dbBubble(msg, msg['sender_id'] == myId),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Colors.blueAccent, size: 20), const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ответ', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(_replyingToMessage!['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => setState(() => _replyingToMessage = null)),
                ],
              ),
            ),
          
          _input(),
        ],
      ),
    );
  }

  String _formatTimer(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Widget _input() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isRecording && _recordedAudioPath == null)
            _isUploading 
              ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)))
              : IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () => _showAttachmentOptions()),
          
          Expanded(
            child: _isRecording 
              ? Container(
                  height: 48, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      const RecordingMicIndicator(isRecording: true), 
                      const SizedBox(width: 10),
                      Text(_formatTimer(_recordDuration), style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const Spacer(),
                      TextButton(onPressed: _cancelRecording, child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
                      IconButton(icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 30), onPressed: _stopRecording, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                )
              : _recordedAudioPath != null 
                ? Container( 
                    height: 48, padding: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      children: [
                        Expanded(child: AudioBubble(url: _recordedAudioPath!, isMe: true, isPreview: true)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                          onPressed: _cancelRecording,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  )
                : TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4, minLines: 1, 
                    onChanged: (text) {
                      _onTypingChanged(); 
                      setState(() => _isComposing = text.isNotEmpty); 
                    }, 
                    decoration: InputDecoration(
                      hintText: 'Сообщение...', hintStyle: const TextStyle(color: Colors.grey),
                      filled: true, fillColor: const Color(0xFF1E1E1E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(), 
                  ),
          ),
          const SizedBox(width: 8),
          
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: (_isComposing || _recordedAudioPath != null) ? Colors.blueAccent : Colors.transparent, 
              shape: BoxShape.circle
            ),
            child: (_isComposing || _recordedAudioPath != null)
              ? IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20), 
                  onPressed: _recordedAudioPath != null ? _sendRecordedAudio : _sendMessage
                )
              : IconButton(
                  icon: const Icon(Icons.mic_none, color: Colors.grey, size: 28),
                  onPressed: _startRecording, 
                ),
          ),
        ],
      ),
    );
  }

  Widget _dbBubble(Map<String, dynamic> msg, bool isMe) {
    final time = DateTime.parse(msg['created_at']).toLocal();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final text = msg['text'] as String? ?? '';
    final isReply = text.startsWith('↳ Ответ на:');
    final imageUrl = msg['image_url'] as String?;
    final fileUrl = msg['file_url'] as String?;
    final fileName = msg['file_name'] as String?;
    final audioUrl = msg['audio_url'] as String?; 
    final bool isRead = msg['is_read'] == true;
    final bool isPinned = msg['is_pinned'] == true;
    final bool isEdited = msg['is_edited'] == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent.shade700 : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isPinned ? Border.all(color: Colors.orange, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(msg['sender_email'] ?? 'Аноним', style: TextStyle(color: Colors.blueAccent.shade100, fontSize: 13, fontWeight: FontWeight.bold))),
            if (isReply) ...[
              Container(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4), margin: const EdgeInsets.only(bottom: 8), 
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.white54, width: 3))), 
                child: Text(text.split('\n\n').first, style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic))
              ),
              Text(text.split('\n\n').length > 1 ? text.split('\n\n').sublist(1).join('\n\n') : '', style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3)),
            ] else ...[
              
              if (imageUrl != null && imageUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl))),
              
              if (fileUrl != null && fileUrl.isNotEmpty) GestureDetector(
                onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ссылка: $fileUrl'), duration: const Duration(seconds: 4))); },
                child: Container(
                  padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file, color: Colors.white70, size: 28), const SizedBox(width: 10), Flexible(child: Text(fileName ?? 'Документ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1))]),
                ),
              ),

              if (audioUrl != null && audioUrl.isNotEmpty)
                AudioBubble(url: audioUrl, isMe: isMe),
              
              if (text.isNotEmpty && text != '📷 Фотография' && text != '📁 Файл' && text != '🎤 Голосовое сообщение')
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.2)),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight, 
              child: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  if (isEdited) const Text('изм. ', style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                  Text(timeStr, style: TextStyle(color: isMe ? Colors.white70 : Colors.white54, fontSize: 11)),
                  if (isMe) ...[const SizedBox(width: 4), Icon(isRead ? Icons.done_all : Icons.check, size: 14, color: isRead ? Colors.white : Colors.white70)]
                ]
              )
            ),
          ],
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}
class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double val = Math.sin((_controller.value * 2 * 3.14159) - (index * 1.0));
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6, height: 6 + (val > 0 ? val * 4 : 0),
                decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
              );
            },
          );
        }),
      ),
    );
  }
}

class RecordingMicIndicator extends StatefulWidget {
  final bool isRecording;
  const RecordingMicIndicator({super.key, required this.isRecording});
  @override
  State<RecordingMicIndicator> createState() => _RecordingMicIndicatorState();
}
class _RecordingMicIndicatorState extends State<RecordingMicIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800), lowerBound: 0.8, upperBound: 1.2);
    if (widget.isRecording) _controller.repeat(reverse: true);
  }
  @override
  void didUpdateWidget(RecordingMicIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) _controller.repeat(reverse: true);
    else if (!widget.isRecording && oldWidget.isRecording) { _controller.stop(); _controller.value = 1.0; }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: const Icon(Icons.mic, color: Colors.redAccent, size: 24),
    );
  }
}

class AudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  final bool isPreview; 
  const AudioBubble({super.key, required this.url, required this.isMe, this.isPreview = false});

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
      margin: widget.isPreview ? EdgeInsets.zero : const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: widget.isPreview ? Colors.transparent : (widget.isMe ? Colors.blueAccent.shade700 : const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 36),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                if (widget.url.startsWith('http')) {
                  await _audioPlayer.play(UrlSource(widget.url));
                } else {
                  await _audioPlayer.play(DeviceFileSource(widget.url));
                }
              }
            }
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
                min: 0,
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0),
                onChanged: (value) async {
                  await _audioPlayer.seek(Duration(seconds: value.toInt()));
                }
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(_position.inSeconds > 0 ? _position : _duration), 
            style: const TextStyle(color: Colors.white70, fontSize: 12)
          ),
        ],
      ),
    );
  }
}