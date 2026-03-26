import 'package:flutter/material.dart';

class Post {
  final String username;
  final Color avatarColor;
  final String timeAgo;
  final String text;
  final bool hasImage;

  Post({
    required this.username,
    required this.avatarColor,
    required this.timeAgo,
    required this.text,
    this.hasImage = false,
  });
}