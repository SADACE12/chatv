import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_layout.dart';
import 'data/app_data.dart';

void main() async {
  // Обязательная строчка перед использованием SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  
  // Достаем данные из памяти браузера
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final userEmoji = prefs.getString('userEmoji');

  // Если пользователь уже залогинен и у него есть эмоджи - восстанавливаем клан
  if (isLoggedIn && userEmoji != null) {
    AppData.activeClans[userEmoji] = (AppData.activeClans[userEmoji] ?? 0) + 1;
  }

  runApp(ChatVApp(isLoggedIn: isLoggedIn));
}

class ChatVApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const ChatVApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ChatV',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      // Если в памяти есть данные о входе - сразу кидаем в ленту
      home: isLoggedIn ? const MainLayout() : const LoginScreen(), 
    );
  }
}