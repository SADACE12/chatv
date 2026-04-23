import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../../theme/app_colors.dart';
import '../../models/post_model.dart';
import 'main_layout.dart';
import 'messages_screen.dart'; // НОВОЕ: Переходим к сообщениям через общий класс

class ProfileScreen extends StatefulWidget {
  final List<Post> allPosts; 
  final String? targetUserId; 

  const ProfileScreen({super.key, required this.allPosts, this.targetUserId});

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

      setState(() {
        userName = prefs.getString('userName') ?? defaultName;
        userHandle = "@${prefs.getString('userHandle') ?? defaultName.toLowerCase()}";
        userEmoji = prefs.getString('userEmoji') ?? "😘";
        userBio = prefs.getString('userBio') ?? "";
      });
    } else {
      final userPosts = widget.allPosts.where((p) => p.userId == widget.targetUserId).toList();
      setState(() {
        if (userPosts.isNotEmpty) {
          userName = userPosts.first.username;
          userHandle = "@${userName.toLowerCase().replaceAll(' ', '_')}";
        } else {
          userName = "Пользователь";
          userHandle = "@user";
        }
        userEmoji = "👤"; 
        userBio = ""; 
      });
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

  @override
  Widget build(BuildContext context) {
    List<Post> userSpecificPosts = widget.allPosts.where((p) => p.userId != null && p.userId == targetId).toList();
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
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
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
                    if (isMyProfile)
                      Positioned(
                        bottom: 15, right: 20,
                        child: ElevatedButton(
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
                    
                    // Кнопки Подписаться и Написать (для чужого профиля)
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
                                  // НОВОЕ: Передаем данные в MessagesScreen
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
                    onLike: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Лайки лучше ставить в общей ленте')));
                    },
                    onDelete: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Удаление доступно в основной ленте')));
                    }, 
                    onEdit: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Редактирование доступно в основной ленте')));
                    },
                    onComment: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Перейдите в ленту, чтобы оставить комментарий')));
                    }, 
                    onVote: () => setState(() { _savePosts(); }), 
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

// ==========================================
// АДАПТИВНЫЙ ДИАЛОГ НАСТРОЕК
// ==========================================
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
  String activeCategory = "Аккаунт";
  bool onlineStatus = true;

  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _handleController = TextEditingController(text: widget.currentHandle);
    _bioController = TextEditingController(text: widget.currentBio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text.trim());
    await prefs.setString('userHandle', _handleController.text.trim());
    await prefs.setString('userBio', _bioController.text.trim());
    
    if (mounted) Navigator.pop(context);
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
              child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
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
                padding: const EdgeInsets.all(16.0),
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
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: AppColors.textSub)),
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
                  child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText), child: const Text('Сменить пароль')),
                )
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Пароль', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                  Text('Изменить пароль от аккаунта', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                ]),
                ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.buttonText), child: const Text('Сменить пароль')),
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
        _dropdownRow('Стена', 'Кто может писать на вашей стене', 'Все'),
        _dropdownRow('Лайки', 'Кто может видеть ваши лайкнутые посты', 'Все'),
        Divider(height: 40, color: AppColors.border),
        
        isMobile 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Онлайн-статус', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                    Switch(value: onlineStatus, activeThumbColor: Colors.blueAccent, onChanged: (v) => setState(() => onlineStatus = v)),
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
                Switch(value: onlineStatus, activeThumbColor: Colors.blueAccent, onChanged: (v) => setState(() => onlineStatus = v)),
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

  Widget _dropdownRow(String title, String sub, String val) {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            Text(sub, style: TextStyle(color: AppColors.textSub, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(val, style: TextStyle(color: AppColors.text)), Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSub)]),
            ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Text(val, style: TextStyle(color: AppColors.text)), const SizedBox(width: 8), Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSub)]),
          ),
        ],
      ),
    );
  }
}