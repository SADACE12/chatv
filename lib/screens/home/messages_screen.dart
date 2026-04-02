import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:video_player/video_player.dart';
import '../../theme/app_colors.dart';

enum MessageType { text, image, video, file }

class ChatMessage {
  final String text; 
  final bool isMe; 
  final String time;
  final MessageType type; 
  final String? filePath; 
  final String? fileName;
  
  ChatMessage({
    required this.text, 
    required this.isMe, 
    required this.time, 
    this.type = MessageType.text, 
    this.filePath, 
    this.fileName
  });
}

class ChatItem {
  final String name; 
  final Color avatarColor; 
  final String emoji; 
  List<ChatMessage> messages;
  
  ChatItem({
    required this.name, 
    required this.avatarColor, 
    required this.emoji, 
    required this.messages
  });
  
  String get lastMessage => messages.isNotEmpty 
      ? (messages.last.type == MessageType.text ? messages.last.text : (messages.last.type == MessageType.image ? '📷 Фотография' : (messages.last.type == MessageType.video ? '🎥 Видео' : '📁 Файл')))
      : "Нет сообщений";
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  ChatItem? selectedChat;
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final ImagePicker _picker = ImagePicker();

  List<ChatItem> chats = [
    ChatItem(name: 'Илон Маск', avatarColor: Colors.orange, emoji: '🚀', messages: [ChatMessage(text: 'Привет! Жду инвайт 😎', isMe: false, time: 'Вчера')]),
    ChatItem(name: 'Команда ChatV', avatarColor: Colors.blueAccent, emoji: '🛠️', messages: [ChatMessage(text: 'Добро пожаловать!', isMe: false, time: '10:00')]),
  ];

  // НОВОЕ МЕНЮ ОТПРАВКИ ФАЙЛОВ
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blueAccent),
            title: Text('Фотография', style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
              if (image != null && selectedChat != null) {
                setState(() {
                  selectedChat!.messages.add(ChatMessage(
                    text: '', isMe: true, time: 'Только что', type: MessageType.image,
                    filePath: image.path, fileName: image.name
                  ));
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.redAccent),
            title: Text('Видео', style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
              if (video != null && selectedChat != null) {
                setState(() {
                  selectedChat!.messages.add(ChatMessage(
                    text: '', isMe: true, time: 'Только что', type: MessageType.video,
                    filePath: video.path, fileName: video.name
                  ));
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.orange),
            title: Text('Документ / Файл', style: TextStyle(color: AppColors.text)),
            onTap: () async {
              Navigator.pop(context);
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null && selectedChat != null) {
                PlatformFile file = result.files.single;
                setState(() {
                  selectedChat!.messages.add(ChatMessage(
                    text: file.name, isMe: true, time: 'Только что', type: MessageType.file,
                    filePath: kIsWeb ? null : file.path, fileName: file.name
                  ));
                });
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkNotifier,
      builder: (context, isDark, child) {
        return Container(
          color: AppColors.bg,
          child: selectedChat == null ? _buildList() : _buildRoom(),
        );
      }
    );
  }

  Widget _buildList() {
    List<ChatItem> filtered = chats.where((chat) {
      final q = _searchQuery.toLowerCase();
      return chat.name.toLowerCase().contains(q) || chat.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController, 
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Поиск...', 
                prefixIcon: Icon(Icons.search, color: AppColors.textSub), 
                filled: true, fillColor: AppColors.input, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (c, i) => ListTile(
                leading: CircleAvatar(backgroundColor: filtered[i].avatarColor, child: Text(filtered[i].emoji)),
                title: Text(filtered[i].name, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                subtitle: Text(filtered[i].lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textSub)),
                onTap: () { setState(() { selectedChat = filtered[i]; _searchQuery = ""; _searchController.clear(); }); },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoom() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar, 
        title: Text(selectedChat!.name, style: TextStyle(color: AppColors.text)), 
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => setState(() => selectedChat = null))
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            itemCount: selectedChat!.messages.length, 
            itemBuilder: (c, i) => _bubble(selectedChat!.messages[i])
          )
        ), 
        _input()
      ]),
    );
  }

  Widget _input() {
    return Container(
      padding: const EdgeInsets.all(10), color: AppColors.sidebar,
      child: Row(children: [
        IconButton(icon: Icon(Icons.attach_file, color: AppColors.textSub), onPressed: _showAttachmentOptions),
        Expanded(
          child: TextField(
            controller: _msgController, 
            style: TextStyle(color: AppColors.text), 
            decoration: InputDecoration(
              hintText: 'Сообщение...', 
              hintStyle: TextStyle(color: AppColors.textSub), 
              filled: true, 
              fillColor: AppColors.input, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
            )
          )
        ),
        IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: () {
          if (_msgController.text.isEmpty) return;
          setState(() { 
            selectedChat!.messages.add(ChatMessage(text: _msgController.text, isMe: true, time: 'Только что')); 
            _msgController.clear(); 
          });
        }),
      ]),
    );
  }

  Widget _bubble(ChatMessage m) {
    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8), 
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.isMe ? Colors.blueAccent : AppColors.card, 
          borderRadius: BorderRadius.circular(15)
        ),
        child: _buildMessageContent(m),
      ),
    );
  }

  // НОВАЯ ЛОГИКА ОТОБРАЖЕНИЯ (С ВИДЕО И КАРТИНКАМИ)
  Widget _buildMessageContent(ChatMessage m) {
    if (m.type == MessageType.image && m.filePath != null) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imagePath: m.filePath!))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: kIsWeb 
              ? Image.network(m.filePath!, width: 200, fit: BoxFit.cover) 
              : Image.file(File(m.filePath!), width: 200, fit: BoxFit.cover),
        ),
      );
    } else if (m.type == MessageType.video && m.filePath != null) {
      return SizedBox(
        width: 280, 
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ChatVideoPlayer(path: m.filePath!),
        ),
      );
    } else if (m.type == MessageType.file) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: m.isMe ? Colors.white : Colors.blueAccent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(m.fileName ?? 'Файл', style: TextStyle(color: m.isMe ? Colors.white : AppColors.text, decoration: TextDecoration.underline)),
          ),
        ],
      );
    }
    
    return Text(m.text, style: TextStyle(color: m.isMe ? Colors.white : AppColors.text));
  }
}

