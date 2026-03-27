import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../models/post_model.dart';
import '../auth/login_screen.dart';
import '../../data/app_data.dart';
import '../../theme/app_colors.dart'; 
import 'profile_screen.dart';
import 'messages_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<Post> posts = [];
  int _currentIndex = 1; 
  XFile? _pickedFile; 

  bool _isCreatingPoll = false;
  List<TextEditingController> _pollControllers = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonPosts = prefs.getStringList('saved_posts_json');

    if (jsonPosts != null) {
      setState(() {
        posts = jsonPosts.map((jsonStr) {
          final map = jsonDecode(jsonStr);
          return Post(
            username: 'Вы',
            avatarColor: Colors.orange,
            timeAgo: 'ранее',
            text: map['text'] ?? '',
            imagePath: map['imagePath'],
            pollOptions: map['pollOptions'] != null ? List<String>.from(map['pollOptions']) : null,
            likesCount: map['likesCount'] ?? 0,
            isLiked: map['isLiked'] ?? false,
            comments: map['comments'] != null ? List<String>.from(map['comments']) : [],
          );
        }).toList();
      });
    }
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonPosts = posts.map((p) => jsonEncode({
      'text': p.text,
      'imagePath': p.imagePath,
      'pollOptions': p.pollOptions,
      'likesCount': p.likesCount,
      'isLiked': p.isLiked,
      'comments': p.comments,
    })).toList();
    await prefs.setStringList('saved_posts_json', jsonPosts);
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Удалить запись?', style: TextStyle(color: AppColors.text)),
        content: Text('Это действие нельзя отменить.', style: TextStyle(color: AppColors.textSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: AppColors.textSub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                posts.removeAt(index);
                _savePosts();
              });
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  void _editPost(int index) {
    TextEditingController editController = TextEditingController(text: posts[index].text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Редактировать', style: TextStyle(color: AppColors.text)),
          content: TextField(
            controller: editController,
            style: TextStyle(color: AppColors.text),
            decoration: InputDecoration(hintText: 'Текст записи...', hintStyle: TextStyle(color: AppColors.textSub)),
            maxLines: null,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: AppColors.textSub))),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  posts[index].text = editController.text;
                  _savePosts();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText),
              child: const Text('Сохранить'),
            ),
          ],
        );
      }
    );
  }

  void _toggleLike(int index) {
    setState(() {
      posts[index].isLiked = !posts[index].isLiked;
      posts[index].isLiked ? posts[index].likesCount++ : posts[index].likesCount--;
      _savePosts();
    });
  }

  void _showComments(int index) {
    TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true, 
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                height: 400,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Комментарии', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                    Divider(color: AppColors.border, height: 20),
                    Expanded(
                      child: posts[index].comments.isEmpty
                          ? Center(child: Text('Пока нет комментариев', style: TextStyle(color: AppColors.textSub)))
                          : ListView.builder(
                              itemCount: posts[index].comments.length,
                              itemBuilder: (c, i) => ListTile(
                                leading: const CircleAvatar(radius: 16, backgroundColor: Colors.orange, child: Icon(Icons.person, size: 16, color: Colors.white)),
                                title: Text('Вы', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: Text(posts[index].comments[i], style: TextStyle(color: AppColors.text)),
                              ),
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: TextStyle(color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: 'Написать комментарий...',
                              hintStyle: TextStyle(color: AppColors.textSub),
                              filled: true,
                              fillColor: AppColors.input,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blueAccent),
                          onPressed: () {
                            if (commentController.text.trim().isNotEmpty) {
                              setState(() {
                                posts[index].comments.add(commentController.text.trim());
                                _savePosts();
                              });
                              setSheetState(() {}); 
                              commentController.clear();
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
              );
            }
          ),
        );
      }
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _pickedFile = image);
  }

  void _showEmojiPicker() {
    final Map<String, List<String>> emojiCategories = {
      'Смайлы': ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '😉', '😍', '🥰', '😘', '😋', '😎', '🤩', '🥳', '😏', '😭', '😤', '😡', '🤯', '😱', '🤔', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '🤯'],
      'Жесты': ['👋', '🤚', '🖐️', '✋', '🖖', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝', '🙏', '✍️', '💅', '🤳', '💪'],
      'Природа': ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐒', '🦍', '🦧', '🐔', '🐧', '🐦', '🐤', '🦉', '🐺', '🐗', '🐴', '🦄', '🐝', '🦋', '🐌', '🐞', '🐜', '🦟', '🐢', '🐍', '🦖', '🦕', '🐙', '🦀', '🐡', '🐠', '🐬', '🐳', '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🐘', '🦛', '🦒', '🦘', '🐒'],
      'Еда': ['🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬', '🥒', '🌽', '🥕', '🥔', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳', '🥓', '🥩', '🍗', '🍖', '🌭', '🍔', '🍟', '🍕', '🥪', '🌮', '🌯', '🥘', '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🍤', '🍘', '🍥', '🥠', '🍰', '🎂', '🥧', '🧁', '🍮', '🍭', '🍬', '🍫', '🍿', '🍩', '🍪', '🍯', '🥛', '☕', '🍵', '🥤', '🍶', '🍺', '🍻', '🥂', '🍷', '🥃', '🍸', '🍹', '🧉', '🍾', '🧊'],
      'Объекты': ['⌚', '📱', '📲', '💻', '⌨️', '🖱️', '🖲️', '🕹️', '🗜️', '💽', '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥', '📽️', '🎞️', '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️', '🎛️', '🧭', '⏱️', '⏲️', '⏰', '🕰️', '⌛', '⏳', '📡', '🔋', '🔌', '💡', '🔦', '🕯️', '🪔', '🧯', '🛢️', '💸', '💵', '💴', '💶', '💷', '💰', '💳', '💎', '⚖️', '🧰', '🔧', '🔨', '⚒️', '🛠️', '⛏️', '🔩', '⚙️', '🧱', '⛓️', '🧲', '🔫', '💣', '🧨', '🪓', '🔪', '🗡️', '⚔️', '🛡️', '🚬', '⚰️', '⚱️', '🏺', '🔮', '📿', '🧿', '💈', '⚗️', '🔭', '🔬', '🕳️', '🩹', '🩺', '💊', '💉', '🩸', '🧬', '🌡️', '🧹', '🧺', '🧻', '🚽', '🚰', '🚿', '🛁', '🛀', '🧼', '🪒', '🧴', '🧷', '🧹', '🧺'],
    };

    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: emojiCategories.length,
          child: Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SizedBox(
              width: 500,
              height: 450,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('Выбрать эмодзи', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  TabBar(
                    isScrollable: true,
                    indicatorColor: Colors.blueAccent,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    unselectedLabelColor: AppColors.textSub,
                    tabs: emojiCategories.keys.map((name) => Tab(text: name)).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: emojiCategories.values.map((emojis) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 15, crossAxisSpacing: 15),
                          itemCount: emojis.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                setState(() => _postController.text += emojis[index]);
                                Navigator.pop(context);
                              },
                              child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 28))),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _publishPost() {
    String text = _postController.text.trim();
    if (_isCreatingPoll && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите вопрос для вашего опроса!')));
      return;
    }
    List<String> currentPollOptions = _pollControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (_isCreatingPoll && currentPollOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавьте минимум 2 варианта ответа!')));
      return;
    }
    if (text.isEmpty && _pickedFile == null && currentPollOptions.isEmpty) return;
    
    setState(() {
      posts.insert(0, Post(
        username: 'Вы',
        avatarColor: Colors.orange,
        timeAgo: 'только что',
        text: text,
        imagePath: _pickedFile?.path,
        pollOptions: _isCreatingPoll ? currentPollOptions : null,
      ));
      _postController.clear();
      _pickedFile = null;
      _isCreatingPoll = false;
      _pollControllers = [TextEditingController(), TextEditingController()];
      _savePosts();
      FocusScope.of(context).unfocus();
    });
  }

  Widget _buildCenterContent() {
    if (_currentIndex == 0) return ProfileScreen();
    if (_currentIndex == 1) return _buildFeed();
    if (_currentIndex == 2) return MessagesScreen();
    return Center(child: Text('В разработке', style: TextStyle(color: AppColors.textSub)));
  }

  int _getBottomNavIndex() {
    if (_currentIndex == 1) return 0; 
    if (_currentIndex == 2) return 2; 
    if (_currentIndex == 0) return 3; 
    return 1; 
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          
          // --- ОБНОВЛЕННЫЙ APPBAR ДЛЯ МОБИЛЬНОЙ ВЕРСИИ ---
          appBar: isMobile ? AppBar(
            title: const Text('ChatV', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            backgroundColor: AppColors.sidebar,
            elevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false, 
            actions: [
              // ДОБАВЛЕНА КНОПКА ТЕМЫ В МОБИЛЬНУЮ ВЕРСИЮ
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.text),
                onPressed: () => AppColors.toggleTheme(),
              ),
              const SizedBox(width: 8),
            ],
          ) : null,
          
          body: Row(
            children: [
              if (!isMobile) Expanded(flex: 2, child: LeftSidebarContent(activeIdx: _currentIndex, onSelect: (idx) => setState(() => _currentIndex = idx))),
              Expanded(
                flex: 5,
                child: Container(
                  color: AppColors.bg,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: isMobile ? screenWidth : 700, 
                      child: _buildCenterContent(), 
                    ),
                  ),
                ),
              ),
              if (screenWidth > 1200) Expanded(flex: 2, child: RightSidebarContent()),
            ],
          ),
          
          bottomNavigationBar: isMobile ? BottomNavigationBar(
            backgroundColor: AppColors.sidebar,
            selectedItemColor: AppColors.text,
            unselectedItemColor: AppColors.textSub,
            currentIndex: _getBottomNavIndex(), 
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: (idx) {
              if (idx == 0) setState(() => _currentIndex = 1); 
              if (idx == 1) setState(() => _currentIndex = 3); 
              if (idx == 2) setState(() => _currentIndex = 2); 
              if (idx == 3) setState(() => _currentIndex = 0); 
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: ''),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
              BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: ''), 
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
            ],
          ) : null,
        );
      }
    );
  }

  Widget _buildFeed() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        TopTabs(),
        const SizedBox(height: 16),
        ClanEmojisPanel(),
        _buildCreatePostField(),
        const SizedBox(height: 16),
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('Здесь пока пусто!', style: TextStyle(color: AppColors.textSub))),
          )
        else
          ...posts.asMap().entries.map((entry) {
            int index = entry.key;
            Post post = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                onEdit: () => _editPost(index),
                onDelete: () => _deletePost(index),
                onLike: () => _toggleLike(index),
                onComment: () => _showComments(index),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCreatePostField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(backgroundColor: Colors.orange, radius: 18, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _postController,
                      maxLines: null,
                      style: TextStyle(fontSize: 16, color: AppColors.text),
                      decoration: InputDecoration(hintText: _isCreatingPoll ? 'Задайте вопрос...' : 'Что нового?', hintStyle: TextStyle(color: AppColors.textSub), border: InputBorder.none),
                    ),
                    if (_pickedFile != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb ? Image.network(_pickedFile!.path, height: 150, width: double.infinity, fit: BoxFit.cover) : Image.file(File(_pickedFile!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _pickedFile = null),
                                child: const CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 16, color: Colors.white)),
                              ),
                            )
                          ],
                        ),
                      ),
                    if (_isCreatingPoll)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...List.generate(_pollControllers.length, (index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: _pollControllers[index],
                                  style: TextStyle(color: AppColors.text, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Вариант ${index + 1}',
                                    hintStyle: TextStyle(color: AppColors.textSub),
                                    filled: true,
                                    fillColor: AppColors.input,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              );
                            }),
                            if (_pollControllers.length < 5)
                              TextButton(onPressed: () => setState(() => _pollControllers.add(TextEditingController())), style: TextButton.styleFrom(foregroundColor: Colors.blueAccent), child: const Text('+ Добавить вариант'))
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: AppColors.border, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(onPressed: _pickImage, icon: Icon(Icons.image_outlined, color: AppColors.textSub, size: 22)),
                  IconButton(onPressed: _showEmojiPicker, icon: Icon(Icons.emoji_emotions_outlined, color: AppColors.textSub, size: 22)),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isCreatingPoll = !_isCreatingPoll;
                        if (!_isCreatingPoll) _pollControllers = [TextEditingController(), TextEditingController()];
                      });
                    }, 
                    icon: Icon(Icons.poll_outlined, color: _isCreatingPoll ? Colors.blueAccent : AppColors.textSub, size: 22)
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('Опубликовать', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const PostCard({
    super.key, 
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
    required this.onComment,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int? selectedPollIndex; 

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: widget.post.avatarColor, radius: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(widget.post.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text)),
                  Text(widget.post.timeAgo, style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                ]
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: AppColors.textSub),
                color: AppColors.input,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') widget.onEdit();
                  if (value == 'delete') widget.onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать', style: TextStyle(color: AppColors.text))),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
          if (widget.post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(widget.post.text, style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.text, fontWeight: widget.post.pollOptions != null ? FontWeight.bold : FontWeight.normal)),
            ),
          if (widget.post.imagePath != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb 
                  ? Image.network(widget.post.imagePath!, fit: BoxFit.cover, width: double.infinity)
                  : Image.file(File(widget.post.imagePath!), fit: BoxFit.cover, width: double.infinity),
              ),
            ),
          if (widget.post.pollOptions != null && widget.post.pollOptions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: List.generate(widget.post.pollOptions!.length, (index) {
                  bool isSelected = selectedPollIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => selectedPollIndex = index),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                        border: Border.all(color: isSelected ? Colors.blueAccent : AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(widget.post.pollOptions![index], style: TextStyle(color: isSelected ? Colors.blueAccent : AppColors.text, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          if (isSelected) const Icon(Icons.check_circle, color: Colors.blueAccent, size: 18),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              GestureDetector(
                onTap: widget.onLike,
                child: Row(
                  children: [
                    Icon(widget.post.isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: widget.post.isLiked ? Colors.redAccent : AppColors.textSub),
                    const SizedBox(width: 6), 
                    Text('${widget.post.likesCount}', style: TextStyle(color: widget.post.isLiked ? Colors.redAccent : AppColors.textSub)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: widget.onComment,
                child: Row(
                  children: [
                    Icon(Icons.mode_comment_outlined, size: 20, color: AppColors.textSub),
                    const SizedBox(width: 6), 
                    Text('${widget.post.comments.length}', style: TextStyle(color: AppColors.textSub)),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.textSub),
              const SizedBox(width: 6), Text('1', style: TextStyle(color: AppColors.textSub)),
            ],
          ),
        ],
      ),
    );
  }
}

class LeftSidebarContent extends StatelessWidget {
  final int activeIdx;
  final Function(int) onSelect;
  const LeftSidebarContent({super.key, required this.activeIdx, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ChatV', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          Text('v1.1 beta', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
          const SizedBox(height: 40),
          
          // --- ИЗМЕНЕН ПОРЯДОК: ПРОФИЛЬ ТЕПЕРЬ ТУТ ---
          _item(Icons.search, 'Поиск', activeIdx == 3, () => onSelect(3)),
          _item(Icons.feed, 'Лента', activeIdx == 1, () => onSelect(1)),
          _item(Icons.chat_bubble_outline, 'Сообщения', activeIdx == 2, () => onSelect(2)),
          _item(Icons.person_outline, 'Профиль', activeIdx == 0, () => onSelect(0)),
          
          const Spacer(),
          
          ListTile(
            leading: Icon(AppColors.isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.textSub),
            title: Text(AppColors.isDark ? 'Светлая тема' : 'Тёмная тема', style: TextStyle(color: AppColors.textSub)),
            onTap: () => AppColors.toggleTheme(),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              AppData.activeClans.clear();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
    );
  }
  Widget _item(IconData icon, String title, bool active, VoidCallback tap) {
    return ListTile(onTap: tap, leading: Icon(icon, color: active ? AppColors.text : AppColors.textSub), title: Text(title, style: TextStyle(color: active ? AppColors.text : AppColors.textSub, fontWeight: active ? FontWeight.bold : FontWeight.normal)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), tileColor: active ? AppColors.input : Colors.transparent);
  }
}

class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('© 2026 ChatV', style: TextStyle(color: AppColors.textSub, fontSize: 12))]));
  }
}

