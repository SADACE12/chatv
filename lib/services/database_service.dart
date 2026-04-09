import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart'; // Путь к твоей модели

class DatabaseService {
  final _supabase = Supabase.instance.client;

  Future<void> createPost(Post newPost) async {
    try {
      await _supabase.from('posts').insert(newPost.toJson());
      print('Пост успешно добавлен!');
    } catch (error) {
      print('Ошибка при создании поста: $error');
    }
  }
}