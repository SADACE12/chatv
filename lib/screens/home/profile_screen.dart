import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../../theme/app_colors.dart';
import '../../models/post_model.dart';
import 'main_layout.dart';
import 'messages_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  final List<Post> allPosts; 
  final String? targetUserId;
  final Function(Post)? onLike;
  final Function(Post)? onDelete;
  final Function(Post)? onEdit;
  final Function(Post)? onPostTap;
  final Function(Post, int)? onVote;

  const ProfileScreen({
    super.key,
    required this.allPosts,
    this.targetUserId,
    this.onLike,
    this.onDelete,
    this.onEdit,
    this.onPostTap,
    this.onVote,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final currentUser = Supabase.instance.client.auth.currentUser;

  String userName = "Загрузка...";
  String userHandle = "@loading";
  String? userEmoji;
  String userBio = "";
  bool _showLikes = false; 

  int followersCount = 0;
  bool isFollowing = false;

  // --- ПЕРЕМЕННЫЕ ДЛЯ РИСОВАНИЯ БАННЕРА ---
  bool _isDrawingBanner = false;
  List<List<Offset>> _bannerStrokes = [];
  List<Offset> _currentStroke = [];

  bool get isMyProfile => widget.targetUserId == null || widget.targetUserId == currentUser?.id;
  String get targetId => widget.targetUserId ?? currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFollowData(); 
  }

  Future<void> _loadUserData() async {
    if (isMyProfile) {
      final prefs = await SharedPreferences.getInstance();
      String defaultName = currentUser?.email?.split('@')[0] ?? "user";

      final metadata = currentUser?.userMetadata ?? {};

      setState(() {
        userName = metadata['userName'] ?? prefs.getString('userName') ?? defaultName;
        userHandle = "@${metadata['userHandle'] ?? prefs.getString('userHandle') ?? defaultName.toLowerCase()}";
        userEmoji = metadata['userEmoji'] ?? prefs.getString('userEmoji') ?? "😘";
        userBio = metadata['userBio'] ?? prefs.getString('userBio') ?? "";
      });

      // Загрузка локально сохраненного баннера
      final bannerData = metadata['bannerData'] ?? prefs.getString('bannerData');
      if (bannerData != null) {
        _parseBannerData(bannerData);
      }
    } else {
      try {
        // Запрашиваем все поля, включая banner_data (Вам нужно добавить эту колонку в БД!)
        final res = await supabase
            .from('profiles')
            .select('*')
            .eq('id', widget.targetUserId!)
            .maybeSingle();

        if (res != null && mounted) {
          setState(() {
            userName = res['username'] ?? "Пользователь";
            userHandle = "@${userName.toLowerCase().replaceAll(' ', '_')}";
            userEmoji = res['emoji'] ?? "👤";
            userBio = "";
          });

          // Пытаемся загрузить баннер, если колонка существует и не пустая
          if (res.containsKey('banner_data') && res['banner_data'] != null) {
            _parseBannerData(res['banner_data']);
          }
          return;
        }
      } catch (_) {}

      final userPosts = widget.allPosts.where((p) => p.userId == widget.targetUserId).toList();
      if (mounted) {
        setState(() {
          if (userPosts.isNotEmpty) {
            userName = userPosts.first.username;
            userHandle = "@${userName.toLowerCase().replaceAll(' ', '_')}";
            userEmoji = userPosts.first.userEmoji ?? "👤";
          } else {
            userName = "Пользователь";
            userHandle = "@user";
            userEmoji = "👤";
          }
          userBio = "";
        });
      }
    }
  }

  // Парсер JSON данных для линий баннера
  void _parseBannerData(dynamic bannerData) {
    try {
      final decoded = bannerData is String ? jsonDecode(bannerData) : bannerData;
      setState(() {
        _bannerStrokes = (decoded as List).map<List<Offset>>((stroke) {
          return (stroke as List).map<Offset>((point) {
            return Offset((point['dx'] as num).toDouble(), (point['dy'] as num).toDouble());
          }).toList();
        }).toList();
      });
    } catch (e) {
      print('Ошибка загрузки баннера: $e');
    }
  }

  // Сохранение нарисованного баннера
  Future<void> _saveBannerStrokes() async {
    setState(() => _isDrawingBanner = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Конвертируем List<List<Offset>> в JSON-совместимый формат
      final strokesJson = _bannerStrokes.map((stroke) => 
        stroke.map((p) => {'dx': p.dx, 'dy': p.dy}).toList()
      ).toList();
      
      final jsonString = jsonEncode(strokesJson);
      await prefs.setString('bannerData', jsonString);

      if (currentUser != null) {
        // Сохраняем в метаданные auth
        await supabase.auth.updateUser(
          UserAttributes(data: {'bannerData': jsonString})
        );
        // Пытаемся сохранить в таблицу profiles (если колонка banner_data добавлена)
        try {
          await supabase.from('profiles').update({'banner_data': jsonString}).eq('id', currentUser!.id);
        } catch (dbError) {
          print('Добавьте колонку banner_data (text) в таблицу profiles, чтобы баннер видели другие: $dbError');
        }
      }
    } catch (e) {
      print('Ошибка сохранения баннера: $e');
    }
  }

  Future<void> _loadFollowData() async {
    if (targetId.isEmpty) return;

    try {
      final data = await supabase
          .from('followers')
          .select('follower_id')
          .eq('following_id', targetId);

      if (mounted) {
        setState(() {
          followersCount = (data as List).length;
          if (currentUser != null) {
            isFollowing = data.any((row) => row['follower_id'] == currentUser!.id);
          }
        });
      }
    } catch (e) {
      print('Ошибка загрузки подписчиков: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (currentUser == null) return;
    
    final wasFollowing = isFollowing;
    
    setState(() {
      isFollowing = !isFollowing;
      followersCount += isFollowing ? 1 : -1;
    });

    try {
      if (wasFollowing) {
        await supabase
            .from('followers')
            .delete()
            .eq('follower_id', currentUser!.id)
            .eq('following_id', targetId);
      } else {
        await supabase
            .from('followers')
            .insert({
          'follower_id': currentUser!.id,
          'following_id': targetId,
        });
      }
    } catch (e) {
      print('Ошибка при подписке: $e');
      if (mounted) {
        setState(() {
          isFollowing = wasFollowing;
          followersCount += isFollowing ? 1 : -1;
        });
      }
    }
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> jsonPosts = widget.allPosts.map((p) => jsonEncode({
      'text': p.text, 'imagePath': p.imagePath, 'fileName': p.fileName,
      'mediaType': p.mediaType.index, 'pollOptions': p.pollOptions,
      'pollVotes': p.pollVotes, 'votedOptionIndex': p.votedOptionIndex,
      'likesCount': p.likesCount, 'isLiked': p.isLiked, 'comments': p.comments,
    })).toList();
    await prefs.setStringList('saved_posts_json', jsonPosts);
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => SettingsDialog(
        currentEmoji: userEmoji ?? "😘",
        currentName: userName,
        currentHandle: userHandle.replaceAll('@', ''),
        currentBio: userBio,
      ),
    ).then((_) => _loadUserData()); 
  }

  // ── ВЫХОД ИЗ АККАУНТА ───────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Выйти из аккаунта?', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        content: Text('Вы уверены, что хотите выйти?', style: TextStyle(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка выхода: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    List<Post> userSpecificPosts = widget.allPosts
        .where((p) => p.userId != null && p.userId == targetId)
        .toList();
    List<Post> likedPosts = widget.allPosts.where((p) => p.isLiked).toList();
    
    List<Post> displayList = (isMyProfile && _showLikes) ? likedPosts : userSpecificPosts;

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Container(
          color: AppColors.bg, 
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 250,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // --- ОБЛАСТЬ РИСОВАНИЯ БАННЕРА ---
                    GestureDetector(
                      onPanStart: _isDrawingBanner ? (details) {
                        setState(() {
                          _currentStroke = [details.localPosition];
                          _bannerStrokes.add(_currentStroke);
                        });
                      } : null,
                      onPanUpdate: _isDrawingBanner ? (details) {
                        setState(() {
                          _currentStroke.add(details.localPosition);
                        });
                      } : null,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: CustomPaint(
                          painter: BannerPainter(
                            strokes: _bannerStrokes,
                            strokeColor: Colors.blueAccent, // Цвет рисунка
                          ),
                        ),
                      ),
                    ),

                    // --- КНОПКИ УПРАВЛЕНИЯ БАННЕРОМ ---
                    if (isMyProfile && !_isDrawingBanner)
                      Positioned(
                        top: 15, right: 15,
                        child: IconButton(
                          icon: const Icon(Icons.brush, color: Colors.grey),
                          onPressed: () => setState(() => _isDrawingBanner = true),
                          tooltip: 'Нарисовать свой баннер',
                        ),
                      ),
                      
                    if (isMyProfile && _isDrawingBanner)
                      Positioned(
                        top: 15, right: 15,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.undo, color: Colors.white, size: 20),
                                tooltip: 'Шаг назад',
                                onPressed: () {
                                  setState(() {
                                    if (_bannerStrokes.isNotEmpty) {
                                      _bannerStrokes.removeLast();
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.greenAccent, size: 20),
                                tooltip: 'Сохранить',
                                onPressed: _saveBannerStrokes,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                tooltip: 'Отмена',
                                onPressed: () {
                                  setState(() => _isDrawingBanner = false);
                                  _loadUserData(); // Сбрасываем несохраненные изменения
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 10,
                      left: 20,
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: AppColors.input,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.bg, width: 4),
                            ),
                            child: Center(
                              child: Text(userEmoji ?? "😘", style: const TextStyle(fontSize: 50)),
                            ),
                          ),
                          Positioned(
                            bottom: 8, right: 8,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.bg, width: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // КНОПКА РЕДАКТИРОВАТЬ И КНОПКА ВЫХОДА
                    if (isMyProfile)
                      Positioned(
                        bottom: 15, right: 20,
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: _showSettingsDialog, 
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonBg,
                                foregroundColor: AppColors.buttonText,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('Редактировать', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(width: 8), 
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: AppColors.buttonBg, 
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                                onPressed: _signOut,
                                tooltip: 'Выйти из аккаунта',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(userName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                      ],
                    ),
                    Text(userHandle, style: TextStyle(color: AppColors.textSub, fontSize: 15)),
                    
                    if (userBio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(userBio, style: TextStyle(color: AppColors.text, fontSize: 14)),
                      ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('${userSpecificPosts.length}', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                        Text(' публикаций', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                        const SizedBox(width: 16),
                        Text('$followersCount', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                        Text(' подписчиков', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, color: AppColors.textSub, size: 14),
                        const SizedBox(width: 6),
                        Text('Регистрация: март 2026 г.', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (!isMyProfile)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? AppColors.input : Colors.blueAccent,
                                  foregroundColor: isFollowing ? AppColors.text : Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(isFollowing ? 'Отписаться' : 'Подписаться', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => MessagesScreen(
                                    initialChat: ChatItem(
                                      id: targetId,
                                      name: userName,
                                      avatarColor: Colors.blueAccent,
                                      emoji: userEmoji ?? '👤',
                                    ),
                                  )));
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.input,
                                  foregroundColor: AppColors.text,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Сообщение', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (isMyProfile)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _showLikes = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: !_showLikes ? AppColors.input : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text('Посты', style: TextStyle(color: !_showLikes ? AppColors.text : AppColors.textSub, fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _showLikes = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: _showLikes ? AppColors.input : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text('Лайки', style: TextStyle(color: _showLikes ? AppColors.text : AppColors.textSub, fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else 
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text('Публикации пользователя', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold))),
                      ),
                      
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              if (displayList.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 40),
                  child: Center(
                    child: Text('Нет постов', style: TextStyle(color: AppColors.textSub, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                ...displayList.map((post) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: PostCard(
                    post: post,
                    currentUserId: currentUser?.id,
                    onPostTap: widget.onPostTap != null
                        ? () => widget.onPostTap!(post)
                        : null,
                    onLike: () {
                      if (widget.onLike != null) {
                        widget.onLike!(post);
                        setState(() {});
                      }
                    },
                    onDelete: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(post);
                      }
                    },
                    onEdit: () {
                      if (widget.onEdit != null) {
                        widget.onEdit!(post);
                      }
                    },
                    onComment: widget.onPostTap != null
                        ? () => widget.onPostTap!(post)
                        : () {},
                    onVote: (int index) {
                      if (widget.onVote != null) {
                        widget.onVote!(post, index);
                        setState(() {});
                      } else {
                        setState(() { _savePosts(); });
                      }
                    },
                    onProfileTap: () {},
                  ),
                )),
                const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }
}

// --- КЛАСС ОТРИСОВЩИКА ХОЛСТА ---
class BannerPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color strokeColor;

  BannerPainter({required this.strokes, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BannerPainter oldDelegate) => true;
}

// Внизу оставляем класс SettingsDialog без изменений (он такой же, как в вашем исходнике)
class SettingsDialog extends StatefulWidget {
  final String currentEmoji;
  final String currentName;
  final String currentHandle;
  final String currentBio;

  const SettingsDialog({
    super.key, 
    required this.currentEmoji, 
    required this.currentName, 
    required this.currentHandle,
    required this.currentBio
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  String activeCategory = "Аккаунт";
  
  bool onlineStatus = true;
  String wallPrivacy = 'Все';
  String likesPrivacy = 'Все';

  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _handleController = TextEditingController(text: widget.currentHandle);
    _bioController = TextEditingController(text: widget.currentBio);

    _loadPrivacySettings();
  }

  void _loadPrivacySettings() {
    final metadata = supabase.auth.currentUser?.userMetadata ?? {};
    setState(() {
      onlineStatus = metadata['onlineStatus'] ?? true;
      wallPrivacy = metadata['wallPrivacy'] ?? 'Все';
      likesPrivacy = metadata['likesPrivacy'] ?? 'Все';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final handle = _handleController.text.trim();
      final bio = _bioController.text.trim();

      if (name.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Имя не может быть пустым'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }
      if (handle.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username не может быть пустым'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final oldName = prefs.getString('userName') ?? supabase.auth.currentUser?.email?.split('@')[0]; 

      await prefs.setString('userName', name);
      await prefs.setString('userHandle', handle);
      await prefs.setString('userBio', bio);
      
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'userName': name,
            'userHandle': handle,
            'userBio': bio,
            'onlineStatus': onlineStatus,
            'wallPrivacy': wallPrivacy,
            'likesPrivacy': likesPrivacy,
          },
        ),
      );

      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('profiles').upsert({
          'id': userId,
          'username': name,
          'emoji': widget.currentEmoji,
        });

        await supabase.from('posts').update({
          'username': name,
          'user_emoji': widget.currentEmoji 
        }).eq('user_id', userId);
        
        if (oldName != null && oldName != name) {
          await supabase.from('likes').update({'username': name}).eq('username', oldName);
          await supabase.from('comments').update({'username': name}).eq('username', oldName);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль успешно обновлен!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _changePassword() {
    TextEditingController passController = TextEditingController();
    TextEditingController passConfirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Сменить пароль', style: TextStyle(color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passController,
              obscureText: true,
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Новый пароль',
                hintStyle: TextStyle(color: AppColors.textSub),
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passConfirmController,
              obscureText: true,
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Повторите пароль',
                hintStyle: TextStyle(color: AppColors.textSub),
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(child: const Text('Отмена', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              if (passController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль должен быть минимум 6 символов')));
                return;
              }
              if (passController.text != passConfirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароли не совпадают')));
                return;
              }
              
              Navigator.pop(ctx); 
              setState(() => _isLoading = true);

              try {
                await supabase.auth.updateUser(UserAttributes(password: passController.text));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль успешно изменен!'), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
              } finally {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePrivacySetting(String key, dynamic value) async {
    try {
      await supabase.auth.updateUser(UserAttributes(data: {key: value}));
    } catch (e) {
      print('Ошибка обновления приватности: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: isMobile ? double.infinity : 800,
              height: isMobile ? MediaQuery.of(context).size.height * 0.85 : 550,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
                  
                  if (_isLoading)
                    Container(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
                      child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                    ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: AppColors.sidebar,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
              ),
              _menuItem(Icons.person_outline, "Аккаунт", isMobile: false),
              _menuItem(Icons.security_outlined, "Безопасность", isMobile: false),
              _menuItem(Icons.lock_outline, "Приватность", isMobile: false),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textSub, size: 28),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _buildRightContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: AppColors.textSub),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _menuItem(Icons.person_outline, "Аккаунт", isMobile: true),
              _menuItem(Icons.security_outlined, "Безопасность", isMobile: true),
              _menuItem(Icons.lock_outline, "Приватность", isMobile: true),
            ],
          ),
        ),
        Divider(color: AppColors.border, height: 30),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: _buildRightContent(),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, {required bool isMobile}) {
    bool isSelected = activeCategory == title;
    
    if (isMobile) {
      return GestureDetector(
        onTap: () => setState(() => activeCategory = title),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected ? (AppColors.isDark ? Colors.white10 : Colors.black12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? AppColors.text : AppColors.textSub, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: isSelected ? AppColors.text : AppColors.textSub, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      );
    }

    return ListTile(
      onTap: () => setState(() => activeCategory = title),
      leading: Icon(icon, color: isSelected ? AppColors.text : AppColors.textSub, size: 22),
      title: Text(title, style: TextStyle(color: isSelected ? AppColors.text : AppColors.textSub, fontSize: 14)),
      tileColor: isSelected ? (AppColors.isDark ? Colors.white10 : Colors.black12) : Colors.transparent,
    );
  }

  Widget _buildRightContent() {
    switch (activeCategory) {
      case "Аккаунт": return _buildAccount();
      case "Безопасность": return _buildSecurity();
      case "Приватность": return _buildPrivacy();
      default: return const SizedBox();
    }
  }

  Widget _buildAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (MediaQuery.of(context).size.width >= 700) ...[
          Text('Аккаунт', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 30),
        ],
        _rowStatic('Эмоджи-клан', widget.currentEmoji, sub: 'Выбран при регистрации. Изменить нельзя'),
        _editableRow('Имя', _nameController),
        _editableRow('Username', _handleController),
        const SizedBox(height: 10),
        Text('О себе', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _bioController,
          maxLines: 3,
          style: TextStyle(fontSize: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'Напиши что-нибудь о себе...',
            hintStyle: TextStyle(color: AppColors.textSub, fontSize: 14),
            filled: true,
            fillColor: AppColors.input,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Сохранить изменения', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity() {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          Text('Безопасность', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 30),
        ],
        isMobile 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Пароль', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                Text('Изменить пароль от аккаунта', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _changePassword,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText),
                    child: const Text('Сменить пароль'),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Пароль', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  Text('Изменить пароль от аккаунта', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                ]),
                ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText),
                  child: const Text('Сменить пароль'),
                ),
              ],
            ),
      ],
    );
  }

  Widget _buildPrivacy() {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          Text('Приватность', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 30),
        ],
        
        _interactiveDropdownRow('Стена', 'Кто может писать на вашей стене', wallPrivacy, ['Все', 'Друзья', 'Только я'], (val) {
          setState(() => wallPrivacy = val);
          _updatePrivacySetting('wallPrivacy', val);
        }),
        _interactiveDropdownRow('Лайки', 'Кто может видеть ваши лайкнутые посты', likesPrivacy, ['Все', 'Друзья', 'Только я'], (val) {
          setState(() => likesPrivacy = val);
          _updatePrivacySetting('likesPrivacy', val);
        }),
        
        Divider(height: 40, color: AppColors.border),
        
        isMobile 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Онлайн-статус', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                    Switch(value: onlineStatus, activeThumbColor: Colors.blueAccent, onChanged: (v) {
                      setState(() => onlineStatus = v);
                      _updatePrivacySetting('onlineStatus', v);
                    }),
                  ],
                ),
                Text('Показывать время последнего визита', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Онлайн-статус', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  Text('Показывать время последнего визита', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                ]),
                Switch(value: onlineStatus, activeThumbColor: Colors.blueAccent, onChanged: (v) {
                  setState(() => onlineStatus = v);
                  _updatePrivacySetting('onlineStatus', v);
                }),
              ],
            ),
            
        const SizedBox(height: 30),
        Text('ЧЁРНЫЙ СПИСОК', style: TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Center(child: Text('Чёрный список пуст', style: TextStyle(color: AppColors.textSub))),
      ],
    );
  }

  Widget _rowStatic(String label, String val, {String? sub}) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            if (sub != null) Text(sub, style: TextStyle(color: AppColors.textSub, fontSize: 11)),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontSize: 24))
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
              if (sub != null) Text(sub, style: TextStyle(color: AppColors.textSub, fontSize: 11)),
            ]),
          ),
          Text(val, style: const TextStyle(fontSize: 24))
        ],
      ),
    );
  }

  Widget _editableRow(String label, TextEditingController controller) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    Widget inputField = SizedBox(
      width: isMobile ? double.infinity : 200,
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.input,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            inputField,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
          inputField,
        ],
      ),
    );
  }

  Widget _interactiveDropdownRow(String title, String sub, String currentValue, List<String> options, Function(String) onChanged) {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    Widget dropdownWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          dropdownColor: AppColors.card,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSub),
          style: TextStyle(color: AppColors.text, fontSize: 14),
          onChanged: (String? newValue) {
            if (newValue != null) onChanged(newValue);
          },
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            Text(sub, style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: dropdownWidget),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
              Text(sub, style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            ]),
          ),
          dropdownWidget,
        ],
      ),
    );
  }
}