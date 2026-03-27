import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:video_player/video_player.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<Post> posts = [];
  int _currentIndex = 1; 
  XFile? _pickedFile; 
  String? _pickedFileName;
  PostMediaType _currentMediaType = PostMediaType.none;

  bool _isCreatingPoll = false;
  List<TextEditingController> _pollControllers = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // ЗАГРУЗКА ИЗ ПАМЯТИ
  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonPosts = prefs.getStringList('saved_posts_json');
    if (jsonPosts != null) {
      setState(() {
        posts = jsonPosts.map((jsonStr) {
          final map = jsonDecode(jsonStr);
          return Post(
            username: 'Вы', avatarColor: Colors.orange, timeAgo: 'ранее',
            text: map['text'] ?? '', imagePath: map['imagePath'], fileName: map['fileName'],
            mediaType: PostMediaType.values[map['mediaType'] ?? 0],
            pollOptions: map['pollOptions'] != null ? List<String>.from(map['pollOptions']) : null,
            likesCount: map['likesCount'] ?? 0, isLiked: map['isLiked'] ?? false,
            comments: map['comments'] != null ? List<String>.from(map['comments']) : [],
          );
        }).toList();
      });
    }
  }

  // СОХРАНЕНИЕ В ПАМЯТЬ
  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonPosts = posts.map((p) => jsonEncode({
      'text': p.text, 'imagePath': p.imagePath, 'fileName': p.fileName,
      'mediaType': p.mediaType.index, 'pollOptions': p.pollOptions,
      'likesCount': p.likesCount, 'isLiked': p.isLiked, 'comments': p.comments,
    })).toList();
    await prefs.setStringList('saved_posts_json', jsonPosts);
  }

  // ФУНКЦИЯ УДАЛЕНИЯ
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

  // ФУНКЦИЯ РЕДАКТИРОВАНИЯ
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

  // СИСТЕМА КОММЕНТАРИЕВ
  void _showComments(int index) {
    TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                height: 450,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 15),
                    Text('Комментарии', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 30),
                    Expanded(
                      child: posts[index].comments.isEmpty
                          ? Center(child: Text('Пока нет комментариев', style: TextStyle(color: AppColors.textSub)))
                          : ListView.builder(
                              itemCount: posts[index].comments.length,
                              itemBuilder: (c, i) => ListTile(
                                leading: const CircleAvatar(radius: 16, backgroundColor: Colors.orange, child: Icon(Icons.person, size: 16, color: Colors.white)),
                                title: Text('Пользователь', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
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

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    AppData.activeClans.clear();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blueAccent),
            title: Text('Фото', style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null) setState(() { _pickedFile = image; _currentMediaType = PostMediaType.image; _pickedFileName = null; });
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.redAccent),
            title: Text('Видео', style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
              if (video != null) setState(() { _pickedFile = video; _currentMediaType = PostMediaType.video; _pickedFileName = null; });
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.orange),
            title: Text('Документ / Файл', style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null) setState(() { 
                _pickedFile = kIsWeb ? null : XFile(result.files.single.path!); 
                _pickedFileName = result.files.single.name; 
                _currentMediaType = PostMediaType.file; 
              });
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    final Map<String, List<String>> emojiCategories = {
      'Смайлы': ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '😉', '😍', '🥰', '😘', '😋', '😎', '🤩', '🥳', '😏', '😭', '😤', '😡', '🤯', '😱', '🤔', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵'],
      'Животные': ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🦍', '🦧', '🐔', '🐧', '🐦', '🐤', '🐝', '🦋', '🐌', '🐞', '🐜', '🦟', '🐢', '🐍', '🐙', '🦀', '🐡', '🐠', '🐬', '🐳', '🐋', '🦈', '🐊'],
    };

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: emojiCategories.length,
        child: Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SizedBox(
            width: 500, height: 450,
            child: Column(
              children: [
                const SizedBox(height: 20),
                TabBar(isScrollable: true, indicatorColor: Colors.blueAccent, tabs: emojiCategories.keys.map((name) => Tab(text: name)).toList()),
                Expanded(
                  child: TabBarView(
                    children: emojiCategories.values.map((emojis) => GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 10, crossAxisSpacing: 10),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) => GestureDetector(onTap: () { setState(() => _postController.text += emojis[index]); Navigator.pop(context); }, child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 24)))),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _publishPost() {
    String text = _postController.text.trim();
    List<String> currentPollOptions = _pollControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (_isCreatingPoll && (text.isEmpty || currentPollOptions.length < 2)) return;
    if (text.isEmpty && _pickedFile == null && currentPollOptions.isEmpty) return;
    setState(() {
      posts.insert(0, Post(
        username: 'Вы', avatarColor: Colors.orange, timeAgo: 'только что', text: text,
        imagePath: _pickedFile?.path, fileName: _pickedFileName, mediaType: _currentMediaType,
        pollOptions: _isCreatingPoll ? currentPollOptions : null,
      ));
      _postController.clear(); _pickedFile = null; _pickedFileName = null; _currentMediaType = PostMediaType.none;
      _isCreatingPoll = false; _pollControllers = [TextEditingController(), TextEditingController()];
      _savePosts();
    });
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
          appBar: isMobile ? AppBar(
            title: const Text('ChatV', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            backgroundColor: AppColors.sidebar, elevation: 0, centerTitle: true,
            actions: [
              IconButton(icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.text), onPressed: () => AppColors.toggleTheme()),
              IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _logout),
            ],
          ) : null,
          body: Row(
            children: [
              if (!isMobile) Expanded(flex: 2, child: LeftSidebarContent(activeIdx: _currentIndex, onSelect: (idx) => setState(() => _currentIndex = idx), onLogout: _logout)),
              Expanded(
                flex: 5,
                child: Container(
                  color: AppColors.bg,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: isMobile ? screenWidth : 700, 
                      child: _currentIndex == 3 ? _buildSearchScreen() : (_currentIndex == 0 ? const ProfileScreen() : (_currentIndex == 2 ? const MessagesScreen() : _buildFeed())),
                    ),
                  ),
                ),
              ),
              if (screenWidth > 1200) Expanded(flex: 2, child: RightSidebarContent()), 
            ],
          ),
          bottomNavigationBar: isMobile ? BottomNavigationBar(
            backgroundColor: AppColors.sidebar, selectedItemColor: AppColors.text, unselectedItemColor: AppColors.textSub,
            currentIndex: _currentIndex == 1 ? 0 : (_currentIndex == 3 ? 1 : (_currentIndex == 2 ? 2 : 3)),
            type: BottomNavigationBarType.fixed, showSelectedLabels: false, showUnselectedLabels: false,
            onTap: (idx) => setState(() => _currentIndex = [1, 3, 2, 0][idx]),
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

  Widget _buildSearchScreen() {
    final query = _searchController.text.toLowerCase();
    List<Post> searchResults = posts.where((post) {
      if (query.isEmpty) return false;
      return post.text.toLowerCase().contains(query) || post.username.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() {}),
            style: TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: 'Поиск постов и людей...',
              prefixIcon: Icon(Icons.search, color: AppColors.textSub),
              filled: true, fillColor: AppColors.input,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: searchResults.isEmpty
              ? Center(child: Text(query.isEmpty ? 'Начните вводить текст' : 'Ничего не найдено', style: TextStyle(color: AppColors.textSub)))
              : ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      post: searchResults[index], 
                      onLike: () {}, 
                      onEdit: () {}, 
                      onDelete: () {}, 
                      onComment: () {}
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TopTabs(), const SizedBox(height: 16), const ClanEmojisPanel(),
        _buildCreatePostField(), const SizedBox(height: 16),
        if (posts.isEmpty) Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Здесь пока пусто!', style: TextStyle(color: AppColors.textSub))))
        else ...posts.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 12), 
          child: PostCard(
            post: entry.value, 
            onLike: () => setState(() { entry.value.isLiked = !entry.value.isLiked; entry.value.isLiked ? entry.value.likesCount++ : entry.value.likesCount--; _savePosts(); }),
            onDelete: () => _deletePost(entry.key),
            onEdit: () => _editPost(entry.key),
            onComment: () => _showComments(entry.key),
          )
        )),
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
                  children: [
                    TextField(controller: _postController, maxLines: null, style: TextStyle(color: AppColors.text), decoration: InputDecoration(hintText: _isCreatingPoll ? 'Задайте вопрос...' : 'Что нового?', hintStyle: TextStyle(color: AppColors.textSub), border: InputBorder.none)),
                    if (_pickedFileName != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_pickedFileName!, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                    if (_isCreatingPoll) Column(children: [
                      ...List.generate(_pollControllers.length, (i) => Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _pollControllers[i], style: TextStyle(color: AppColors.text, fontSize: 14), decoration: InputDecoration(hintText: 'Вариант ${i+1}', filled: true, fillColor: AppColors.input, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))))),
                      TextButton(onPressed: () => setState(() => _pollControllers.add(TextEditingController())), child: const Text('+ Вариант'))
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(onPressed: _showPickerOptions, icon: Icon(Icons.image_outlined, color: AppColors.textSub)),
                  IconButton(onPressed: _showEmojiPicker, icon: Icon(Icons.emoji_emotions_outlined, color: AppColors.textSub)),
                  IconButton(onPressed: () => setState(() => _isCreatingPoll = !_isCreatingPoll), icon: Icon(Icons.poll_outlined, color: _isCreatingPoll ? Colors.blueAccent : AppColors.textSub)),
                ],
              ),
              ElevatedButton(onPressed: _publishPost, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Опубликовать')),
            ],
          )
        ],
      ),
    );
  }
}

