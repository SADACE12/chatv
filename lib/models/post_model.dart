import 'package:flutter/material.dart';

class Post {
  final String username;
  final Color avatarColor;
  final String timeAgo;
  String text; // Убрали final, чтобы можно было редактировать
  final String? imagePath;
  final List<String>? pollOptions;
  
  // Новые поля для лайков и комментариев
  int likesCount;
  bool isLiked;
  List<String> comments;

  Post({
    required this.username,
    required this.avatarColor,
    required this.timeAgo,
    required this.text,
    this.imagePath,
    this.pollOptions,
    this.likesCount = 0,
    this.isLiked = false,
    List<String>? comments,
  }) : comments = comments ?? []; // Инициализируем пустой список комментариев по умолчанию
}