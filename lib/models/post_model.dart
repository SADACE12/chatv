import 'package:flutter/material.dart';

enum PostMediaType { none, image, video, file }

class Post {
  final String? id;
  final String? userId; 
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
    this.userId, 
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

  // Добавили параметр myName, чтобы определять, лайкнул ли пост текущий пользователь
  factory Post.fromJson(Map<String, dynamic> json, String myName) {
    final List likesList = json['likes'] ?? [];
    final List dbComments = json['comments'] ?? [];

    return Post(
      id: json['id']?.toString(), // toString() спасет, если в БД id это цифра, а не текст
      userId: json['user_id'] as String?, 
      username: json['username'] as String? ?? 'Аноним',
      userEmoji: json['user_emoji'] as String? ?? '👤',
      avatarColor: Color(json['avatar_color'] as int? ?? Colors.orange.value),
      createdAt: DateTime.parse(json['created_at']),
      text: json['text'] as String? ?? '',
      imagePath: json['image_path'] as String?,
      fileName: json['file_name'] as String?,
      mediaType: PostMediaType.values[json['media_type'] as int? ?? 0],
      pollOptions: json['poll_options'] != null ? List<String>.from(json['poll_options']) : null, // Восстановили опросы
      pollVotes: json['poll_votes'] != null ? List<int>.from(json['poll_votes']) : null, // Восстановили голоса
      likesCount: likesList.length,
      isLiked: likesList.any((like) => like['username'] == myName), // Проверяем лайк
      comments: dbComments.map((c) => "${c['username']}||${c['text']}").toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId, 
      'username': username,
      'user_emoji': userEmoji,
      'avatar_color': avatarColor.value,
      'text': text,
      'image_path': imagePath,
      'file_name': fileName,
      'media_type': mediaType.index,
      'poll_options': pollOptions, // Отправляем опросы в БД
      'poll_votes': pollVotes,     // Отправляем голоса в БД
    };
  }
}