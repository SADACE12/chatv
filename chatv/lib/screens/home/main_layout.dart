import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/post_model.dart';
import '../auth/login_screen.dart';
import '../../data/app_data.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final TextEditingController _postController = TextEditingController();
  List<Post> posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts(); // Загружаем посты при входе
  }

  // ЗАГРУЗКА ПОСТОВ ИЗ ПАМЯТИ
  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedPosts = prefs.getStringList('saved_posts');
    
    if (savedPosts != null) {
      setState(() {
        posts = savedPosts.map((text) => Post(
          username: 'Вы', // Убрали (User)
          avatarColor: Colors.orange,
          timeAgo: 'ранее',
          text: text,
        )).toList();
      });
    }
  }

  // СОХРАНЕНИЕ ПОСТОВ В ПАМЯТЬ
  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> postTexts = posts.map((p) => p.text).toList();
    await prefs.setStringList('saved_posts', postTexts);
  }

  void _publishPost() {
    if (_postController.text.trim().isEmpty) return;
    setState(() {
      posts.insert(0, Post(
        username: 'Вы', // Здесь тоже убрали (User)
        avatarColor: Colors.orange,
        timeAgo: 'только что',
        text: _postController.text,
      ));
      _postController.clear();
      _savePosts(); // Сохраняем после публикации
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
            const Expanded(flex: 2, child: LeftSidebarContent()),

          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFF000000),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: isMobile ? screenWidth : 700, 
                  child: ListView(
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
                          child: Center(
                            child: Text(
                              'Здесь пока пусто. Опубликуйте первый пост!',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        )
                      else
                        ...posts.map((post) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(post: post),
                        )),
                    ],
                  ),
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
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
      ) : null,
    );
  }

  Widget _buildCreatePostField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(backgroundColor: Colors.orange, radius: 18, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _postController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Что нового?',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.image_outlined, color: Colors.grey, size: 22),
                  SizedBox(width: 16),
                  Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 22),
                  SizedBox(width: 16),
                  Icon(Icons.poll_outlined, color: Colors.grey, size: 22),
                ],
              ),
              ElevatedButton(
                onPressed: _publishPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Опубликовать', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class ClanEmojisPanel extends StatelessWidget {
  const ClanEmojisPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppData.activeClans.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Map<String, dynamic>> activeClans = AppData.activeClans.entries
        .map((e) => {'emoji': e.key, 'count': e.value})
        .toList();
    
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        clan['emoji'], 
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${clan['count']} чел.', 
                    style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
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
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: post.avatarColor, radius: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(post.timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.text, style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.favorite_border, size: 20, color: Colors.grey),
              SizedBox(width: 6),
              Text('0', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 20),
              Icon(Icons.mode_comment_outlined, size: 20, color: Colors.grey),
              SizedBox(width: 6),
              Text('0', style: TextStyle(color: Colors.grey)),
              Spacer(),
              Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.grey),
              SizedBox(width: 6),
              Text('1', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class LeftSidebarContent extends StatelessWidget {
  const LeftSidebarContent({super.key});

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
          
          _item(Icons.person_outline, 'Профиль'),
          _item(Icons.feed, 'Лента', active: true),
          _item(Icons.search, 'Поиск'),
          _item(Icons.notifications_none, 'Уведомления'),
          
          const Spacer(),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              AppData.activeClans.clear();

              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, {bool active = false, Color? color}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon, color: color ?? (active ? Colors.white : Colors.grey)),
      title: Text(title, style: TextStyle(color: color ?? (active ? Colors.white : Colors.grey), fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: active ? const Color(0xFF1E1E1E) : Colors.transparent,
      onTap: () {},
    );
  }
}

class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Вакансии', style: TextStyle(color: Colors.grey, fontSize: 13)),
          SizedBox(height: 12),
          Text('Конфиденциальность', style: TextStyle(color: Colors.grey, fontSize: 13)),
          SizedBox(height: 12),
          Text('© 2026 ChatV', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
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
      child: Row(
        children: [
          _t('Для вас', true),
          _t('Подписки', false),
        ],
      ),
    );
  }

  Widget _t(String text, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF333333) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.grey, fontSize: 13))),
      ),
    );
  }
}