class PostVideoPlayer extends StatefulWidget {
  final String path;
  const PostVideoPlayer({super.key, required this.path});
  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}
class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _controller;
  @override
  void initState() { super.initState(); _controller = VideoPlayerController.file(File(widget.path))..initialize().then((_) => setState(() {})); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)) : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
  }
}

class PostCard extends StatelessWidget {
  final Post post; 
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onComment;

  const PostCard({
    super.key, 
    required this.post, 
    required this.onLike, 
    required this.onDelete, 
    required this.onEdit, 
    required this.onComment
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: post.avatarColor, radius: 18), 
              const SizedBox(width: 10), 
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(post.username, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), Text(post.timeAgo, style: TextStyle(color: AppColors.textSub, fontSize: 11))]), 
              const Spacer(), 
              // ТРОЕТОЧИЕ С МЕНЮ
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: AppColors.textSub),
                color: AppColors.card,
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (c) => [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать', style: TextStyle(color: AppColors.text))),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ]
          ),
          if (post.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(post.text, style: TextStyle(color: AppColors.text, fontSize: 15))),
          if (post.imagePath != null || post.fileName != null) Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildMedia(post))),
          if (post.pollOptions != null) Padding(padding: const EdgeInsets.only(top: 12), child: Column(children: post.pollOptions!.map((o) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)), child: Text(o, style: TextStyle(color: AppColors.text)))).toList())),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(onTap: onLike, child: Row(children: [Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: post.isLiked ? Colors.red : AppColors.textSub, size: 20), const SizedBox(width: 5), Text('${post.likesCount}', style: TextStyle(color: AppColors.textSub))])),
              const SizedBox(width: 20),
              // КНОПКА КОММЕНТАРИЕВ
              GestureDetector(onTap: onComment, child: Row(children: [Icon(Icons.chat_bubble_outline, color: AppColors.textSub, size: 20), const SizedBox(width: 5), Text('${post.comments.length}', style: TextStyle(color: AppColors.textSub))])),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildMedia(Post p) {
    if (p.mediaType == PostMediaType.image) return kIsWeb ? Image.network(p.imagePath!) : Image.file(File(p.imagePath!), fit: BoxFit.cover, width: double.infinity);
    if (p.mediaType == PostMediaType.video) return Container(height: 200, color: Colors.black, child: const Center(child: Icon(Icons.play_circle, color: Colors.white, size: 50)));
    return Container(padding: const EdgeInsets.all(15), color: AppColors.input, child: Row(children: [const Icon(Icons.description, color: Colors.blueAccent), const SizedBox(width: 10), Expanded(child: Text(p.fileName ?? 'Файл', style: TextStyle(color: AppColors.text)))]));
  }
}