// ==========================================
// ПОЛНОЭКРАННЫЙ ПРОСМОТР ФОТО
// ==========================================
class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, 
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: kIsWeb ? Image.network(imagePath) : Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

// ==========================================
// ВИДЕОПЛЕЕР ДЛЯ ЧАТА
// ==========================================
class ChatVideoPlayer extends StatefulWidget {
  final String path;
  const ChatVideoPlayer({super.key, required this.path});
  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() { 
    super.initState(); 
    if (kIsWeb) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.path));
    } else {
      _controller = VideoPlayerController.file(File(widget.path));
    }
    _controller.initialize().then((_) {
      setState(() {});
      _startHideTimer();
    }); 
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _hideTimer?.cancel(); 
      } else {
        _controller.play();
        _showControls = true;
        _startHideTimer();
      }
    });
  }

  @override
  void dispose() { 
    _hideTimer?.cancel();
    _controller.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized 
      ? Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _showControls = !_showControls);
                if (_showControls && _controller.value.isPlaying) {
                  _startHideTimer();
                } else {
                  _hideTimer?.cancel();
                }
              },
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            
            if (_showControls) ...[
              IgnorePointer(child: Container(color: Colors.black26)),
              
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54, 
                    radius: 25, 
                    child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30)
                  ),
                ),
              ),
              
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller, 
                            allowScrubbing: true,
                            colors: const VideoProgressColors(playedColor: Colors.white, backgroundColor: Colors.white54),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                          onPressed: () {
                             _hideTimer?.cancel();
                             Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenVideoPage(controller: _controller))).then((_) {
                                if (_controller.value.isPlaying) _startHideTimer();
                             });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ],
        ) 
      : Container(height: 150, color: Colors.black12, child: const Center(child: CircularProgressIndicator(color: Colors.white)));
  }
}

// ==========================================
// ПОЛНОЭКРАННЫЙ ВИДЕОПЛЕЕР С ТАЙМЕРОМ
// ==========================================
class FullScreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  const FullScreenVideoPage({super.key, required this.controller});

  @override
  State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        widget.controller.play();
        _showControls = true;
        _startHideTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: Container(color: Colors.transparent),
              ),
            ),
            
            IgnorePointer(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            
            if (_showControls) ...[
              IgnorePointer(child: Container(color: Colors.black38)),
              
              Positioned(
                top: 10, left: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: !widget.controller.value.isPlaying ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const CircleAvatar(
                    backgroundColor: Colors.black54, 
                    radius: 40, 
                    child: Icon(Icons.play_arrow, color: Colors.white, size: 45)
                  ),
                ),
              ),
              
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        widget.controller, 
                        allowScrubbing: true,
                        colors: const VideoProgressColors(playedColor: Colors.blueAccent, backgroundColor: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(widget.controller.value.volume > 0 ? Icons.volume_up : Icons.volume_off, color: Colors.white),
                              SizedBox(
                                width: 120,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: widget.controller.value.volume,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: Colors.blueAccent,
                                    inactiveColor: Colors.white54,
                                    onChanged: (val) {
                                      widget.controller.setVolume(val);
                                      if (widget.controller.value.isPlaying) _startHideTimer();
                                    },
                                  ),
                                ),
                              )
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}