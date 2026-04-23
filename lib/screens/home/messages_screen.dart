import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'dart:io';
import 'dart:async';
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

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;

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
        final followData = await supabase
            .from('followers')
            .select('following_id')
            .eq('follower_id', myId);
            
        for (var row in followData) {
          relevantUserIds.add(row['following_id']);
        }
      } catch (e) {}

      if (relevantUserIds.isEmpty) {
        if (mounted) {
          setState(() {
            chats = [];
            _isLoadingChats = false;
          });
        }
        return;
      }

      final data = await supabase
          .from('profiles')
          .select()
          .filter('id', 'in', relevantUserIds.toList()); 

      if (mounted) {
        setState(() {
          chats = (data as List).map((user) => ChatItem(
              id: user['id'], 
              name: user['username'] ?? 'Пользователь', 
              avatarColor: Colors.blueAccent, 
              emoji: user['emoji'] ?? '👤', 
          )).toList();
          _isLoadingChats = false; 
        });
      }
    } catch (e) {
      print('Ошибка при загрузке списка чатов: $e');
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
        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет доступа к микрофону')));
      }
    } catch (e) {
      print('Ошибка записи: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        await _uploadAndSendAudio(path);
      }
    } catch (e) {
      print('Ошибка остановки записи: $e');
    }
  }

  Future<void> _uploadAndSendAudio(String path) async {
    setState(() => _isUploading = true); 
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
          ListTile(leading: const Icon(Icons.reply, color: Colors.white), title: const Text('Ответить', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); setState(() => _replyingToMessage = msg); }),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.white), title: const Text('Копировать текст', style: TextStyle(color: Colors.white)),
            onTap: () { Clipboard.setData(ClipboardData(text: msg['text'] ?? '')); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Текст скопирован'))); },
          ),
          if (isMe) ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent), title: const Text('Удалить у всех', style: TextStyle(color: Colors.white)),
              onTap: () async { Navigator.pop(context); try { await supabase.from('messages').delete().eq('id', msg['id']); } catch (e) {} },
            ),
          const SizedBox(height: 20),
        ],
      ),
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

                return ListView.builder(
                  reverse: true, padding: const EdgeInsets.all(16), itemCount: chatMessages.length,
                  itemBuilder: (context, index) {
                    final msg = chatMessages[index];
                    return GestureDetector(
                      onLongPress: () => _showMsgMenu(msg, msg['sender_id'] == myId),
                      child: _dbBubble(msg, msg['sender_id'] == myId),
                    );
                  },
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

  Widget _input() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: const Color(0xFF121212),
      child: Row(
        children: [
          _isUploading 
            ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)))
            : IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () => _showAttachmentOptions()),
          
          Expanded(
            child: _isRecording 
              ? Container(
                  height: 48, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: const [
                      Icon(Icons.mic, color: Colors.redAccent, size: 18), SizedBox(width: 10),
                      Text('Запись...', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (text) {
                    _onTypingChanged(); 
                    setState(() => _isComposing = text.isNotEmpty); 
                  }, 
                  decoration: InputDecoration(
                    hintText: 'Сообщение...', hintStyle: const TextStyle(color: Colors.grey),
                    filled: true, fillColor: const Color(0xFF1E1E1E),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendMessage(), 
                ),
          ),
          const SizedBox(width: 8),
          
          _isComposing
            ? Container(
                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
              )
            : GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopAndSendRecording(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _isRecording ? Colors.redAccent : Colors.blueAccent, shape: BoxShape.circle),
                  child: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: Colors.white, size: 22),
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(msg['sender_email'] ?? 'Аноним', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))),
            if (isReply) ...[
              Container(padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4), margin: const EdgeInsets.only(bottom: 8), decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.white54, width: 3))), child: Text(text.split('\n\n').first, style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic))),
              Text(text.split('\n\n').length > 1 ? text.split('\n\n').sublist(1).join('\n\n') : '', style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3)),
            ] else ...[
              
              if (imageUrl != null && imageUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl))),
              
              if (fileUrl != null && fileUrl.isNotEmpty) GestureDetector(
                onTap: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ссылка: $fileUrl\n(Для скачивания установите url_launcher)'), duration: const Duration(seconds: 4))); },
                child: Container(
                  padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file, color: Colors.white70, size: 28), const SizedBox(width: 10), Flexible(child: Text(fileName ?? 'Документ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1))]),
                ),
              ),

              if (audioUrl != null && audioUrl.isNotEmpty)
                AudioBubble(url: audioUrl, isMe: isMe),
              
              if (text.isNotEmpty && text != '📷 Фотография' && text != '📁 Файл' && text != '🎤 Голосовое сообщение')
                Text(text, style: const TextStyle(color: Colors.white)),
            ],
            const SizedBox(height: 4),
            Align(alignment: Alignment.bottomRight, child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(timeStr, style: const TextStyle(color: Colors.white60, fontSize: 10)),
              if (isMe) ...[const SizedBox(width: 4), Icon(isRead ? Icons.done_all : Icons.check, size: 14, color: isRead ? Colors.white : Colors.white60)]
            ])),
          ],
        ),
      ),
    );
  }
}

class AudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const AudioBubble({super.key, required this.url, required this.isMe});

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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 36),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.url));
              }
            }
          ),
          SizedBox(
            width: 120, 
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