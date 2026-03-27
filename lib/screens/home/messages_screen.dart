import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import '../../theme/app_colors.dart';

enum MessageType { text, image, video, file }

class ChatMessage {
  final String text; final bool isMe; final String time;
  final MessageType type; final String? filePath; final String? fileName;
  ChatMessage({required this.text, required this.isMe, required this.time, this.type = MessageType.text, this.filePath, this.fileName});
}

class ChatItem {
  final String name; final Color avatarColor; final String emoji; List<ChatMessage> messages;
  ChatItem({required this.name, required this.avatarColor, required this.emoji, required this.messages});
  String get lastMessage => messages.isNotEmpty ? messages.last.text : "Нет сообщений";
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  ChatItem? selectedChat;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  List<ChatItem> chats = [
    ChatItem(name: 'Илон Маск', avatarColor: Colors.orange, emoji: '🚀', messages: [ChatMessage(text: 'Привет! Жду инвайт 😎', isMe: false, time: 'Вчера')]),
    ChatItem(name: 'Команда ChatV', avatarColor: Colors.blueAccent, emoji: '🛠️', messages: [ChatMessage(text: 'Добро пожаловать!', isMe: false, time: '10:00')]),
  ];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && selectedChat != null) {
      PlatformFile file = result.files.first;
      MessageType type = MessageType.file;
      String ext = file.extension?.toLowerCase() ?? '';
      if (['jpg', 'png', 'jpeg'].contains(ext)) type = MessageType.image;
      
      setState(() {
        selectedChat!.messages.add(ChatMessage(
          text: file.name, isMe: true, time: '10:00', type: type, 
          filePath: kIsWeb ? null : file.path, fileName: file.name
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return selectedChat == null ? _buildList() : _buildRoom();
  }

  Widget _buildList() {
    List<ChatItem> filtered = chats.where((chat) {
      final q = _searchQuery.toLowerCase();
      return chat.name.toLowerCase().contains(q) || chat.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController, 
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Поиск...', 
                prefixIcon: Icon(Icons.search, color: AppColors.textSub), 
                filled: true, fillColor: AppColors.input, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (c, i) => ListTile(
                leading: CircleAvatar(backgroundColor: filtered[i].avatarColor, child: Text(filtered[i].emoji)),
                title: Text(filtered[i].name, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                subtitle: Text(filtered[i].lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSub)),
                onTap: () { setState(() { selectedChat = filtered[i]; _searchQuery = ""; _searchController.clear(); }); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoom() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.sidebar, title: Text(selectedChat!.name, style: TextStyle(color: AppColors.text)), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => selectedChat = null))),
      body: Column(children: [Expanded(child: ListView.builder(itemCount: selectedChat!.messages.length, itemBuilder: (c, i) => _bubble(selectedChat!.messages[i]))), _input()]),
    );
  }

  Widget _input() {
    return Container(
      padding: const EdgeInsets.all(10), color: AppColors.sidebar,
      child: Row(children: [
        IconButton(icon: Icon(Icons.attach_file, color: AppColors.textSub), onPressed: _pickFile),
        Expanded(child: TextField(controller: _msgController, style: TextStyle(color: AppColors.text), decoration: InputDecoration(hintText: 'Сообщение...', filled: true, fillColor: AppColors.input, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
        IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: () {
          if (_msgController.text.isEmpty) return;
          setState(() { selectedChat!.messages.add(ChatMessage(text: _msgController.text, isMe: true, time: 'Только что')); _msgController.clear(); });
        }),
      ]),
    );
  }

  Widget _bubble(ChatMessage m) {
    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: m.isMe ? Colors.blueAccent : AppColors.card, borderRadius: BorderRadius.circular(15)),
        child: m.type == MessageType.image && m.filePath != null && !kIsWeb 
          ? Image.file(File(m.filePath!), width: 150) 
          : Text(m.text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}