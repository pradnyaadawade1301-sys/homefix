import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/technician_theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../services/service_locator.dart' show UploadService;

/// Technician's "before/after" job-proof photo manager, opened as a bottom
/// sheet from a job card (see TechnicianJobsScreen._JobCard). Backed by
/// POST/GET /bookings/:id/photos (homefix_backend booking_handler.go
/// AddJobPhoto/ListJobPhotos) — separate from the customer's own initial
/// problem photos (Booking.images).
///
/// Flow for adding a photo: pick from camera/gallery -> shown as a local
/// preview with its own "Upload" button (a separate, explicit step, not
/// automatic) -> upload the raw file via the generic UploadService
/// (POST /uploads -> {url}) -> attach that URL to the booking via
/// BookingProvider.addJobPhoto.
class JobPhotosSheet extends StatefulWidget {
  final String bookingId;
  // True right after a job is marked complete — only the "After" section is
  // shown then (the natural moment to capture proof of finished work), not
  // "Before" (which belongs earlier, during the visit).
  final bool onlyAfter;
  const JobPhotosSheet({Key? key, required this.bookingId, this.onlyAfter = false}) : super(key: key);

  @override
  State<JobPhotosSheet> createState() => _JobPhotosSheetState();
}

class _JobPhotosSheetState extends State<JobPhotosSheet> {
  final _picker = ImagePicker();
  // Picked but not yet uploaded — the technician confirms with the explicit
  // "Upload" button before this actually goes anywhere.
  File? _stagedBefore;
  File? _stagedAfter;
  bool _uploadingBefore = false;
  bool _uploadingAfter = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().fetchJobPhotos(widget.bookingId);
    });
  }

  Future<void> _pickPhoto(String photoType) async {
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

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _localError = null;
      if (photoType == 'before') {
        _stagedBefore = File(picked.path);
      } else {
        _stagedAfter = File(picked.path);
      }
    });
  }

  void _clearStaged(String photoType) {
    setState(() {
      if (photoType == 'before') {
        _stagedBefore = null;
      } else {
        _stagedAfter = null;
      }
    });
  }

  Future<void> _uploadStaged(String photoType) async {
    final file = photoType == 'before' ? _stagedBefore : _stagedAfter;
    if (file == null) return;

    setState(() {
      _localError = null;
      if (photoType == 'before') {
        _uploadingBefore = true;
      } else {
        _uploadingAfter = true;
      }
    });

    try {
      final uploadService = context.read<UploadService>();
      final url = await uploadService.uploadFile(file);
      if (!mounted) return;
      final provider = context.read<BookingProvider>();
      final ok = await provider.addJobPhoto(
        bookingId: widget.bookingId,
        photoType: photoType,
        imageUrl: url,
      );
      if (!ok && mounted) {
        setState(() => _localError = provider.error ?? 'Failed to save photo');
      } else if (mounted) {
        _clearStaged(photoType);
        // Completion flow: the "after" photo was the whole point of opening
        // this sheet, so once it's uploaded there's nothing left to do here
        // — close it instead of leaving the technician looking at an empty
        // "add another photo" placeholder.
        if (widget.onlyAfter && photoType == 'after') {
          Navigator.of(context).pop();
          return;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _localError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _uploadingBefore = false;
          _uploadingAfter = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<BookingProvider>(
          builder: (context, provider, _) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(widget.onlyAfter ? 'Add completion photo' : 'Job photos',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    widget.onlyAfter
                        ? 'Add a photo of the completed work. The customer can see this too.'
                        : 'Add before/after proof photos for this job. The customer can see these too.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  if (_localError != null) ...[
                    Text(_localError!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12.5)),
                    const SizedBox(height: 12),
                  ],
                  if (provider.isLoadingJobPhotos)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(strokeWidth: 2, color: TechTheme.primary),
                    ))
                  else ...[
                    if (!widget.onlyAfter) ...[
                      _photoSection(
                        type: 'before',
                        title: 'Before',
                        photos: provider.beforePhotos,
                        staged: _stagedBefore,
                        uploading: _uploadingBefore,
                      ),
                      const SizedBox(height: 24),
                    ],
                    _photoSection(
                      type: 'after',
                      title: 'After',
                      photos: provider.afterPhotos,
                      staged: _stagedAfter,
                      uploading: _uploadingAfter,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _photoSection({
    required String type,
    required String title,
    required List<BookingJobPhoto> photos,
    required File? staged,
    required bool uploading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final photo in photos) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photo.imageUrl, width: 96, height: 96, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
              ],
              if (staged != null) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(staged, width: 96, height: 96, fit: BoxFit.cover),
                    ),
                    if (uploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _clearStaged(type),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
              ] else
                GestureDetector(
                  onTap: () => _pickPhoto(type),
                  child: Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      color: TechTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TechTheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: TechTheme.primary),
                  ),
                ),
            ],
          ),
        ),
        if (staged != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
              onPressed: uploading ? null : () => _uploadStaged(type),
              icon: uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(uploading ? 'Uploading…' : 'Upload'),
            ),
          ),
        ],
      ],
    );
  }
}