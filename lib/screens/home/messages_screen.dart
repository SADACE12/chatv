import 'package:flutter/material.dart';
import '../../theme/app_colors.dart'; // ПОДКЛЮЧИЛИ ЦВЕТА

// --- МОДЕЛИ ДАННЫХ ДЛЯ ЧАТА ---
class ChatMessage {
  final String text;
  final bool isMe; 
  final String time;

  ChatMessage({required this.text, required this.isMe, required this.time});
}

class ChatItem {
  final String name;
  final Color avatarColor;
  final String emoji;
  int unreadCount;
  List<ChatMessage> messages;

  ChatItem({
    required this.name,
    required this.avatarColor,
    required this.emoji,
    this.unreadCount = 0,
    required this.messages,
  });

  String get lastMessage => messages.isNotEmpty ? messages.last.text : "Нет сообщений";
  String get lastTime => messages.isNotEmpty ? messages.last.time : "";
}

// --- САМ ЭКРАН СООБЩЕНИЙ ---
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
    ChatItem(
      name: 'Команда ChatV',
      avatarColor: Colors.blueAccent,
      emoji: '🛠️',
      unreadCount: 1,
      messages: [
        ChatMessage(text: 'Добро пожаловать в ChatV!', isMe: false, time: '10:00'),
        ChatMessage(text: 'Мы рады, что вы с нами. Если найдете баги - пишите сюда.', isMe: false, time: '10:01'),
      ],
    ),
    ChatItem(
      name: 'Илон Маск',
      avatarColor: Colors.orange,
      emoji: '🚀',
      messages: [
        ChatMessage(text: 'Привет! Как там твой новый проект на Flutter?', isMe: false, time: 'Вчера'),
        ChatMessage(text: 'Всё супер, скоро запускаем соцсеть!', isMe: true, time: 'Вчера'),
        ChatMessage(text: 'Жду инвайт 😎', isMe: false, time: 'Вчера'),
      ],
    ),
    ChatItem(
      name: 'Клан Огня',
      avatarColor: Colors.redAccent,
      emoji: '🔥',
      messages: [
        ChatMessage(text: 'Кто сегодня вечером в игру?', isMe: false, time: 'Среда'),
      ],
    ),
  ];

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty || selectedChat == null) return;
    
    setState(() {
      selectedChat!.messages.add(
        ChatMessage(
          text: _msgController.text,
          isMe: true,
          time: 'Только что',
        ),
      );
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем изменение темы
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: selectedChat == null ? _buildChatList() : _buildChatRoom(),
        );
      }
    );
  }

  Widget _buildChatList() {
    List<ChatItem> filteredChats = chats.where((chat) {
      final query = _searchQuery.toLowerCase();
      final matchesName = chat.name.toLowerCase().contains(query);
      final matchesMessage = chat.messages.any((msg) => msg.text.toLowerCase().contains(query));
      return matchesName || matchesMessage;
    }).toList();

    return Scaffold(
      key: const ValueKey('ChatList'),
      backgroundColor: AppColors.bg, // ДИНАМИЧЕСКИЙ ФОН
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Новый чат в разработке')),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            child: Text('Сообщения', style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.text),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Поиск сообщений...',
                hintStyle: TextStyle(color: AppColors.textSub),
                prefixIcon: Icon(Icons.search, color: AppColors.textSub),
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: filteredChats.isEmpty 
              ? Center(child: Text('Ничего не найдено', style: TextStyle(color: AppColors.textSub)))
              : ListView.builder(
              itemCount: filteredChats.length,
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                String displaySubtitle = chat.lastMessage;
                
                if (_searchQuery.isNotEmpty) {
                  try {
                    final matchedMsg = chat.messages.lastWhere((msg) => msg.text.toLowerCase().contains(_searchQuery.toLowerCase()));
                    displaySubtitle = matchedMsg.text;
                  } catch (_) {}
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(radius: 25, backgroundColor: chat.avatarColor, child: Text(chat.emoji, style: const TextStyle(fontSize: 24))),
                      if (chat.unreadCount > 0)
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                            child: Text('${chat.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                  title: Text(chat.name, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  subtitle: Text(displaySubtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: chat.unreadCount > 0 ? AppColors.text : AppColors.textSub)),
                  trailing: Text(chat.lastTime, style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                  onTap: () {
                    setState(() {
                      chat.unreadCount = 0; 
                      selectedChat = chat; 
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoom() {
    return Scaffold(
      key: const ValueKey('ChatRoom'),
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.text), onPressed: () => setState(() => selectedChat = null)),
                CircleAvatar(radius: 18, backgroundColor: selectedChat!.avatarColor, child: Text(selectedChat!.emoji, style: const TextStyle(fontSize: 18))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selectedChat!.name, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Был(а) недавно', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.more_vert, color: AppColors.textSub), onPressed: () {}),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: selectedChat!.messages.length,
              itemBuilder: (context, index) {
                final msg = selectedChat!.messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.attach_file, color: AppColors.textSub), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: TextStyle(color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: 'Написать сообщение...',
                      hintStyle: TextStyle(color: AppColors.textSub),
                      filled: true,
                      fillColor: AppColors.input,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(), 
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 22,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6), 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isMe ? Colors.blueAccent : AppColors.card,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: msg.isMe ? const Radius.circular(5) : const Radius.circular(20),
            bottomLeft: !msg.isMe ? const Radius.circular(5) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Текст: если синий фон - белый текст, иначе цвет темы
            Text(msg.text, style: TextStyle(color: msg.isMe ? Colors.white : AppColors.text, fontSize: 15)),
            const SizedBox(height: 4),
            Text(msg.time, style: TextStyle(color: msg.isMe ? Colors.white70 : AppColors.textSub, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}