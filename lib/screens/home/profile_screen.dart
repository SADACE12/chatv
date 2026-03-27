import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../theme/app_colors.dart';
import '../../models/post_model.dart';
import 'main_layout.dart'; // Нужен для доступа к PostCard

class ProfileScreen extends StatefulWidget {
  final List<Post> allPosts; // Добавлено для получения постов из MainLayout

  const ProfileScreen({super.key, required this.allPosts});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "AlmasGod";
  String userHandle = "@tamerlox";
  String? userEmoji;
  bool _showLikes = false; // Переключатель Посты/Лайки

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "AlmasGod";
      userHandle = "@${prefs.getString('userHandle') ?? "tamerlox"}";
      userEmoji = prefs.getString('userEmoji') ?? "😘";
    });
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
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => SettingsDialog(
        currentEmoji: userEmoji ?? "😘",
        currentName: userName,
        currentHandle: userHandle.replaceAll('@', ''),
      ),
    ).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    // Фильтрация постов для отображения во вкладках
    List<Post> myPosts = widget.allPosts.where((p) => p.username == 'Вы').toList();
    List<Post> likedPosts = widget.allPosts.where((p) => p.isLiked).toList();
    List<Post> displayList = _showLikes ? likedPosts : myPosts;

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Container(
          color: AppColors.bg, // ДИНАМИЧЕСКИЙ ФОН
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('0', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                        Text(' подписчиков', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                        const SizedBox(width: 16),
                        Text('0', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                        Text(' подписок', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
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
                    
                    // ВКЛАДКИ: ПОСТЫ / ЛАЙКИ
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
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ОТРИСОВКА СПИСКА ПОСТОВ
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
                    onLike: () {
                      setState(() {
                        post.isLiked = !post.isLiked;
                        post.isLiked ? post.likesCount++ : post.likesCount--;
                        _savePosts();
                      });
                    },
                    onDelete: () {}, 
                    onEdit: () {},
                    onComment: () {},
                    onVote: () => setState(() { _savePosts(); }), 
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

  const SettingsDialog({super.key, required this.currentEmoji, required this.currentName, required this.currentHandle});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String activeCategory = "Аккаунт";
  bool onlineStatus = true;

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
          child: Container(
            width: isMobile ? double.infinity : 800,
            height: isMobile ? MediaQuery.of(context).size.height * 0.85 : 550,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(),
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
        _row('Эмоджи-клан', widget.currentEmoji, sub: 'Выбран при регистрации. Изменить нельзя'),
        _row('Имя', widget.currentName),
        _row('Username', widget.currentHandle),
        const SizedBox(height: 10),
        Text('О себе', style: TextStyle(color: AppColors.textSub, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
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
                    Switch(value: onlineStatus, activeColor: Colors.blueAccent, onChanged: (v) => setState(() => onlineStatus = v)),
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
                Switch(value: onlineStatus, activeColor: Colors.blueAccent, onChanged: (v) => setState(() => onlineStatus = v)),
              ],
            ),
            
        const SizedBox(height: 30),
        Text('ЧЁРНЫЙ СПИСОК', style: TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Center(child: Text('Чёрный список пуст', style: TextStyle(color: AppColors.textSub))),
      ],
    );
  }

  Widget _row(String label, String val, {String? sub}) {
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
            if (label == 'Эмоджи-клан') 
              Text(val, style: const TextStyle(fontSize: 24))
            else 
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(10)), child: Text(val, style: TextStyle(color: AppColors.text))),
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
          if (label == 'Эмоджи-клан') Text(val, style: const TextStyle(fontSize: 24))
          else Container(width: 200, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(10)), child: Text(val, style: TextStyle(color: AppColors.text))),
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