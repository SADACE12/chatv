import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Подключаем Supabase!

enum MessageType { text, image, video, file }

class ChatItem {
  final String name;
  final Color avatarColor;
  final String emoji;

  ChatItem({
    required this.name,
    required this.avatarColor,
    required this.emoji,
  });
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
  final ImagePicker _picker = ImagePicker();

  // Подключаемся к базе
  final supabase = Supabase.instance.client;
  String myName = "Вы"; // Сюда подгрузится твое имя

  List<ChatItem> chats = [
    ChatItem(name: 'Илон Маск', avatarColor: Colors.orange, emoji: '🚀'),
    ChatItem(
      name: 'Команда ChatV',
      avatarColor: Colors.blueAccent,
      emoji: '🛠️',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMyName();
  }

  // Загружаем твое имя из памяти, чтобы знать, где твои сообщения, а где чужие
  Future<void> _loadMyName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        myName = prefs.getString('userName') ?? "Вы";
      });
    }
  }

  // Функция ОТПРАВКИ сообщения в базу данных
  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;

    final text = _msgController.text.trim();
    _msgController.clear(); // Очищаем поле сразу для удобства

    try {
      await supabase.from('messages').insert({
        'chat_id': selectedChat!.name, // Кому пишем (Илон Маск и т.д.)
        'sender_name': myName, // Кто пишет (Твой ник)
        'text': text, // Само сообщение
        'media_type': 'text',
      });
    } catch (e) {
      print('Ошибка при отправке в БД: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blueAccent),
            title: const Text(
              'Фотография (Локально)',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () async {
              Navigator.pop(context);
              // Заглушка: медиа файлы пока работают локально, до настройки Storage
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Для отправки медиа нужно настроить Supabase Storage!',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: selectedChat == null ? _buildList() : _buildRoom(),
    );
  }

  Widget _buildList() {
    List<ChatItem> filtered = chats.where((chat) {
      final q = _searchQuery.toLowerCase();
      return chat.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (c, i) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: filtered[i].avatarColor,
                  child: Text(filtered[i].emoji),
                ),
                title: Text(
                  filtered[i].name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  "Нажмите, чтобы открыть переписку",
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  setState(() {
                    selectedChat = filtered[i];
                    _searchQuery = "";
                    _searchController.clear();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // КОМНАТА ЧАТА: Теперь она работает с БД
  Widget _buildRoom() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text(
          selectedChat!.name,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() => selectedChat = null),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            // STREAM BUILDER - Магия реального времени!
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Слушаем таблицу messages, фильтруем по текущему чату, сортируем по времени
              stream: supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', selectedChat!.name)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                // Если загружается
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                final messages = snapshot.data!;

                // Если пусто
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Здесь пока пусто. Напишите первым!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Отрисовка списка сообщений
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe =
                        msg['sender_name'] ==
                        myName; // Проверяем, наше ли это сообщение
                    return _dbBubble(msg, isMe);
                  },
                );
              },
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
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.grey),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(), // Отправка по Enter на ПК
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blueAccent),
            onPressed: _sendMessage, // Отправка по кнопке
          ),
        ],
      ),
    );
  }

  // Отрисовка пузыря сообщения из Базы Данных
  Widget _dbBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(18),
            bottomLeft: !isMe
                ? const Radius.circular(0)
                : const Radius.circular(18),
          ),
        ),
        child: Text(
          msg['text'] ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}
