import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:video_player/video_player.dart';

import '../../models/post_model.dart';
import '../auth/login_screen.dart';
import '../../data/app_data.dart';
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
  String? _pickedFileName;
  PostMediaType _currentMediaType = PostMediaType.none;

  bool _isCreatingPoll = false;
  List<TextEditingController> _pollControllers = [TextEditingController(), TextEditingController()];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonPosts = prefs.getStringList('saved_posts_json_v3');
    if (jsonPosts != null) {
      setState(() {
        posts = jsonPosts.map((jsonStr) {
          final map = jsonDecode(jsonStr);
          return Post(
            username: map['username'] ?? 'Вы', avatarColor: Colors.orange, timeAgo: 'ранее',
            text: map['text'] ?? '', imagePath: map['imagePath'], fileName: map['fileName'],
            mediaType: PostMediaType.values[map['mediaType'] ?? 0],
            pollOptions: map['pollOptions'] != null ? List<String>.from(map['pollOptions']) : null,
            pollVotes: map['pollVotes'] != null ? List<int>.from(map['pollVotes']) : null,
            votedOptionIndex: map['votedOptionIndex'],
            likesCount: map['likesCount'] ?? 0, isLiked: map['isLiked'] ?? false,
            comments: map['comments'] != null ? List<String>.from(map['comments']) : [],
          );
        }).toList();
      });
    }
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonPosts = posts.map((p) => jsonEncode({
      'username': p.username, 'text': p.text, 'imagePath': p.imagePath, 'fileName': p.fileName,
      'mediaType': p.mediaType.index, 'pollOptions': p.pollOptions,
      'pollVotes': p.pollVotes, 'votedOptionIndex': p.votedOptionIndex,
      'likesCount': p.likesCount, 'isLiked': p.isLiked, 'comments': p.comments,
    })).toList();
    await prefs.setStringList('saved_posts_json_v3', jsonPosts);
  }

  void _deletePost(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Удалить запись?', style: TextStyle(color: Colors.white)),
        content: const Text('Это действие нельзя отменить.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
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
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Редактировать', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: editController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Текст записи...', hintStyle: TextStyle(color: Colors.grey)),
            maxLines: null,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  posts[index].text = editController.text;
                  _savePosts();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text('Сохранить'),
            ),
          ],
        );
      }
    );
  }

  // =====================================
  // ИСПРАВЛЕННЫЙ БЛОК КОММЕНТАРИЕВ
  // =====================================
  void _showComments(int index) async {
    // Получаем реальное имя пользователя из памяти
    final prefs = await SharedPreferences.getInstance();
    String currentUserName = prefs.getString('userName') ?? "Вы";

    TextEditingController commentController = TextEditingController();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
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
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 15),
                    const Text('Комментарии', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 30, color: Colors.white10),
                    Expanded(
                      child: posts[index].comments.isEmpty
                          ? const Center(child: Text('Пока нет комментариев', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: posts[index].comments.length,
                              itemBuilder: (c, i) {
                                // Парсим комментарий: вытаскиваем Имя и Текст
                                String rawText = posts[index].comments[i];
                                String authorName = currentUserName; // По умолчанию
                                String commentText = rawText;

                                if (rawText.contains('||')) {
                                  final parts = rawText.split('||');
                                  authorName = parts[0];
                                  commentText = parts[1];
                                }

                                return ListTile(
                                  leading: const CircleAvatar(radius: 16, backgroundColor: Colors.orange, child: Icon(Icons.person, size: 16, color: Colors.white)),
                                  title: Text(authorName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  subtitle: Text(commentText, style: const TextStyle(color: Colors.grey)),
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Написать комментарий...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFF333333),
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
                                // Сохраняем коммент склеивая "Имя||Текст"
                                posts[index].comments.add("$currentUserName||${commentController.text.trim()}");
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

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blueAccent),
            title: const Text('Фото', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null) setState(() { _pickedFile = image; _currentMediaType = PostMediaType.image; _pickedFileName = null; });
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.redAccent),
            title: const Text('Видео', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
              if (video != null) setState(() { _pickedFile = video; _currentMediaType = PostMediaType.video; _pickedFileName = null; });
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.orange),
            title: const Text('Документ / Файл', style: TextStyle(color: Colors.white)),
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

  void _publishPost() async {
    String text = _postController.text.trim();
    List<String> currentPollOptions = _pollControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (_isCreatingPoll && (text.isEmpty || currentPollOptions.length < 2)) return;
    if (text.isEmpty && _pickedFile == null && currentPollOptions.isEmpty) return;
    
    // Получаем никнейм автора для поста
    final prefs = await SharedPreferences.getInstance();
    String myName = prefs.getString('userName') ?? "Вы";

    setState(() {
      posts.insert(0, Post(
        username: myName, avatarColor: Colors.orange, timeAgo: 'только что', text: text,
        imagePath: _pickedFile?.path, fileName: _pickedFileName, mediaType: _currentMediaType,
        pollOptions: _isCreatingPoll ? currentPollOptions : null,
        pollVotes: _isCreatingPoll ? List.filled(currentPollOptions.length, 0) : null,
      ));
      _postController.clear(); _pickedFile = null; _pickedFileName = null; _currentMediaType = PostMediaType.none;
      _isCreatingPoll = false; _pollControllers = [TextEditingController(), TextEditingController()];
      _savePosts();
      FocusScope.of(context).unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return Scaffold(
      appBar: isMobile ? AppBar(
        title: const Text('ChatV', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ) : null,
      
      body: Row(
        children: [
          if (!isMobile)
            Expanded(
              flex: 2, 
              child: LeftSidebarContent(
                activeIdx: _currentIndex, 
                onSelect: (idx) => setState(() => _currentIndex = idx)
              )
            ),

          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFF000000),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: isMobile ? screenWidth : 700, 
                  child: _currentIndex == 0 
                    ? ProfileScreen(allPosts: posts) 
                    : (_currentIndex == 2 ? const MessagesScreen() : _buildFeed()),
                ),
              ),
            ),
          ),

          if (screenWidth > 1200)
            const Expanded(flex: 2, child: RightSidebarContent()),
        ],
      ),
      
      bottomNavigationBar: isMobile ? BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex == 0 ? 3 : (_currentIndex == 2 ? 2 : 0), 
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (idx) {
          if (idx == 0) setState(() => _currentIndex = 1);
          if (idx == 2) setState(() => _currentIndex = 2);
          if (idx == 3) setState(() => _currentIndex = 0);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ) : null,
    );
  }

  Widget _buildFeed() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        const TopTabs(),
        const SizedBox(height: 16),
        const ClanEmojisPanel(),
        _buildCreatePostField(),
        const SizedBox(height: 16),
        if (posts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('Здесь пока пусто!', style: TextStyle(color: Colors.grey))),
          )
        else
          ...posts.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: entry.value,
              onLike: () => setState(() { entry.value.isLiked = !entry.value.isLiked; entry.value.isLiked ? entry.value.likesCount++ : entry.value.likesCount--; _savePosts(); }),
              onDelete: () => _deletePost(entry.key),
              onEdit: () => _editPost(entry.key),
              onComment: () => _showComments(entry.key), // ВЫЗЫВАЕМ КОММЕНТАРИИ
              onVote: () => setState(() { _savePosts(); }), 
            ),
          )),
      ],
    );
  }

  Widget _buildCreatePostField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
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
                    TextField(
                      controller: _postController,
                      maxLines: null,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Что нового?', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none),
                    ),
                    
                    if (_pickedFile != null) 
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _currentMediaType == PostMediaType.image
                                  ? (kIsWeb ? Image.network(_pickedFile!.path, fit: BoxFit.cover) : Image.file(File(_pickedFile!.path), fit: BoxFit.cover))
                                  : _currentMediaType == PostMediaType.video
                                      ? SizedBox(height: 200, child: PostVideoPlayer(path: _pickedFile!.path))
                                      : Container(padding: const EdgeInsets.all(15), color: const Color(0xFF333333), child: Row(children: [const Icon(Icons.description, color: Colors.blueAccent), const SizedBox(width: 10), Expanded(child: Text(_pickedFileName ?? 'Файл', style: const TextStyle(color: Colors.white)))])),
                            ),
                          ),
                          Positioned(
                            top: 15, right: 5,
                            child: GestureDetector(
                              onTap: () => setState(() { _pickedFile = null; _pickedFileName = null; _currentMediaType = PostMediaType.none; }),
                              child: const CircleAvatar(backgroundColor: Colors.black54, radius: 14, child: Icon(Icons.close, size: 16, color: Colors.white)),
                            ),
                          )
                        ],
                      ),

                    if (_isCreatingPoll) Column(children: [
                      ...List.generate(_pollControllers.length, (i) => Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: _pollControllers[i], style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: 'Вариант ${i+1}', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: const Color(0xFF333333), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))))),
                      TextButton(onPressed: () => setState(() => _pollControllers.add(TextEditingController())), child: const Text('+ Вариант'))
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey, size: 22),
                    onPressed: _showPickerOptions,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 22),
                    onPressed: () {}, 
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.poll_outlined, color: _isCreatingPoll ? Colors.blueAccent : Colors.grey, size: 22),
                    onPressed: () => setState(() => _isCreatingPoll = !_isCreatingPoll),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('Опубликовать', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// ПОЛНОЭКРАННЫЙ ПРОСМОТР ФОТО
// ==========================================
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, minScale: 0.5, maxScale: 4.0,
          child: kIsWeb ? Image.network(imagePath) : Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

// ==========================================
// ИНТЕРАКТИВНЫЙ ВИДЕОПЛЕЕР 
// ==========================================
class PostVideoPlayer extends StatefulWidget {
  final String path;
  const PostVideoPlayer({super.key, required this.path});
  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() { 
    super.initState(); 
    if (kIsWeb) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.path));
    } else {
      _controller = VideoPlayerController.file(File(widget.path));
    }
    _controller.initialize().then((_) {
      setState(() {});
      _startHideTimer();
    }); 
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _hideTimer?.cancel(); 
      } else {
        _controller.play();
        _showControls = true;
        _startHideTimer();
      }
    });
  }

  @override
  void dispose() { 
    _hideTimer?.cancel();
    _controller.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized 
      ? Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls && _controller.value.isPlaying) {
                    _startHideTimer();
                  } else {
                    _hideTimer?.cancel();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            
            IgnorePointer(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio, 
                child: VideoPlayer(_controller)
              ),
            ),
            
            if (_showControls) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54, 
                    radius: 30, 
                    child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 35)
                  ),
                ),
              ),
              
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, 
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller, 
                            allowScrubbing: true,
                            colors: const VideoProgressColors(playedColor: Colors.blueAccent, backgroundColor: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(_controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 18),
                        
                        SizedBox(
                          width: 70,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 2,
                            ),
                            child: Slider(
                              value: _controller.value.volume,
                              min: 0.0,
                              max: 1.0,
                              activeColor: Colors.blueAccent,
                              inactiveColor: Colors.white54,
                              onChanged: (val) {
                                _controller.setVolume(val);
                                if (_controller.value.isPlaying) _startHideTimer(); 
                              },
                            ),
                          ),
                        ),
                        
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                          onPressed: () {
                            _hideTimer?.cancel();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenVideoPage(controller: _controller))).then((_) {
                              if (_controller.value.isPlaying) _startHideTimer();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        ) 
      : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white)));
  }
}

