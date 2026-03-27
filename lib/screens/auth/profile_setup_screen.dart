import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/main_layout.dart';
import '../../data/app_data.dart';
import '../../theme/app_colors.dart'; // Подключаем тему

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 1; 
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedEmoji;

  final List<String> _emojis = [
    '😀', '😁', '😂', '🤣', '😃', '😄', '😅', '😆', '😉', '😊', 
    '😋', '😎', '😍', '😘', '🥰', '😗', '😙', '😚', '🙂', '🤗', 
    '🤩', '🤔', '🤨', '😐', '😑', '😶', '🙄', '😏', '😣', '😥', 
    '😮', '🤐', '😯', '😪', '😫', '😴', '😌', '😛', '😜', '😝', 
    '🤤', '😒', '😓', '😔', '😕', '🙃', '🤑', '😲', '☹️', '🙁', 
    '😤', '😢', '😭', '😦', '😧', '😨', '😩', '🤯', '😬', '😰', 
    '😱', '🥵', '🥶', '😳', '🤪', '😵', '😡', '😠', '🤬', '😷', 
    '😈', '👿', '👹', '👺', '💀', '👻', '👽', '👾', '🤖', '💩',
    '🤡', '👾', '🚀', '⭐', '🎈', '🦊', '🐱', '🐼', '🐸', '🐢'
  ];

  void _nextStep() {
    if (_nameController.text.isNotEmpty && _usernameController.text.isNotEmpty) {
      setState(() {
        _currentStep = 2;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
    }
  }

  void _finishSetup() async {
    if (_selectedEmoji != null) {
      final prefs = await SharedPreferences.getInstance();
      
      // СОХРАНЯЕМ ВСЕ ДАННЫЕ В ПАМЯТЬ
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmoji', _selectedEmoji!);
      await prefs.setString('userName', _nameController.text.trim());
      await prefs.setString('userHandle', _usernameController.text.trim());

      // Обновляем локальную статистику кланов
      AppData.activeClans[_selectedEmoji!] = (AppData.activeClans[_selectedEmoji!] ?? 0) + 1;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите свой эмоджи-клан')),
      );
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card, // Адаптивный фон шторки
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Выберите эмоджи', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _emojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = _emojis[index];
                        });
                        Navigator.pop(context);
                      },
                      child: Center(
                        child: Text(_emojis[index], style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.text), // Цвет стрелки "назад"
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Настройка профиля', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text('Пожалуйста, укажите данные профиля', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
                    const SizedBox(height: 30),
                    
                    _buildProgressBar(),
                    const SizedBox(height: 40),

                    _currentStep == 1 ? _buildStep1() : _buildStep2(),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blueAccent,
          child: Text('1', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep == 2 ? Colors.blueAccent : AppColors.border,
          ),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: _currentStep == 2 ? Colors.blueAccent : AppColors.input,
          child: Text('2', style: TextStyle(color: _currentStep == 2 ? Colors.white : AppColors.textSub, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Имя', style: TextStyle(color: AppColors.text, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Как тебя будут видеть другие пользователи', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
        const SizedBox(height: 12),
        _buildTextField(controller: _nameController, hint: 'Алмас'),
        
        const SizedBox(height: 24),
        
        Text('Username', style: TextStyle(color: AppColors.text, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Уникальный никнейм для твоего профиля\n(латиница, цифры, и "_")', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
        const SizedBox(height: 12),
        _buildTextField(controller: _usernameController, hint: 'zxcAlmas'),
        
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonBg,
            foregroundColor: AppColors.buttonText,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Продолжить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Эмоджи-клан', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Поменять его позже - нельзя. Выбрав эмоджи, ты\nвступаешь в клан с теми же, у кого такой же!',
          style: TextStyle(color: AppColors.textSub, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        
        GestureDetector(
          onTap: _showEmojiPicker,
          child: Row(
            children: [
              CustomPaint(
                painter: DashedCirclePainter(color: AppColors.textSub),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Center(
                    child: _selectedEmoji == null 
                      ? Text('?', style: TextStyle(color: AppColors.textSub, fontSize: 24, fontWeight: FontWeight.bold))
                      : Text(_selectedEmoji!, style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text('Нажми чтобы выбрать', style: TextStyle(color: AppColors.textSub, fontSize: 14)),
            ],
          ),
        ),
        
        const SizedBox(height: 60),
        
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1; 
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.input,
            foregroundColor: AppColors.text,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Назад', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _finishSetup,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedEmoji != null ? AppColors.buttonBg : AppColors.border,
            foregroundColor: AppColors.buttonText,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Завершить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSub),
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      ),
    );
  }
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 6, dashSpace = 4, startAngle = 0;
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    while (startAngle < 360) {
      canvas.drawArc(rect, startAngle * (3.14159 / 180), dashWidth * (3.14159 / 180), false, paint);
      startAngle += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}