class TopTabs extends StatelessWidget {
  const TopTabs({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(30)), child: Row(children: [_t('Для вас', true), _t('Подписки', false)]));
  }
  Widget _t(String text, bool active) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: active ? AppColors.input : Colors.transparent, borderRadius: BorderRadius.circular(25)), child: Center(child: Text(text, style: TextStyle(color: active ? AppColors.text : AppColors.textSub, fontSize: 13, fontWeight: FontWeight.bold)))));
  }
}

class ClanEmojisPanel extends StatelessWidget {
  const ClanEmojisPanel({super.key});
  @override
  Widget build(BuildContext context) {
    if (AppData.activeClans.isEmpty) return const SizedBox.shrink();
    final List<Map<String, dynamic>> activeClans = AppData.activeClans.entries.map((e) => {'emoji': e.key, 'count': e.value}).toList();
    activeClans.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: activeClans.length, itemBuilder: (context, index) {
      final clan = activeClans[index];
      return Padding(padding: const EdgeInsets.only(right: 16), child: Column(children: [Container(width: 54, height: 54, decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 1.5)), child: Center(child: Text(clan['emoji'], style: const TextStyle(fontSize: 26)))), const SizedBox(height: 6), Text('${clan['count']} чел.', style: TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.bold))]));
    })));
  }
}