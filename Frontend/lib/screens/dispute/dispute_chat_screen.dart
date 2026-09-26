import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/dispute_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/dispute_service.dart';
import '../../services/service_locator.dart' show UploadService;

/// Live chat between the customer/technician who raised a dispute and
/// HomeFix support ("agar technician ne thik se kaam nahi kiya to seedha
/// organization se complain kar sako" — this is that direct line, separate
/// from the booking-scoped chat with the technician themselves).
/// Backed by GET/POST /disputes/:id/messages
/// (homefix_backend/internal/handler/dispute_handler.go SendMessage/ListMessages).
/// Supports photo and video attachments (uploaded via UploadService, then
/// referenced by URL), not just text.
class DisputeChatScreen extends StatefulWidget {
  final String disputeId;
  const DisputeChatScreen({Key? key, required this.disputeId}) : super(key: key);

  @override
  State<DisputeChatScreen> createState() => _DisputeChatScreenState();
}

class _DisputeChatScreenState extends State<DisputeChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  List<DisputeMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingAttachment = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Simple polling, same approach as the booking chat screen — good
    // enough for a support thread, no websocket layer needed.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final messages = await context.read<DisputeService>().listMessages(widget.disputeId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
    try {
      final sent = await context.read<DisputeService>().sendMessage(
            disputeId: widget.disputeId,
            message: content,
          );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      _controller.text = content;
    }
  }

  Future<void> _pickAndSendAttachment() async {
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(const _AttachmentChoice(ImageSource.camera, isVideo: false)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo from gallery'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(const _AttachmentChoice(ImageSource.gallery, isVideo: false)),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record video'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(const _AttachmentChoice(ImageSource.camera, isVideo: true)),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Choose video from gallery'),
              onTap: () => Navigator.of(sheetContext)
                  .pop(const _AttachmentChoice(ImageSource.gallery, isVideo: true)),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    XFile? picked;
    try {
      picked = choice.isVideo
          ? await _picker.pickVideo(source: choice.source, maxDuration: const Duration(minutes: 2))
          // maxWidth/maxHeight cap the decoded bitmap size — same reasoning
          // as the booking chat screen's image picker.
          : await _picker.pickImage(
              source: choice.source,
              imageQuality: 70,
              maxWidth: 1600,
              maxHeight: 1600,
            );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${choice.source == ImageSource.camera ? 'camera' : 'gallery'}: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
      return;
    }
    if (picked == null || _isUploadingAttachment) return;

    setState(() => _isUploadingAttachment = true);
    try {
      final url = await context.read<UploadService>().uploadFile(File(picked.path));
      final sent = await context.read<DisputeService>().sendMessage(
            disputeId: widget.disputeId,
            attachmentUrl: url,
            attachmentType: choice.isVideo ? 'video' : 'image',
          );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _isUploadingAttachment = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAttachment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: InteractiveViewer(child: Image.network(url))),
      ),
    ));
  }

  void _openVideo(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _NetworkVideoDialog(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat with Support')),
      body: Column(
        children: [
          Expanded(child: _body(myId)),
          _composer(),
        ],
      ),
    );
  }

  Widget _body(String? myId) {
    if (_isLoading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Complaint darj ho gayi hai. Yahan aap seedha support team se baat kar sakte hain.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        // "Mine" is by role, not sender_id — the app only ever calls this
        // screen as the customer/technician side ("user"); admin replies
        // come from the hidden web panel and always render as the peer.
        final isMine = msg.senderRole == 'user';
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: (msg.hasImage || msg.hasVideo)
                ? const EdgeInsets.all(6)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primaryColor : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMine ? 14 : 2),
                bottomRight: Radius.circular(isMine ? 2 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      'HomeFix Support',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ),
                if (msg.hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () => _openImage(msg.attachmentUrl!),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Image.network(
                          msg.attachmentUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (msg.hasVideo)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () => _openVideo(msg.attachmentUrl!),
                      child: Container(
                        width: 200,
                        height: 200,
                        color: Colors.black87,
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                  ),
                if (msg.message.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: (msg.hasImage || msg.hasVideo) ? 6 : 0),
                    child: Text(
                      msg.message,
                      style: TextStyle(color: isMine ? Colors.white : Colors.black87, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(msg.createdAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isMine ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _composer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            IconButton(
              icon: _isUploadingAttachment
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.attach_file, color: Colors.grey[700]),
              tooltip: 'Send photo or video',
              onPressed: _isUploadingAttachment ? null : _pickAndSendAttachment,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Apna message likhein...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isSending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _AttachmentChoice {
  final ImageSource source;
  final bool isVideo;
  const _AttachmentChoice(this.source, {required this.isVideo});
}

/// Full-screen player for a video attachment already uploaded to the
/// server (network URL) — the chat-thread counterpart of
/// IssueDetailsScreen's _VideoPreviewDialog, which plays a local file
/// before upload.
class _NetworkVideoDialog extends StatefulWidget {
  final String url;
  const _NetworkVideoDialog({required this.url});

  @override
  State<_NetworkVideoDialog> createState() => _NetworkVideoDialogState();
}

class _NetworkVideoDialogState extends State<_NetworkVideoDialog> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: _initialized
          ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: GestureDetector(
                onTap: () => setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                }),
                child: VideoPlayer(_controller),
              ),
            )
          : const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
    );
  }
}