import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/booking_call_launcher.dart';
import '../../core/theme.dart';
import '../../core/technician_theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import '../../services/service_locator.dart' show UploadService;
import '../../l10n/app_localizations.dart';

/// Prefix marking a chat message's content as an image URL rather than
/// plain text — no separate message-type column on booking_messages, so
/// this is the cheapest way to tell the two apart on render (see
/// BookingMessage.isImage/previewText, which share this same prefix).
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
  // Messages from this same customer+technician pair's *other* bookings —
  // chat is normally booking-scoped, so this is what lets a returning
  // customer/technician see they've talked before. Shown collapsed by
  // default above the current booking's thread; empty when this is their
  // first booking together.
  List<BookingMessage> _previousMessages = [];
  bool _isLoadingPrevious = true;
  bool _previousExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCallability();
    _loadPreviousMessages();
    // Simple polling so new messages from the other side show up without a
    // websocket layer — cheap for a booking-scoped 1:1 thread like this.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  Future<void> _loadPreviousMessages() async {
    try {
      final messages = await context.read<BookingService>().getPreviousMessages(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _previousMessages = messages;
        _isLoadingPrevious = false;
      });
    } catch (_) {
      // Best-effort — the current booking's thread still loads fine without
      // this; just skip showing the "previous conversation" section.
      if (!mounted) return;
      setState(() => _isLoadingPrevious = false);
    }
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

    XFile? picked;
    try {
      // maxWidth/maxHeight cap the decoded bitmap size — a full-resolution
      // camera photo (12MP+, tens of MB once decoded) can OOM-kill the app
      // on lower-RAM devices when the picker hands it back uncapped; 1600px
      // is plenty for a chat thumbnail while keeping memory use bounded.
      picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (e) {
      // e.g. camera permission denied, or no camera app available.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
      return;
    }
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

  // Shown when the customer taps the audio/video call icon before a
  // technician is assigned to this booking (or the booking is no longer
  // in a callable state) — previously the buttons just looked disabled
  // with no explanation.
  void _showNotAvailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Technician is not available right now. Please try again later.')),
    );
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
            onPressed: () => _callable
                ? startBookingAudioCall(context, bookingId: widget.bookingId, peerDisplayName: widget.peerName)
                : _showNotAvailable(),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video call',
            onPressed: () => _callable
                ? startBookingVideoCall(context, bookingId: widget.bookingId, peerDisplayName: widget.peerName)
                : _showNotAvailable(),
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
    final showPrevious = !_isLoadingPrevious && _previousMessages.isNotEmpty;
    if (_messages.isEmpty && !showPrevious) {
      return Center(
        child: Text(
          l10n.chatEmptyState,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    if (_messages.isEmpty) {
      // No messages on this booking yet, but they've chatted on an earlier
      // one together — lead with that instead of the empty state.
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _previousConversationSection(myId),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(l10n.chatEmptyState, style: TextStyle(color: Colors.grey[500])),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: (showPrevious ? 1 : 0) + _messages.length,
      itemBuilder: (context, i) {
        if (showPrevious) {
          if (i == 0) return _previousConversationSection(myId);
          i -= 1;
        }
        return _messageBubble(_messages[i], myId);
      },
    );
  }

  // Collapsible header + (when expanded) the messages themselves from this
  // pair's earlier bookings, rendered above the current booking's thread.
  Widget _previousConversationSection(String? myId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _previousExpanded = !_previousExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Previous conversation (${_previousMessages.length})',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                  ),
                  Icon(
                    _previousExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),
          if (_previousExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: _previousMessages.map((m) => _messageBubble(m, myId)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageBubble(BookingMessage msg, String? myId) {
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
          color: isMine
              ? (context.watch<AuthProvider>().currentUser?.isTechnician == true ? TechTheme.primary : AppTheme.primaryColor)
              : Colors.grey[200],
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
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Image.network(
                      imageUrl!,
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
              decoration: BoxDecoration(
                color: context.watch<AuthProvider>().currentUser?.isTechnician == true ? TechTheme.primary : AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
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