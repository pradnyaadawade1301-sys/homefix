import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/service_locator.dart';
import 'ai_diagnosis_screen.dart';

/// Step 3 of the customer flow ("ServiceSelection" -> Issue Details Screen):
/// title, description, multiple images, optional voice note. On submit, opens
/// an AI Diagnosis chat session seeded with this issue (step 4).
///
/// [categoryId]/[categoryName] are optional: when the caller already knows
/// the category (tapping a category card elsewhere in the app), pass both
/// and the form opens straight away. When opened with neither — e.g. the
/// bottom-nav "AI Assessment" tab, which has no category context yet — this
/// screen shows an inline category dropdown at the top of the very same form
/// instead of requiring a separate picker screen first. Either way it's the
/// exact same screen and the exact same flow into [AIDiagnosisScreen].
class IssueDetailsScreen extends StatefulWidget {
  final String? categoryId;
  final String? categoryName;

  const IssueDetailsScreen({Key? key, this.categoryId, this.categoryName}) : super(key: key);

  @override
  State<IssueDetailsScreen> createState() => _IssueDetailsScreenState();
}

class _IssueDetailsScreenState extends State<IssueDetailsScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _images = [];
  final List<File> _videos = [];
  bool _isUploading = false;

  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool get _needsCategoryPicker => widget.categoryId == null;
  String? get _categoryId => widget.categoryId ?? _selectedCategoryId;
  String? get _categoryName => widget.categoryName ?? _selectedCategoryName;

  static const _startedOptions = ['Today', '1-2 days', '3-7 days', 'Over a week'];
  String? _startedWhen;
  bool? _isContinuous;
  bool? _previousRepair;
  bool _isEmergency = false;
  final _unusualSignsController = TextEditingController();

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTicker;

  static const int _maxImages = 5;
  static const int _maxVideos = 1;

  @override
  void initState() {
    super.initState();
    if (_needsCategoryPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<CategoryProvider>();
        if (provider.categories.isEmpty) provider.fetchCategories();
      });
    }
  }

  bool get _canAddMore => _images.length < _maxImages || _videos.length < _maxVideos;

  /// Single entry point for adding any media — replaces the old always-visible
  /// "Camera" + "Gallery" boxes with one "+ Add" tile that opens a bottom
  /// sheet of options. Options that are no longer available (e.g. video slot
  /// already filled) are simply omitted rather than shown disabled.
  Future<void> _openAddMediaSheet() async {
    final canAddPhoto = _images.length < _maxImages;
    final canAddVideo = _videos.length < _maxVideos;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              if (canAddPhoto) ...[
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryColor),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
              if (canAddVideo) ...[
                ListTile(
                  leading: const Icon(Icons.videocam_outlined, color: AppTheme.primaryColor),
                  title: const Text('Record a video'),
                  subtitle: const Text('Up to 2 minutes', style: TextStyle(fontSize: 11.5)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickVideo(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined, color: AppTheme.primaryColor),
                  title: const Text('Choose video from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickVideo(ImageSource.gallery);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= _maxImages) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _images.add(File(picked.path)));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_videos.isNotEmpty) return;
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked != null) {
      setState(() => _videos.add(File(picked.path)));
    }
  }

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index));
  }

  void _openVideoPreview(File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _VideoPreviewDialog(file: file),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      _recordingTicker?.cancel();
      final elapsed = _recordingStartedAt != null ? DateTime.now().difference(_recordingStartedAt!) : Duration.zero;
      setState(() {
        _isRecording = false;
        _recordingStartedAt = null;
        _recordingElapsed = Duration.zero;
      });
      if (path == null) return;

      if (elapsed < const Duration(milliseconds: 1000)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording bahut chhoti thi — button dabaye rakhein aur kam se kam 2 second bolein')),
          );
        }
        return;
      }

      setState(() => _isTranscribing = true);
      try {
        if (!mounted) return;
        final aiService = context.read<AIService>();
        final text = await aiService.transcribeAudio(File(path));
        if (!mounted) return;
        setState(() {
          if (_descriptionController.text.trim().isEmpty) {
            _descriptionController.text = text;
          } else {
            _descriptionController.text = '${_descriptionController.text}\n$text';
          }
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_transcribeErrorMessage(e))),
        );
      } finally {
        if (mounted) setState(() => _isTranscribing = false);
      }
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record a voice note')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: filePath,
    );
    _recordingStartedAt = DateTime.now();
    _recordingTicker?.cancel();
    _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _recordingStartedAt == null) return;
      setState(() => _recordingElapsed = DateTime.now().difference(_recordingStartedAt!));
    });
    setState(() => _isRecording = true);
  }

  String _transcribeErrorMessage(Object e) {
    final message = e.toString().replaceFirst('Exception: ', '');
    if (message.toLowerCase().contains("couldn't hear any speech") ||
        message.toLowerCase().contains('recording was too short')) {
      return message;
    }
    return 'Could not transcribe voice note: $message';
  }

  Future<void> _continue() async {
    final categoryId = _categoryId;
    final categoryName = _categoryName;
    if (categoryId == null || categoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select what the issue is with')),
      );
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a short issue title')),
      );
      return;
    }

    setState(() => _isUploading = true);
    final uploadService = context.read<UploadService>();
    final imageUrls = <String>[];
    final videoUrls = <String>[];
    try {
      for (final img in _images) {
        imageUrls.add(await uploadService.uploadFile(img));
      }
      for (final vid in _videos) {
        videoUrls.add(await uploadService.uploadFile(vid));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some attachments failed to upload: $e')),
      );
      return;
    }

    // issueSummary goes to the AI (includes attachment URLs so it has real
    // context). displaySummary is what the customer sees in the chat bubble —
    // just their own title + description, no raw upload URLs.
    final issueSummary = StringBuffer(title);
    final displaySummary = StringBuffer(title);
    if (description.isNotEmpty) {
      issueSummary.write('\n\n$description');
      displaySummary.write('\n\n$description');
    }
    if (imageUrls.isNotEmpty) {
      issueSummary.write('\n\n(Customer attached ${imageUrls.length} photo(s): ${imageUrls.join(', ')})');
    }
    if (videoUrls.isNotEmpty) {
      issueSummary.write('\n\n(Customer attached ${videoUrls.length} video(s): ${videoUrls.join(', ')})');
    }

    if (!mounted) return;
    setState(() => _isUploading = false);

    final brief = JobBrief(
      startedWhen: _startedWhen,
      isContinuous: _isContinuous,
      previousRepair: _previousRepair,
      isEmergency: _isEmergency,
      unusualSigns: _unusualSignsController.text.trim().isEmpty ? null : _unusualSignsController.text.trim(),
      hasVideo: videoUrls.isNotEmpty,
    );
    if (!mounted) return;
    final bookingProvider = context.read<BookingProvider>();
    bookingProvider.setPendingJobBrief(brief);
    bookingProvider.setPendingJobBriefImages(imageUrls);

    await context.read<AIProvider>().startWithIssue(
          categoryId: categoryId,
          issueSummary: issueSummary.toString(),
          displayText: displaySummary.toString(),
        );

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AIDiagnosisScreen(
        categoryId: categoryId,
        categoryName: categoryName,
        problemDescription: '$title${description.isNotEmpty ? '\n$description' : ''}',
      ),
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unusualSignsController.dispose();
    _audioRecorder.dispose();
    _recordingTicker?.cancel();
    super.dispose();
  }

  Widget _buildCategoryPicker() {
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories.where((c) => c.name != 'Refrigerator' && c.name != 'Roofer').toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("What's the issue with?", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              if (provider.isLoading && categories.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  isExpanded: true,
                  hint: const Text('Select a category'),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (value) {
                    final cat = categories.where((c) => c.id == value).toList();
                    setState(() {
                      _selectedCategoryId = value;
                      _selectedCategoryName = cat.isNotEmpty ? cat.first.name : null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// A single media thumbnail (photo or video) with a clearly visible remove
  /// button — a solid white-bordered circle sitting mostly outside the
  /// thumbnail's corner, easy to tap and easy to see against any image.
  Widget _mediaThumb({required Widget child, required VoidCallback onRemove, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 6),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 80, height: 80, child: child),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addMediaTile() {
    return GestureDetector(
      onTap: _openAddMediaSheet,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 10, top: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 26),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _categoryName != null ? 'Describe your $_categoryName issue' : 'AI Assessment';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_needsCategoryPicker) _buildCategoryPicker(),
            const Text('Issue title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'e.g. Ceiling fan not spinning'),
            ),
            const SizedBox(height: 20),
            const Text('Detailed description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Describe what\'s wrong, when it started, anything unusual...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            const Text('A few quick questions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Helps the technician come prepared', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Text('Since when?', style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _startedOptions.map((opt) {
                final selected = _startedWhen == opt;
                return ChoiceChip(
                  label: Text(opt, style: const TextStyle(fontSize: 12.5)),
                  selected: selected,
                  onSelected: (_) => setState(() => _startedWhen = selected ? null : opt),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Text('Is the problem...', style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: const Text('Continuous', style: TextStyle(fontSize: 12.5)),
                selected: _isContinuous == true,
                onSelected: (_) => setState(() => _isContinuous = _isContinuous == true ? null : true),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
              ChoiceChip(
                label: const Text('Occasional', style: TextStyle(fontSize: 12.5)),
                selected: _isContinuous == false,
                onSelected: (_) => setState(() => _isContinuous = _isContinuous == false ? null : false),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
            ]),
            const SizedBox(height: 14),
            Text('Was this repaired before?', style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: const Text('Yes', style: TextStyle(fontSize: 12.5)),
                selected: _previousRepair == true,
                onSelected: (_) => setState(() => _previousRepair = _previousRepair == true ? null : true),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
              ChoiceChip(
                label: const Text('No', style: TextStyle(fontSize: 12.5)),
                selected: _previousRepair == false,
                onSelected: (_) => setState(() => _previousRepair = _previousRepair == false ? null : false),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
            ]),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('This is an emergency', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Marks the job Urgent for the technician', style: TextStyle(fontSize: 11.5)),
              value: _isEmergency,
              activeColor: AppTheme.errorColor,
              onChanged: (v) => setState(() => _isEmergency = v),
            ),
            const SizedBox(height: 10),
            Text('Any unusual sound, smell or leakage?', style: TextStyle(fontSize: 12.5, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _unusualSignsController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Optional — e.g. loud rattling noise from outdoor unit'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Photos & Video', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${_images.length}/$_maxImages photos, ${_videos.length}/$_maxVideos video',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._images.asMap().entries.map((e) => _mediaThumb(
                        child: Image.file(e.value, fit: BoxFit.cover),
                        onRemove: () => _removeImage(e.key),
                      )),
                  ..._videos.asMap().entries.map((e) => _mediaThumb(
                        onTap: () => _openVideoPreview(e.value),
                        onRemove: () => _removeVideo(e.key),
                        child: Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
                          ),
                        ),
                      )),
                  if (_canAddMore) _addMediaTile(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _isTranscribing ? null : _toggleRecording,
              icon: _isTranscribing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                      color: _isRecording ? AppTheme.errorColor : null,
                    ),
              label: Text(
                _isTranscribing
                    ? 'Transcribing...'
                    : _isRecording
                        ? 'Stop recording (${_recordingElapsed.inSeconds}s)'
                        : 'Record voice description',
                style: TextStyle(color: _isRecording ? AppTheme.errorColor : null),
              ),
              style: OutlinedButton.styleFrom(
                side: _isRecording ? const BorderSide(color: AppTheme.errorColor) : null,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _continue,
                child: _isUploading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Continue to AI Assessment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen video preview — opened by tapping a video thumbnail. Simple
/// tap-to-toggle playback with a close button; no scrubber/controls beyond
/// that since these are short (<=2 min) attachment clips, not long-form video.
class _VideoPreviewDialog extends StatefulWidget {
  final File file;
  const _VideoPreviewDialog({required this.file});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
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
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_initialized)
            GestureDetector(
              onTap: () => setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              }),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const CircularProgressIndicator(color: Colors.white),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}