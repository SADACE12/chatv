import 'package:flutter/material.dart';

enum PostMediaType { none, image, video, file }

class Post {
  final String username;
  final String? userEmoji; // <--- ДОБАВЛЕНО ДЛЯ ЭМОДЖИ
  final Color avatarColor;
  final String timeAgo;
  String text;
  final String? imagePath;
  final String? fileName;
  final PostMediaType mediaType;
  final List<String>? pollOptions;

  // --- ДОБАВЛЕНО ДЛЯ ОПРОСОВ ---
  List<int>? pollVotes;
  int? votedOptionIndex;
  // -----------------------------

  int likesCount;
  bool isLiked;
  List<String> comments;

  Post({
    required this.username,
    this.userEmoji, // <--- ДОБАВЛЕНО СЮДА
    required this.avatarColor,
    required this.timeAgo,
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
}
