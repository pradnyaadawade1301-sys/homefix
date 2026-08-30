import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';
import '../../services/service_locator.dart' show UploadService;

/// Technician's "before/after" job-proof photo manager, opened as a bottom
/// sheet from a job card (see TechnicianJobsScreen._JobCard). Backed by
/// POST/GET /bookings/:id/photos (homefix_backend booking_handler.go
/// AddJobPhoto/ListJobPhotos) — separate from the customer's own initial
/// problem photos (Booking.images).
///
/// Flow for adding a photo: pick from camera/gallery -> upload the raw file
/// via the generic UploadService (POST /uploads -> {url}) -> attach that URL
/// to the booking via BookingProvider.addJobPhoto. Two calls, but it keeps
/// file storage fully decoupled from booking data, matching how every other
/// image field in this app (KYC docs, issue photos) already works.
class JobPhotosSheet extends StatefulWidget {
  final String bookingId;
  const JobPhotosSheet({Key? key, required this.bookingId}) : super(key: key);

  @override
  State<JobPhotosSheet> createState() => _JobPhotosSheetState();
}

class _JobPhotosSheetState extends State<JobPhotosSheet> {
  final _picker = ImagePicker();
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

  Future<void> _addPhoto(String photoType) async {
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
        _uploadingBefore = true;
      } else {
        _uploadingAfter = true;
      }
    });

    try {
      final uploadService = context.read<UploadService>();
      final url = await uploadService.uploadFile(File(picked.path));
      if (!mounted) return;
      final provider = context.read<BookingProvider>();
      final ok = await provider.addJobPhoto(
        bookingId: widget.bookingId,
        photoType: photoType,
        imageUrl: url,
      );
      if (!ok && mounted) {
        setState(() => _localError = provider.error ?? 'Failed to save photo');
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
                  const Text('Job photos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Add before/after proof photos for this job. The customer can see these too.',
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    ))
                  else ...[
                    _photoSection(
                      title: 'Before',
                      photos: provider.beforePhotos,
                      uploading: _uploadingBefore,
                      onAdd: () => _addPhoto('before'),
                    ),
                    const SizedBox(height: 24),
                    _photoSection(
                      title: 'After',
                      photos: provider.afterPhotos,
                      uploading: _uploadingAfter,
                      onAdd: () => _addPhoto('after'),
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
    required String title,
    required List<BookingJobPhoto> photos,
    required bool uploading,
    required VoidCallback onAdd,
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
              GestureDetector(
                onTap: uploading ? null : onAdd,
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                  ),
                  child: uploading
                      ? const Center(
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                          ),
                        )
                      : const Icon(Icons.add_a_photo_outlined, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}