// ==========================================
// ПОЛНОЭКРАННЫЙ ВИДЕОПЛЕЕР
// ==========================================
class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  const FullScreenVideoPage({super.key, required this.controller});

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        widget.controller.play();
        _showControls = true;
        _startHideTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls && widget.controller.value.isPlaying) {
                    _startHideTimer();
                  } else {
                    _hideTimer?.cancel();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            
            IgnorePointer(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            
            if (_showControls) ...[
              IgnorePointer(child: Container(color: Colors.black38)),
              
              Positioned(
                top: 10, left: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54, 
                    radius: 40, 
                    child: Icon(widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 45)
                  ),
                ),
              ),
              
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        widget.controller, 
                        allowScrubbing: true,
                        colors: const VideoProgressColors(playedColor: Colors.blueAccent, backgroundColor: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(widget.controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white),
                              SizedBox(
                                width: 120,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: widget.controller.value.volume,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: Colors.blueAccent,
                                    inactiveColor: Colors.white54,
                                    onChanged: (val) {
                                      widget.controller.setVolume(val);
                                      if (widget.controller.value.isPlaying) _startHideTimer();
                                    },
                                  ),
                                ),
                              )
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ОБНОВЛЕННЫЙ САЙДБАР С ОБРАБОТКОЙ НАЖАТИЙ
class LeftSidebarContent extends StatelessWidget {
  final int activeIdx;
  final Function(int) onSelect;
  const LeftSidebarContent({super.key, required this.activeIdx, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      color: const Color(0xFF121212),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ChatV', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const Text('v1.1 beta', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 40),
          _item(Icons.person_outline, 'Профиль', activeIdx == 0, () => onSelect(0)),
          _item(Icons.feed, 'Лента', activeIdx == 1, () => onSelect(1)),
          _item(Icons.search, 'Поиск', false, () {}),
          _item(Icons.notifications_none, 'Сообщения', activeIdx == 2, () => onSelect(2)),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, bool active, VoidCallback tap) {
    return ListTile(
      onTap: tap,
      leading: Icon(icon, color: active ? Colors.white : Colors.grey),
      title: Text(title, style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: active ? const Color(0xFF1E1E1E) : Colors.transparent,
    );
  }
}

class ClanEmojisPanel extends StatelessWidget {
  const ClanEmojisPanel({super.key});
  @override
  Widget build(BuildContext context) {
    if (AppData.activeClans.isEmpty) return const SizedBox.shrink();
    final List<Map<String, dynamic>> activeClans = AppData.activeClans.entries.map((e) => {'emoji': e.key, 'count': e.value}).toList();
    activeClans.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: activeClans.length,
          itemBuilder: (context, index) {
            final clan = activeClans[index];
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 1.5)),
                    child: Center(child: Text(clan['emoji'], style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(height: 6),
                  Text('${clan['count']} чел.', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onComment;
  final VoidCallback onVote;

  const PostCard({super.key, required this.post, required this.onLike, required this.onDelete, required this.onEdit, required this.onComment, required this.onVote});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: post.avatarColor, radius: 20),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                Text(post.timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                color: const Color(0xFF333333),
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 'edit', child: Text('Редактировать', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (post.text.isNotEmpty) Text(post.text, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white)),
          
          if (post.imagePath != null || post.fileName != null) 
            Padding(
              padding: const EdgeInsets.only(top: 12), 
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildMedia(post, context))
            ),
            
          if (post.pollOptions != null && post.pollVotes != null) 
            Padding(
              padding: const EdgeInsets.only(top: 12), 
              child: Column(
                children: List.generate(post.pollOptions!.length, (index) {
                  String optionText = post.pollOptions![index];
                  int votesCount = post.pollVotes![index];
                  int totalVotes = post.pollVotes!.fold(0, (sum, v) => sum + v);
                  bool hasVoted = post.votedOptionIndex != null;
                  double percentage = totalVotes > 0 ? (votesCount / totalVotes) : 0.0;
                  bool isSelected = post.votedOptionIndex == index;

                  return GestureDetector(
                    onTap: () {
                      if (!hasVoted) {
                        post.votedOptionIndex = index;
                        post.pollVotes![index]++;
                        onVote(); 
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: isSelected ? Colors.blueAccent : const Color(0xFF333333)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          if (hasVoted)
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: percentage,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF333333).withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(optionText, style: const TextStyle(color: Colors.white))),
                                if (hasVoted)
                                  Text('${(percentage * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              )
            ),
            if (post.pollOptions != null && post.pollVotes != null && post.votedOptionIndex != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Всего голосов: ${post.pollVotes!.fold(0, (sum, v) => sum + v)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),

          const SizedBox(height: 16),
          Row(children: [
            GestureDetector(
              onTap: onLike, 
              child: Row(children: [
                Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: post.isLiked ? Colors.red : Colors.grey), 
                const SizedBox(width: 6), 
                Text('${post.likesCount}', style: const TextStyle(color: Colors.grey))
              ])
            ),
            const SizedBox(width: 20),
            
            // КЛИКАБЕЛЬНАЯ КНОПКА КОММЕНТАРИЕВ
            GestureDetector(
              onTap: onComment,
              child: Row(children: [
                const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.grey),
                const SizedBox(width: 6), 
                Text('${post.comments.length}', style: const TextStyle(color: Colors.grey))
              ])
            ),
            
            const Spacer(),
            const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: 6), const Text('1', style: TextStyle(color: Colors.grey)),
          ]),
        ],
      ),
    );
  }

  Widget _buildMedia(Post p, BuildContext context) {
    if (p.mediaType == PostMediaType.image) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePath: p.imagePath!))),
        child: kIsWeb ? Image.network(p.imagePath!) : Image.file(File(p.imagePath!), fit: BoxFit.cover, width: double.infinity),
      );
    }
    if (p.mediaType == PostMediaType.video) return PostVideoPlayer(path: p.imagePath!);
    return Container(padding: const EdgeInsets.all(15), color: const Color(0xFF333333), child: Row(children: [const Icon(Icons.description, color: Colors.blueAccent), const SizedBox(width: 10), Expanded(child: Text(p.fileName ?? 'Файл', style: const TextStyle(color: Colors.white)))]));
  }
}

class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(30),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Вакансии', style: TextStyle(color: Colors.grey, fontSize: 13)),
        SizedBox(height: 12),
        Text('Конфиденциальность', style: TextStyle(color: Colors.grey, fontSize: 13)),
        SizedBox(height: 12),
        Text('© 2026 ChatV', style: TextStyle(color: Colors.white24, fontSize: 12)),
      ]),
    );
  }
}

class TopTabs extends StatelessWidget {
  const TopTabs({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        _t('Для вас', true),
        _t('Подписки', false),
      ]),
    );
  }
  Widget _t(String text, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? const Color(0xFF333333) : Colors.transparent, borderRadius: BorderRadius.circular(25)),
        child: Center(child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 13))),
      ),
    );
  }
}