class LeftSidebarContent extends StatelessWidget {
  final int activeIdx; final Function(int) onSelect; final VoidCallback onLogout;
  const LeftSidebarContent({super.key, required this.activeIdx, required this.onSelect, required this.onLogout});
  @override
  Widget build(BuildContext context) { 
    return Container(
      color: AppColors.sidebar, padding: const EdgeInsets.all(20), 
      child: Column(children: [
        const Text('ChatV', style: TextStyle(color: Colors.blueAccent, fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 30),
        _i(Icons.search, 'Поиск', 3), _i(Icons.home_filled, 'Лента', 1), _i(Icons.chat_bubble_outline, 'Сообщения', 2), _i(Icons.person_outline, 'Профиль', 0),
        const Spacer(), 
        ListTile(leading: Icon(AppColors.isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.textSub), title: Text('Тема', style: TextStyle(color: AppColors.textSub)), onTap: () => AppColors.toggleTheme()),
        ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)), onTap: onLogout),
      ])
    ); 
  }
  Widget _i(IconData i, String t, int id) { bool a = activeIdx == id; return ListTile(leading: Icon(i, color: a ? AppColors.text : AppColors.textSub), title: Text(t, style: TextStyle(color: a ? AppColors.text : AppColors.textSub)), onTap: () => onSelect(id)); }
}

class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(color: AppColors.sidebar, border: Border(left: BorderSide(color: AppColors.border))),
      child: const SizedBox.expand(),
    );
  }
}

class TopTabs extends StatelessWidget {
  const TopTabs({super.key});
  @override
  Widget build(BuildContext context) { return Row(children: [Expanded(child: Center(child: Text('Для вас', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)))), Expanded(child: Center(child: Text('Подписки', style: TextStyle(color: AppColors.textSub))))]); }
}
class ClanEmojisPanel extends StatelessWidget {
  const ClanEmojisPanel({super.key});
  @override
  Widget build(BuildContext context) { return const SizedBox(height: 10); }
}