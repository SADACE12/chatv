import 'package:flutter/material.dart';
import '../home/main_layout.dart';
import 'dart:math';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 1; // 1 - Имя/Никнейм, 2 - Эмоджи
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedEmoji;

  // Массив базовых эмоджи для выбора
  final List<String> _emojis = [
    '😀', '😁', '😂', '🤣', '😃', '😄', '😅', '😆', '😉', '😊', 
    '😋', '😎', '😍', '😘', '🥰', '😗', '😙', '😚', '🙂', '🤗', 
    '🤩', '🤔', '🤨', '😐', '😑', '😶', '🙄', '😏', '😣', '😥', 
    '😮', '🤐', '😯', '😪', '😫', '😴', '😌', '😛', '😜', '😝', 
    '🤤', '😒', '😓', '😔', '😕', '🙃', '🤑', '😲', '☹️', '🙁', 
    '😤', '😢', '😭', '😦', '😧', '😨', '😩', '🤯', '😬', '😰', 
    '😱', '🥵', '🥶', '😳', '🤪', '😵', '😡', '😠', '🤬', '😷', 
    '😈', '👿', '👹', '👺', '💀', '👻', '👽', '👾', '🤖', '💩'
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

  void _finishSetup() {
    if (_selectedEmoji != null) {
      // Здесь в будущем данные будут отправляться в БД
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите свой эмоджи-клан')),
      );
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Выберите эмоджи', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF161618),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Настройка профиля',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Пожалуйста, укажите данные профиля',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 30),
                
                // Прогресс бар (шаги)
                _buildProgressBar(),
                const SizedBox(height: 40),

                // Меняем контент в зависимости от шага
                _currentStep == 1 ? _buildStep1() : _buildStep2(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ВИДЖЕТЫ ШАГОВ ---

  Widget _buildProgressBar() {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.blueAccent,
          child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep == 2 ? Colors.blueAccent : Colors.white24,
          ),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: _currentStep == 2 ? Colors.blueAccent : const Color(0xFF2A2A2A),
          child: Text('2', style: TextStyle(color: _currentStep == 2 ? Colors.white : Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Имя', style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Как тебя будут видеть другие пользователи', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        _buildTextField(controller: _nameController, hint: 'Иван Иванов'),
        
        const SizedBox(height: 24),
        
        const Text('Username', style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Уникальный никнейм для твоего профиля\n(латиница, цифры, и "_")', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        _buildTextField(controller: _usernameController, hint: 'ivanov1998'),
        
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
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
        const Text('Эмоджи-клан', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Поменять его позже - нельзя. Выбрав эмоджи, ты\nвступаешь в клан с теми же, у кого такой же!',
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        
        // Кнопка выбора эмоджи с кастомным пунктирным кругом
        GestureDetector(
          onTap: _showEmojiPicker,
          child: Row(
            children: [
              CustomPaint(
                painter: DashedCirclePainter(),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Center(
                    child: _selectedEmoji == null 
                      ? const Text('?', style: TextStyle(color: Colors.grey, fontSize: 24, fontWeight: FontWeight.bold))
                      : Text(_selectedEmoji!, style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text('Нажми чтобы выбрать', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
        
        const SizedBox(height: 60),
        
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1; // Возврат на первый шаг
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2A2A2A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Назад', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _finishSetup,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedEmoji != null ? Colors.white : Colors.grey[800],
            foregroundColor: Colors.black,
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
      ),
    );
  }
}

// Кастомный рисовальщик для пунктирного круга
class DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 6, dashSpace = 4, startAngle = 0;
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    while (startAngle < 360) {
      canvas.drawArc(rect, startAngle * (pi / 180), dashWidth * (pi / 180), false, paint);
      startAngle += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}