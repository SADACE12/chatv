import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  late TabController _tabController;

  int totalUsers = 0;
  int totalPosts = 0;
  int totalMessages = 0;
  int bannedUsers = 0;

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStats();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      filteredUsers = allUsers.where((u) {
        final name = (u['username'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    });
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final usersRes = await supabase
          .from('profiles')
          .select('*')
          .order('username', ascending: true);

      final postsRes = await supabase.from('posts').select('id');
      final msgsRes = await supabase.from('messages').select('id');

      final users = List<Map<String, dynamic>>.from(usersRes);

      if (mounted) {
        setState(() {
          allUsers = users;
          filteredUsers = users;
          totalUsers = users.length;
          bannedUsers = users.where((u) => u['is_banned'] == true).length;
          totalPosts = (postsRes as List).length;
          totalMessages = (msgsRes as List).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Admin Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final isBanned = user['is_banned'] == true;
    try {
      await supabase
          .from('profiles')
          .update({'is_banned': !isBanned}).eq('id', user['id']);
      _showSnack(
        isBanned ? '✅ Пользователь разбанен' : '🚫 Пользователь заблокирован',
        isBanned ? Colors.greenAccent : Colors.orangeAccent,
      );
      await _fetchStats();
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.redAccent);
    }
  }

  Future<void> _deleteUserPosts(String userId) async {
    try {
      await supabase.from('posts').delete().eq('user_id', userId);
      _showSnack('🗑️ Посты удалены', Colors.orangeAccent);
      await _fetchStats();
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.redAccent);
    }
  }

  Future<void> _deleteAccount(String userId) async {
  try {
    await supabase.rpc('delete_user_by_id', params: {'user_id': userId});
    _showSnack('💀 Аккаунт удалён', Colors.redAccent);
    await _fetchStats();
  } catch (e) {
    _showSnack('Ошибка: $e', Colors.redAccent);
  }
}

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final isAdmin = user['role'] == 'admin';
    try {
      await supabase
          .from('profiles')
          .update({'role': isAdmin ? 'user' : 'admin'}).eq('id', user['id']);
      _showSnack(
        isAdmin ? '👤 Роль изменена на USER' : '🛡️ Роль изменена на ADMIN',
        Colors.blueAccent,
      );
      await _fetchStats();
    } catch (e) {
      _showSnack('Ошибка: $e', Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SYSTEM CONTROL',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Colors.redAccent,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchStats,
            icon: const Icon(Icons.sync, color: Colors.blueAccent),
          ),
          const SizedBox(width: 10),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.redAccent,
          labelColor: Colors.redAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: 'USERS'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
              ],
            ),
    );
  }

  // ─── TAB 1: Overview ───────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _statCard('USERS', totalUsers.toString(), Icons.person_search, Colors.blueAccent)),
            const SizedBox(width: 15),
            Expanded(child: _statCard('POSTS', totalPosts.toString(), Icons.auto_awesome_motion, Colors.orangeAccent)),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _statCard('CHATS', totalMessages.toString(), Icons.forum_rounded, Colors.greenAccent)),
            const SizedBox(width: 15),
            Expanded(child: _statCard('BANNED', bannedUsers.toString(), Icons.block, Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 30),
        _sectionLabel('QUICK ACTIONS'),
        const SizedBox(height: 12),
        _quickActions(),
      ],
    ),
  );
}

  Widget _quickActions() {
    return Column(
      children: [
        _actionTile(
          icon: Icons.sync,
          color: Colors.blueAccent,
          title: 'Обновить данные',
          subtitle: 'Перезагрузить всю статистику',
          onTap: _fetchStats,
        ),
        const SizedBox(height: 10),
        _actionTile(
          icon: Icons.people_alt_rounded,
          color: Colors.purpleAccent,
          title: 'Перейти к пользователям',
          subtitle: 'Управление аккаунтами',
          onTap: () => _tabController.animateTo(1),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: Users ──────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search,
                  color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF111111),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filteredUsers.length} пользователей',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final bool isAdmin = user['role'] == 'admin';
              final bool isBanned = user['is_banned'] == true;
              return _userTile(user, isAdmin, isBanned);
            },
          ),
        ),
      ],
    );
  }

  // ─── Shared widgets ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 1.2),
      );

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(icon, size: 60, color: color.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTile(
      Map<String, dynamic> user, bool isAdmin, bool isBanned) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: isBanned
            ? Border.all(color: Colors.redAccent.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle),
              child: Center(
                  child: Text(user['emoji'] ?? '👤',
                      style: const TextStyle(fontSize: 22))),
            ),
            if (isBanned)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.block,
                      size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          user['username'] ?? 'No Name',
          style: TextStyle(
              color: isBanned ? Colors.white38 : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
        subtitle: Text(
          user['id'].toString().length > 8
              ? "${user['id'].toString().substring(0, 8)}..."
              : user['id'].toString(),
          style:
              const TextStyle(color: Colors.white24, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _roleBadge(isAdmin, isBanned),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white10),
          ],
        ),
        onTap: () => _showUserOptions(user, isAdmin, isBanned),
      ),
    );
  }

  Widget _roleBadge(bool isAdmin, bool isBanned) {
    if (isBanned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: Colors.redAccent.withOpacity(0.3)),
        ),
        child: const Text('BANNED',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? Colors.redAccent.withOpacity(0.1)
            : Colors.white10,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isAdmin
                ? Colors.redAccent.withOpacity(0.3)
                : Colors.transparent),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'USER',
        style: TextStyle(
            color: isAdmin ? Colors.redAccent : Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showUserOptions(
      Map<String, dynamic> user, bool isAdmin, bool isBanned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(user['emoji'] ?? '👤',
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['username'] ?? 'No Name',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(isAdmin ? 'Administrator' : 'User',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ListTile(
            leading: Icon(
              isAdmin ? Icons.person : Icons.admin_panel_settings,
              color: Colors.blueAccent,
            ),
            title: Text(
              isAdmin ? 'Снять права админа' : 'Назначить админом',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _changeRole(user);
            },
          ),
          ListTile(
            leading: Icon(
              isBanned ? Icons.lock_open : Icons.block,
              color: Colors.orangeAccent,
            ),
            title: Text(
              isBanned ? 'Разбанить' : 'Заблокировать',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _toggleBan(user);
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_delete,
                color: Colors.orangeAccent),
            title: const Text('Удалить все посты',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _confirmDialog(
                title: 'Удалить посты?',
                message:
                    'Все посты пользователя ${user['username']} будут удалены.',
                onConfirm: () =>
                    _deleteUserPosts(user['id'].toString()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever,
                color: Colors.redAccent),
            title: const Text('Удалить аккаунт',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _confirmDialog(
                title: 'Удалить аккаунт?',
                message:
                    'Аккаунт ${user['username']} будет удалён навсегда.',
                onConfirm: () =>
                    _deleteAccount(user['id'].toString()),
                isDanger: true,
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDanger = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(
              'Подтвердить',
              style: TextStyle(
                  color: isDanger
                      ? Colors.redAccent
                      : Colors.blueAccent,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}