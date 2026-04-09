import 'package:flutter/material.dart';

enum PostMediaType { none, image, video, file }

class Post {
  final String? id;
  final String? userId; // <--- ДОБАВИЛИ: ID автора из Supabase Auth
  final String username;
  final String? userEmoji;
  final Color avatarColor;
  final DateTime createdAt;
  String text;
  final String? imagePath;
  final String? fileName;
  final PostMediaType mediaType;
  final List<String>? pollOptions;
  List<int>? pollVotes;
  int? votedOptionIndex;
  int likesCount;
  bool isLiked;
  List<String> comments;

  Post({
    this.id,
    this.userId, // <--- ДОБАВИЛИ В КОНСТРУКТОР
    required this.username,
    this.userEmoji,
    required this.avatarColor,
    required this.createdAt,
    required this.text,
    this.imagePath,
    this.fileName,
    this.mediaType = PostMediaType.none,
    this.pollOptions,
    this.pollVotes,
    this.votedOptionIndex,
    this.likesCount = 0,
    this.isLiked = false,
    List<String>? comments,
  }) : comments = comments ?? [];

  // Конвертируем данные из Supabase (JSON) в объект Dart
  factory Post.fromJson(Map<String, dynamic> json) {
    // Безопасное получение списка лайков и комментов, если они приходят в запросе
    final List likesList = json['likes'] ?? [];
    final List dbComments = json['comments'] ?? [];

    return Post(
      id: json['id'] as String?,
      userId: json['user_id'] as String?, // <--- ЧИТАЕМ ИЗ БАЗЫ
      username: json['username'] as String? ?? 'Аноним',
      userEmoji: json['user_emoji'] as String?,
      avatarColor: Color(json['avatar_color'] as int? ?? Colors.orange.value),
      createdAt: DateTime.parse(json['created_at']),
      text: json['text'] as String? ?? '',
      imagePath: json['image_path'] as String?,
      fileName: json['file_name'] as String?,
      mediaType: PostMediaType.values[json['media_type'] as int? ?? 0],
      likesCount: likesList.length,
      comments: dbComments.map((c) => "${c['username']}||${c['text']}").toList(),
    );
  }

  // Конвертируем объект Dart в формат JSON для отправки в Supabase
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId, // <--- ОТПРАВЛЯЕМ В БАЗУ
      'username': username,
      'user_emoji': userEmoji,
      'avatar_color': avatarColor.value,
      'text': text,
      'image_path': imagePath,
      'file_name': fileName,
      'media_type': mediaType.index,
    };
  }
}