import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';

/// Lets the technician upload/view their trade license. UI-only for now;
/// wire the upload to your TechnicianKycProvider.uploadFile once ready.
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({Key? key}) : super(key: key);

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _picker = ImagePicker();
  final _licenseNumberController = TextEditingController();
  File? _licenseFile;

  Future<void> _pickLicense() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _licenseFile = File(picked.path));
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('License')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add your trade license so customers know you\'re certified.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 20),
            TextField(
              controller: _licenseNumberController,
              decoration: const InputDecoration(
                hintText: 'License number',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickLicense,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.lightOutline),
                ),
                child: _licenseFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_licenseFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file_rounded, size: 36, color: AppTheme.primaryColor),
                          SizedBox(height: 8),
                          Text('Tap to upload license photo', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  if (_licenseNumberController.text.trim().isEmpty || _licenseFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add both license number and photo')),
                    );
                    return;
                  }
                  // TODO: Upload via TechnicianKycProvider and save license number.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('License submitted for review')),
                  );
                },
                child: const Text('Submit License'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}