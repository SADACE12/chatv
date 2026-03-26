import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "AlmasGod";
  String userHandle = "@tamerlox";
  String? userEmoji;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Загружаем данные из памяти
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "AlmasGod";
      userHandle = "@${prefs.getString('userHandle') ?? "tamerlox"}";
      userEmoji = prefs.getString('userEmoji') ?? "😘";
    });
  }

  // Функция вызова окна настроек
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
    return Container(
      color: Colors.black,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Шапка профиля (высота 250 гарантирует кликабельность кнопки)
          SizedBox(
            height: 250,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
                          color: const Color(0xFF2A2A2A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 4),
                        ),
                        child: Center(
                          child: Text(userEmoji ?? "😘", style: const TextStyle(fontSize: 50)),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 15,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _showSettingsDialog, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
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

          // Основная информация
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                  ],
                ),
                Text(userHandle, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text('0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(' подписчиков', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    SizedBox(width: 16),
                    Text('0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(' подписок', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 14),
                    SizedBox(width: 6),
                    Text('Регистрация: март 2026 г.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 24),
                // Табы
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(10)),
                          child: const Center(child: Text('Посты', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      ),
                      const Expanded(child: Center(child: Text('Лайки', style: TextStyle(color: Colors.grey)))),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                const Center(
                  child: Text('Нет постов', style: TextStyle(color: Colors.white10, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ДИАЛОГ НАСТРОЕК (Только 3 раздела)
// ==========================================
class SettingsDialog extends StatefulWidget {
  final String currentEmoji;
  final String currentName;
  final String currentHandle;

  const SettingsDialog({
    super.key, 
    required this.currentEmoji, 
    required this.currentName, 
    required this.currentHandle
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  String activeCategory = "Аккаунт";
  bool onlineStatus = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 800,
        height: 550,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // МЕНЮ СЛЕВА (Аккаунт, Безопасность, Приватность)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: Color(0xFF161618),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  _menuItem(Icons.person_outline, "Аккаунт"),
                  _menuItem(Icons.security_outlined, "Безопасность"),
                  _menuItem(Icons.lock_outline, "Приватность"),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                    ),
                  ),
                ],
              ),
            ),
            // КОНТЕНТ СПРАВА
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: _buildRightContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title) {
    bool isSelected = activeCategory == title;
    return ListTile(
      onTap: () => setState(() => activeCategory = title),
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 22),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 14)),
      tileColor: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
    );
  }

  Widget _buildRightContent() {
    switch (activeCategory) {
      case "Аккаунт":
        return _buildAccount();
      case "Безопасность":
        return _buildSecurity();
      case "Приватность":
        return _buildPrivacy();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Аккаунт', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 30),
        _row('Эмоджи-клан', widget.currentEmoji, sub: 'Выбран при регистрации. Изменить нельзя'),
        _row('Имя', widget.currentName),
        _row('Username', widget.currentHandle),
        const SizedBox(height: 10),
        const Text('О себе', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Напиши что-нибудь о себе...',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Безопасность', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Пароль', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Изменить пароль от аккаунта', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            ElevatedButton(
              onPressed: () {}, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text('Сменить пароль')
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Приватность', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 30),
        _dropdownRow('Стена', 'Кто может писать на вашей стене', 'Все'),
        _dropdownRow('Лайки', 'Кто может видеть ваши лайкнутые посты', 'Все'),
        const Divider(height: 40, color: Colors.white10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Онлайн-статус', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Показывать время последнего визита', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            Switch(value: onlineStatus, activeColor: Colors.blueAccent, onChanged: (v) => setState(() => onlineStatus = v)),
          ],
        ),
        const SizedBox(height: 30),
        const Text('ЧЁРНЫЙ СПИСОК', style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        const Center(child: Text('Чёрный список пуст', style: TextStyle(color: Colors.white38))),
      ],
    );
  }

  Widget _row(String label, String val, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (sub != null) Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
          if (label == 'Эмоджи-клан') Text(val, style: const TextStyle(fontSize: 24))
          else Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)), child: Text(val, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _dropdownRow(String title, String sub, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Text(val, style: const TextStyle(color: Colors.white)), const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey)]),
          ),
        ],
      ),
    );
  }
}