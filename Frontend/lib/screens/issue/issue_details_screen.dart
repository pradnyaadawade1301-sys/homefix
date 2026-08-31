import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/service_locator.dart';
import 'ai_diagnosis_screen.dart';

/// Step 3 of the customer flow ("ServiceSelection" -> Issue Details Screen):
/// title, description, multiple images, optional voice note. On submit, opens
/// an AI Diagnosis chat session seeded with this issue (step 4).
class IssueDetailsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const IssueDetailsScreen({Key? key, required this.categoryId, required this.categoryName}) : super(key: key);

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

  // Guided questions — quick chip-style answers that fold into the Job
  // Brief the technician sees before Accept (see JobBrief in booking_model).
  static const _startedOptions = ['Today', '1-2 days', '3-7 days', 'Over a week'];
  String? _startedWhen;
  bool? _isContinuous;
  bool? _previousRepair;
  bool _isEmergency = false;
  final _unusualSignsController = TextEditingController();

  // Voice recording state.
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTicker;

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 5 images')),
      );
      return;
    }
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _images.add(File(picked.path)));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _pickVideo() async {
    if (_videos.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 1 video')),
      );
      return;
    }
    final picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked != null) {
      setState(() => _videos.add(File(picked.path)));
    }
  }

  void _removeVideo(int index) {
    setState(() => _videos.removeAt(index));
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording, then upload + transcribe.
      final path = await _audioRecorder.stop();
      _recordingTicker?.cancel();
      final elapsed = _recordingStartedAt != null ? DateTime.now().difference(_recordingStartedAt!) : Duration.zero;
      setState(() {
        _isRecording = false;
        _recordingStartedAt = null;
        _recordingElapsed = Duration.zero;
      });
      if (path == null) return;

      // A recording under ~1 second is almost always an accidental tap
      // rather than real speech, and is exactly what makes Whisper
      // hallucinate unrelated text (e.g. "Thank you.") instead of failing
      // cleanly — so catch it here before even uploading.
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

    // Start recording — request mic permission implicitly via the record package.
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
    // Explicit AAC-LC config at a healthy bitrate/sample rate — the record
    // package's bare default can end up choosing a low-quality encoder on
    // some Android devices, which also makes Whisper's output less reliable.
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

  /// Server sends a clear, already-user-facing message for the "no real
  /// speech in that clip" case (see ai_handler.go / groq_service.go) —
  /// surface that as-is instead of a generic "Could not transcribe" wrapper.
  String _transcribeErrorMessage(Object e) {
    final message = e.toString().replaceFirst('Exception: ', '');
    if (message.toLowerCase().contains("couldn't hear any speech") ||
        message.toLowerCase().contains('recording was too short')) {
      return message;
    }
    return 'Could not transcribe voice note: $message';
  }

  Future<void> _continue() async {
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

    final issueSummary = StringBuffer(title);
    if (description.isNotEmpty) issueSummary.write('\n\n$description');
    if (imageUrls.isNotEmpty) {
      issueSummary.write('\n\n(Customer attached ${imageUrls.length} photo(s): ${imageUrls.join(', ')})');
    }
    if (videoUrls.isNotEmpty) {
      issueSummary.write('\n\n(Customer attached ${videoUrls.length} video(s): ${videoUrls.join(', ')})');
    }

    if (!mounted) return;
    setState(() => _isUploading = false);

    // Fold guided-question answers into the pending Job Brief so the
    // technician can see them later — done here rather than only at final
    // booking-create time because this is the one place we know them.
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
          categoryId: widget.categoryId,
          issueSummary: issueSummary.toString(),
        );

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AIDiagnosisScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Describe your ${widget.categoryName} issue')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
                const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${_images.length}/5', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._images.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(e.value, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removeImage(e.key),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_images.length < 5) ...[
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Camera', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Gallery', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  ..._videos.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removeVideo(e.key),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_videos.isEmpty)
                    GestureDetector(
                      onTap: _pickVideo,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_outlined, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Video', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
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
                    : const Text('Continue to AI Diagnosis'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}