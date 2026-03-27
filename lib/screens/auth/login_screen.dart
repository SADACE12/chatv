import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/main_layout.dart';
import 'register_screen.dart';
import '../../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, заполните все поля')));
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите корректный E-Mail')));
      return;
    }

    // Сохраняем в память, что мы вошли
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: AppColors.bg, // Адаптивный фон
          
          // Прозрачная шапка для кнопки смены темы
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: AppColors.text),
                onPressed: () => AppColors.toggleTheme(),
              ),
              const SizedBox(width: 16),
            ],
          ),

          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ChatV', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 40),
                    Text('Вход', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text('Пожалуйста, введите ваши данные', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                    const SizedBox(height: 30),
                    
                    Text('E-Mail', style: TextStyle(color: AppColors.text, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _emailController, hint: 'Almas@gmail.com'),
                    
                    const SizedBox(height: 20),
                    Text('Пароль', style: TextStyle(color: AppColors.text, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hint: '••••••••••••',
                      isPassword: true,
                      obscure: _obscurePassword,
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(foregroundColor: AppColors.textSub),
                        child: const Text('Забыли пароль?', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonBg,
                        foregroundColor: AppColors.buttonText,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Войти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Еще нет аккаунта? ', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                          },
                          child: const Text('Создать аккаунт', style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, bool isPassword = false, bool obscure = false, VoidCallback? onToggleVisibility}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSub),
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSub),
                onPressed: onToggleVisibility,
              )
            : null,
      ),
    );
  }
}