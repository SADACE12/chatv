import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Убедись, что путь к экрану логина совпадает с твоей структурой папок.
// Если у тебя пока нет LoginScreen, можешь заменить его на MainLayout.
import 'screens/auth/login_screen.dart';

void main() async {
  // Эта строка обязательна, если мы делаем что-то асинхронное до запуска приложения
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация базы данных Supabase с твоими ключами
  await Supabase.initialize(
    url: 'https://cyoupnpoobemnozqcfen.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN5b3VwbnBvb2JlbW5venFjZmVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3MjYyMjYsImV4cCI6MjA5MTMwMjIyNn0.wBPVNPY0_6q_w766f-GsLeWzoja3qSOjiQeYlPijix4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatV',
      debugShowCheckedModeBanner:
          false, // Убираем красную плашку "DEBUG" справа сверху
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black, // Ставим черный фон по умолчанию
      ),
      // Стартовый экран. Если хочешь сразу тестировать чат без ввода логина/пароля,
      // можешь поменять LoginScreen() на MainLayout()
      home: const LoginScreen(),
    );
  }
}
