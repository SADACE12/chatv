import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; 
import 'dart:io';
import 'dart:convert';
import 'dart:async'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import '../../models/post_model.dart';
import '../auth/login_screen.dart';
import '../../data/app_data.dart';
import 'profile_screen.dart' hide MessagesScreen; 
import 'messages_screen.dart'; 

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final supabase = Supabase.instance.client;
  
  User? get currentUser => supabase.auth.currentUser;
  String myName = "Вы"; 

  final TextEditingController _postController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final ImagePicker _picker = ImagePicker();
  
  List<Post> posts = [];
  int _currentIndex = 1; 
  
  bool _isFollowingFeed = false;

  XFile? _pickedFile; 
  String? _pickedFileName;
  PostMediaType _currentMediaType = PostMediaType.none;

  bool _isCreatingPoll = false;
  List<TextEditingController> _pollControllers = [TextEditingController(), TextEditingController()];

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    _postController.dispose();
    _searchController.dispose();
    for (var controller in _pollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        myName = prefs.getString('userName') ?? currentUser!.email!.split('@')[0];
      });
    }
    await _loadPosts(); 
    _setupRealtime();   
  }

  void _setupRealtime() {
    _realtimeChannel = supabase
        .channel('public_changes')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            callback: (payload) {
              _loadPosts(); 
            })
        .subscribe();
  }

  Future<void> _loadPosts() async {
    if (currentUser == null) return;
    
    // Получаем локальные данные, чтобы помнить, где мы уже голосовали
    final prefs = await SharedPreferences.getInstance();
    
    try {
      List<dynamic> data = [];

      if (_isFollowingFeed) {
        final followData = await supabase
            .from('followers')
            .select('following_id')
            .eq('follower_id', currentUser!.id);
            
        List<String> followedIds = (followData as List).map((row) => row['following_id'].toString()).toList();
        
        if (followedIds.isEmpty) {
          if (mounted) setState(() => posts = []);
          return;
        }
        
        data = await supabase
            .from('posts')
            .select('*, likes(username), comments(*)')
            .filter('user_id', 'in', followedIds)
            .order('created_at', ascending: false);
      } else {
        data = await supabase
            .from('posts')
            .select('*, likes(username), comments(*)')
            .order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          posts = (data as List).map((map) {
            final List likesList = map['likes'] ?? [];
            final List commentsList = map['comments'] ?? [];

            final post = Post(
              id: map['id'],
              userId: map['user_id'], 
              username: map['username'] ?? 'Аноним',
              avatarColor: Color(map['avatar_color'] ?? Colors.orange.value), 
              createdAt: DateTime.parse(map['created_at']), 
              text: map['text'] ?? '', 
              imagePath: map['image_path'], 
              fileName: map['file_name'],
              mediaType: PostMediaType.values[map['media_type'] ?? 0],
              likesCount: likesList.length,
              isLiked: likesList.any((like) => like['username'] == myName),
              comments: commentsList.map((c) => "${c['username']}||${c['text']}").toList(),
              pollOptions: map['poll_options'] != null ? List<String>.from(map['poll_options']) : null,
              pollVotes: map['poll_votes'] != null ? List<int>.from(map['poll_votes']) : null,
            );
            
            // Восстанавливаем информацию о нашем голосе
            post.votedOptionIndex = prefs.getInt('voted_poll_${map['id']}');
            
            return post;
          }).toList();
        });
      }
    } catch (e) {
      print('Ошибка при загрузке данных из БД: $e');
    }
  }

  void _toggleLike(int index) async {
    final post = posts[index];
    final postId = post.id;
    if (postId == null) return;

    final bool wasLiked = post.isLiked;

    setState(() {
      if (wasLiked) {
        post.isLiked = false;
        post.likesCount--;
      } else {
        post.isLiked = true;
        post.likesCount++;
      }
    });

    try {
      if (wasLiked) {
        await supabase.from('likes').delete().eq('post_id', postId).eq('username', myName);
      } else {
        await supabase.from('likes').insert({'post_id': postId, 'username': myName});
      }
    } catch (e) {
      print('Ошибка при обработке лайка: $e');
    }
  }

  Future<void> _handleVote(int postIndex, int optionIndex) async {
    final post = posts[postIndex];
    if (post.id == null || post.pollVotes == null) return;

    // Если уже голосовал, блокируем повторное нажатие
    if (post.votedOptionIndex != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Вы уже проголосовали!')));
      return;
    }

    // Обновляем UI мгновенно
    setState(() {
      post.pollVotes![optionIndex]++;
      post.votedOptionIndex = optionIndex; // Запоминаем выбор
    });

    // Сохраняем в память телефона, чтобы не забыть после перезапуска приложения
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('voted_poll_${post.id}', optionIndex);

    try {
      await supabase.from('posts').update({
        'poll_votes': post.pollVotes
      }).eq('id', post.id!);
    } catch (e) {
      print('Ошибка при голосовании: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки голоса: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addComment(int index, String commentText) async {
    final postId = posts[index].id;
    if (postId == null || commentText.isEmpty) return;

    try {
      await supabase.from('comments').insert({
        'post_id': postId,
        'username': myName,
        'text': commentText,
      });
      
      setState(() {
        posts[index].comments.add("$myName||$commentText");
      });
    } catch (e) {
      print('Ошибка при отправке комментария: $e');
    }
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
            onPressed: () async {
              final postToDelete = posts[index];
              final postId = postToDelete.id;

              Navigator.pop(context);

              if (postId == null) return;

              setState(() {
                posts.removeAt(index);
              });

              try {
                await supabase.from('posts').delete().eq('id', postId);
              } catch (e) {
                setState(() {
                  posts.insert(index, postToDelete);
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка БД: $e'), backgroundColor: Colors.red));
              }
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
      builder: (dialogContext) {
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Отмена', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = editController.text.trim();
                final postId = posts[index].id;
                Navigator.pop(dialogContext);

                if (postId == null) return;

                try {
                  await supabase.from('posts').update({'text': newText}).eq('id', postId);
                  if (mounted) setState(() => posts[index].text = newText);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка БД: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text('Сохранить'),
            ),
          ],
        );
      }
    );
  }

  void _showComments(int index) {
    TextEditingController commentController = TextEditingController();
    
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
                                String rawText = posts[index].comments[i];
                                String author = "Аноним";
                                String text = rawText;

                                if (rawText.contains('||')) {
                                  final parts = rawText.split('||');
                                  author = parts[0];
                                  text = parts[1];
                                }

                                return ListTile(
                                  leading: const CircleAvatar(radius: 16, backgroundColor: Colors.orange, child: Icon(Icons.person, size: 16, color: Colors.white)),
                                  title: Text(author, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  subtitle: Text(text, style: const TextStyle(color: Colors.grey)),
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
                              hintText: 'Написать...',
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
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                              await _addComment(index, commentController.text.trim());
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

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              setState(() {
                _postController.text += emoji.emoji;
              });
            },
            config: const Config(
              emojiViewConfig: EmojiViewConfig(
                backgroundColor: Color(0xFF1E1E1E),
              ),
              categoryViewConfig: CategoryViewConfig(
                backgroundColor: Color(0xFF1E1E1E),
                indicatorColor: Colors.blueAccent,
                iconColorSelected: Colors.blueAccent,
              ),
              bottomActionBarConfig: BottomActionBarConfig(
                backgroundColor: Color(0xFF1E1E1E),
                buttonIconColor: Colors.grey,
                buttonColor: Color(0xFF1E1E1E),
              ),
            ),
          ),
        );
      },
    );
  }

  void _publishPost() async {
    if (currentUser == null) return;
    
    String text = _postController.text.trim();
    List<String> currentPollOptions = _pollControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    
    if (_isCreatingPoll) {
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите текст вопроса для опросника')));
        return;
      }
      if (currentPollOptions.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавьте минимум 2 варианта ответа')));
        return;
      }
    }
    
    if (text.isEmpty && _pickedFile == null && currentPollOptions.isEmpty) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Публикация... Пожалуйста, подождите'), duration: Duration(seconds: 2)),
    );

    try {
      String? uploadedUrl;

      if (_pickedFile != null) {
        final bytes = await _pickedFile!.readAsBytes();
        final fileExtension = _pickedFile!.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        await supabase.storage.from('post_media').uploadBinary(fileName, bytes);
        uploadedUrl = supabase.storage.from('post_media').getPublicUrl(fileName);
      }

      final response = await supabase.from('posts').insert({
        'user_id': currentUser!.id, 
        'username': myName,
        'avatar_color': Colors.orange.value, 
        'text': text,
        'media_type': _currentMediaType.index,
        'image_path': uploadedUrl,
        'file_name': _pickedFileName,
        'poll_options': _isCreatingPoll ? currentPollOptions : null,
        'poll_votes': _isCreatingPoll ? List.filled(currentPollOptions.length, 0) : null,
      }).select();

      setState(() {
        if (!_isFollowingFeed) {
          posts.insert(0, Post(
            id: response[0]['id'],
            userId: currentUser!.id, 
            username: myName, 
            avatarColor: Colors.orange, 
            createdAt: DateTime.parse(response[0]['created_at']), 
            text: text,
            imagePath: uploadedUrl, 
            fileName: _pickedFileName, 
            mediaType: _currentMediaType,
            pollOptions: _isCreatingPoll ? currentPollOptions : null,
            pollVotes: _isCreatingPoll ? List.filled(currentPollOptions.length, 0) : null,
            comments: [],
            likesCount: 0,
            isLiked: false,
          ));
        }
      });

    } catch (e) {
      print('Ошибка при публикации: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() {
      _postController.clear(); _pickedFile = null; _pickedFileName = null; _currentMediaType = PostMediaType.none;
      _isCreatingPoll = false; _pollControllers = [TextEditingController(), TextEditingController()];
      FocusScope.of(context).unfocus();
    });
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
                      decoration: InputDecoration(
                        hintText: _isCreatingPoll ? 'Задайте вопрос...' : 'Что нового?', 
                        hintStyle: const TextStyle(color: Colors.grey), 
                        border: InputBorder.none
                      ),
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
                      TextButton(
                        onPressed: () => setState(() => _pollControllers.add(TextEditingController())), 
                        child: const Text('+ Вариант', style: TextStyle(color: Colors.blueAccent))
                      )
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
                    onPressed: _showEmojiPicker, 
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), 
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
                    : (_currentIndex == 2 
                        ? const MessagesScreen() 
                        : (_currentIndex == 3 ? _buildSearchScreen() : _buildFeed())),
                ),
              ),
            ),
          ),
          
          if (screenWidth > 1200)
            Expanded(
              flex: 2, 
              child: Container(color: const Color(0xFF000000)),
            ),
        ],
      ),
      
      bottomNavigationBar: isMobile ? BottomNavigationBar(
        backgroundColor: const Color(0xFF121212),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex == 1 ? 0 : (_currentIndex == 3 ? 1 : (_currentIndex == 2 ? 2 : 3)), 
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

  Widget _buildSearchScreen() {
    List<Post> searchResults = [];
    if (_searchQuery.isNotEmpty) {
      searchResults = posts.where((p) => 
        p.text.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.username.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Поиск постов и авторов...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_searchQuery.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('Введите текст для поиска', style: TextStyle(color: Colors.grey)),
            ),
          )
        else if (searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('Ничего не найдено', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...searchResults.map((post) {
            int originalIndex = posts.indexOf(post);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                currentUserId: currentUser?.id, 
                onLike: () => _toggleLike(originalIndex),
                onDelete: () => _deletePost(originalIndex),
                onEdit: () => _editPost(originalIndex),
                onComment: () => _showComments(originalIndex),
                onVote: (optionIndex) => _handleVote(originalIndex, optionIndex), 
                onProfileTap: () {
                  if (post.userId != null && post.userId == currentUser?.id) {
                    setState(() => _currentIndex = 0);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: const Color(0xFF000000),
                          appBar: AppBar(
                            backgroundColor: const Color(0xFF121212),
                            title: Text(post.username, style: const TextStyle(color: Colors.white, fontSize: 16)),
                            iconTheme: const IconThemeData(color: Colors.white),
                          ),
                          body: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width < 900 ? MediaQuery.of(context).size.width : 700,
                              child: ProfileScreen(
                                allPosts: posts, 
                                targetUserId: post.userId, 
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildFeed() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      children: [
        TopTabs(
          isFollowingFeed: _isFollowingFeed,
          onTabChanged: (isFollowing) {
            if (_isFollowingFeed != isFollowing) {
              setState(() {
                _isFollowingFeed = isFollowing;
                posts = []; 
              });
              _loadPosts();
            }
          },
        ),
        const SizedBox(height: 16),
        const ClanEmojisPanel(),
        _buildCreatePostField(),
        const SizedBox(height: 16),
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                _isFollowingFeed ? 'Вы никого не читаете или у них нет постов.' : 'Здесь пока пусто!', 
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              )
            ),
          )
        else
          ...posts.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: entry.value,
              currentUserId: currentUser?.id, 
              onLike: () => _toggleLike(entry.key),
              onDelete: () => _deletePost(entry.key),
              onEdit: () => _editPost(entry.key),
              onComment: () => _showComments(entry.key),
              onVote: (optionIndex) => _handleVote(entry.key, optionIndex), 
              onProfileTap: () {
                if (entry.value.userId != null && entry.value.userId == currentUser?.id) {
                  setState(() => _currentIndex = 0);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        backgroundColor: const Color(0xFF000000),
                        appBar: AppBar(
                          backgroundColor: const Color(0xFF121212),
                          title: Text(entry.value.username, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width < 900 ? MediaQuery.of(context).size.width : 700,
                            child: ProfileScreen(
                              allPosts: posts,
                              targetUserId: entry.value.userId, 
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          )),
      ],
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final String? currentUserId; 
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onComment;
  final Function(int) onVote;
  final VoidCallback onProfileTap; 

  const PostCard({
    super.key, 
    required this.post, 
    this.currentUserId, 
    required this.onLike, 
    required this.onDelete, 
    required this.onEdit, 
    required this.onComment, 
    required this.onVote,
    required this.onProfileTap, 
  });
  
  Widget _buildMedia(Post p, BuildContext context) {
    bool isNetworkUrl = p.imagePath != null && p.imagePath!.startsWith('http');

    if (p.mediaType == PostMediaType.image) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePath: p.imagePath!))),
        child: isNetworkUrl 
            ? Image.network(p.imagePath!, fit: BoxFit.cover, width: double.infinity) 
            : Image.file(File(p.imagePath!), fit: BoxFit.cover, width: double.infinity),
      );
    }
    if (p.mediaType == PostMediaType.video) return PostVideoPlayer(path: p.imagePath!);
    return Container(padding: const EdgeInsets.all(15), color: const Color(0xFF333333), child: Row(children: [const Icon(Icons.description, color: Colors.blueAccent), const SizedBox(width: 10), Expanded(child: Text(p.fileName ?? 'Файл', style: const TextStyle(color: Colors.white)))]));
  }

  @override
  Widget build(BuildContext context) {
    bool isMyPost = post.userId != null && post.userId == currentUserId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque, 
                onTap: onProfileTap,
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: post.avatarColor, radius: 20),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      Text('${post.createdAt.hour}:${post.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ],
                ),
              ),
              const Spacer(),
              if (isMyPost)
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

          if (post.pollOptions != null && post.pollOptions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: List.generate(post.pollOptions!.length, (index) {
                  final option = post.pollOptions![index];
                  final votes = (post.pollVotes != null && post.pollVotes!.length > index) 
                      ? post.pollVotes![index] 
                      : 0;

                  // Вычисляем проценты
                  int totalVotes = post.pollVotes?.fold<int>(0, (int sum, int item) => sum + item) ?? 0;
                  double percentage = totalVotes > 0 ? (votes / totalVotes) : 0.0;
                  int percentInt = (percentage * 100).round();
                  
                  bool hasVoted = post.votedOptionIndex != null;
                  bool isSelected = post.votedOptionIndex == index;

                  return GestureDetector(
                    onTap: () {
                      if (!hasVoted) {
                        onVote(index);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      height: 48, // Фиксированная высота кнопки опроса
                      child: Stack(
                        children: [
                          // 1. Базовый фон кнопки
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 1.5),
                            ),
                          ),
                          
                          // 2. Полоса заполнения процента (показывается только после голосования)
                          if (hasVoted)
                            FractionallySizedBox(
                              widthFactor: percentage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            
                          // 3. Текст варианта и проценты
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 14))
                                  )
                                ),
                                if (hasVoted)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('$votes ($percentInt%)', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold))
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
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
}

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    bool isNetworkUrl = imagePath.startsWith('http');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white), elevation: 0),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, minScale: 0.5, maxScale: 4.0,
          child: isNetworkUrl ? Image.network(imagePath) : Image.file(File(imagePath)),
        ),
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
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() { 
    super.initState(); 
    bool isNetworkUrl = widget.path.startsWith('http');
    if (isNetworkUrl || kIsWeb) {
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
            ]
          ],
        ) 
      : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white)));
  }
}

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
                child: CircleAvatar(
                  backgroundColor: Colors.black54, 
                  radius: 40, 
                  child: Icon(widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 45)
                ),
              ),
            ],
          ],
        ),
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
      color: const Color(0xFF121212),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ChatV', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const Text('v1.1 beta', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 40),
          _item(Icons.person_outline, 'Профиль', activeIdx == 0, () => onSelect(0)),
          _item(Icons.feed, 'Лента', activeIdx == 1, () => onSelect(1)),
          _item(Icons.search, 'Поиск', activeIdx == 3, () => onSelect(3)),
          _item(Icons.chat_bubble_outline, 'Сообщения', activeIdx == 2, () => onSelect(2)),
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

class TopTabs extends StatelessWidget {
  final bool isFollowingFeed;
  final Function(bool) onTabChanged;

  const TopTabs({
    super.key, 
    required this.isFollowingFeed, 
    required this.onTabChanged
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        _t('Для вас', !isFollowingFeed, () => onTabChanged(false)),
        _t('Подписки', isFollowingFeed, () => onTabChanged(true)),
      ]),
    );
  }

  Widget _t(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? const Color(0xFF333333) : Colors.transparent, borderRadius: BorderRadius.circular(25)),
          child: Center(child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 13))),
        ),
      ),
    );
  }
}