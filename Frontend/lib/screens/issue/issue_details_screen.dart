import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';
import '../../providers/ai_provider.dart';
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
  bool _isUploading = false;

  // Voice recording state.
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;

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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording, then upload + transcribe.
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;

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
          SnackBar(content: Text('Could not transcribe voice note: $e')),
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
    await _audioRecorder.start(const RecordConfig(), path: filePath);
    setState(() => _isRecording = true);
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
    try {
      for (final img in _images) {
        imageUrls.add(await uploadService.uploadFile(img));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some images failed to upload: $e')),
      );
      return;
    }

    final issueSummary = StringBuffer(title);
    if (description.isNotEmpty) issueSummary.write('\n\n$description');
    if (imageUrls.isNotEmpty) {
      issueSummary.write('\n\n(Customer attached ${imageUrls.length} photo(s): ${imageUrls.join(', ')})');
    }

    if (!mounted) return;
    setState(() => _isUploading = false);

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
    _audioRecorder.dispose();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Photos (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${_images.length}/5', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
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
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.grey),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                      ),
                    ),
                  ],
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
                        ? 'Stop recording'
                        : 'Record voice description (optional)',
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