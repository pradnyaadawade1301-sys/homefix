import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/booking_call_launcher.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import '../../services/service_locator.dart' show UploadService;
import '../../l10n/app_localizations.dart';

/// Prefix marking a chat message's content as an image URL rather than
/// plain text — no separate message-type column on booking_messages, so
/// this is the cheapest way to tell the two apart on render (see
/// BookingMessage.content in the backend, which stores whatever this sends
/// verbatim).
const _imageMessagePrefix = 'img::';

/// Booking-scoped chat between the customer and the technician assigned to
/// that booking. Backed by GET/POST /bookings/:id/messages
/// (homefix_backend/internal/handler/booking_handler.go SendMessage/ListMessages) —
/// there's no separate "conversation" concept, every booking has at most one
/// customer + one technician so the booking id doubles as the thread id.
class BookingChatScreen extends StatefulWidget {
  final String bookingId;
  final String peerName;

  const BookingChatScreen({
    Key? key,
    required this.bookingId,
    required this.peerName,
  }) : super(key: key);

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  List<BookingMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;
  String? _error;
  Timer? _pollTimer;
  // Whether the call buttons should be enabled — mirrors
  // isCallableBookingStatus (only an assigned, active-or-completed booking
  // can start a call); fetched separately since this screen is only ever
  // given a bookingId + peerName by its callers, not the full Booking.
  bool _callable = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCallability();
    // Simple polling so new messages from the other side show up without a
    // websocket layer — cheap for a booking-scoped 1:1 thread like this.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCallability() async {
    try {
      final booking = await context.read<BookingService>().getBookingDetail(widget.bookingId);
      if (!mounted) return;
      setState(() => _callable = isCallableBookingStatus(booking.status));
    } catch (_) {
      // Best-effort — the call buttons simply stay disabled if this fails.
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final messages = await context.read<BookingService>().getMessages(widget.bookingId);
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
      final sent = await context.read<BookingService>().sendMessage(widget.bookingId, content);
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

  Future<void> _pickAndSendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (picked == null || _isUploadingImage) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await context.read<UploadService>().uploadFile(File(picked.path));
      final sent = await context.read<BookingService>().sendMessage(widget.bookingId, '$_imageMessagePrefix$url');
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _isUploadingImage = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingImage = false);
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

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Audio call',
            onPressed: _callable
                ? () => startBookingAudioCall(context, bookingId: widget.bookingId, peerDisplayName: widget.peerName)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video call',
            onPressed: _callable
                ? () => startBookingVideoCall(context, bookingId: widget.bookingId, peerDisplayName: widget.peerName)
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body(myId)),
          _composer(),
        ],
      ),
    );
  }

  Widget _body(String? myId) {
    final l10n = AppLocalizations.of(context);
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
            TextButton(onPressed: _load, child: Text(l10n.chatRetry)),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          l10n.chatEmptyState,
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
        final isMine = msg.senderId == myId;
        final isImage = msg.content.startsWith(_imageMessagePrefix);
        final imageUrl = isImage ? msg.content.substring(_imageMessagePrefix.length) : null;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: isImage
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
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () => _openImage(imageUrl),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 160,
                          height: 120,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    msg.content,
                    style: TextStyle(color: isMine ? Colors.white : Colors.black87, fontSize: 14),
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
    final l10n = AppLocalizations.of(context);
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
              icon: _isUploadingImage
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.camera_alt_outlined, color: Colors.grey[700]),
              tooltip: 'Send photo',
              onPressed: _isUploadingImage ? null : _pickAndSendImage,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.chatMessageHint(widget.peerName),
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