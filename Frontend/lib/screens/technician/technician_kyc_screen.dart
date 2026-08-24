import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/category_provider.dart';

/// Technician KYC / registration screen — collects service category, experience,
/// address, government ID, and profile photo, then submits to POST /technicians.
/// Shown right after a technician signs up, or whenever a logged-in technician has
/// no profile yet (see SplashScreen / TechnicianStatusScreen routing).
class TechnicianKycScreen extends StatefulWidget {
  const TechnicianKycScreen({Key? key}) : super(key: key);

  @override
  State<TechnicianKycScreen> createState() => _TechnicianKycScreenState();
}

class _TechnicianKycScreenState extends State<TechnicianKycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _experienceController = TextEditingController();
  final _addressController = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedCategoryId;
  File? _governmentIdFile;
  File? _profilePhotoFile;
  String? _localError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  @override
  void dispose() {
    _experienceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isGovernmentId) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (isGovernmentId) {
        _governmentIdFile = File(picked.path);
      } else {
        _profilePhotoFile = File(picked.path);
      }
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _localError = 'Please select a service category');
      return;
    }
    if (_governmentIdFile == null) {
      setState(() => _localError = 'Please upload a government ID');
      return;
    }
    if (_profilePhotoFile == null) {
      setState(() => _localError = 'Please upload a profile photo');
      return;
    }

    final kyc = context.read<TechnicianKycProvider>();

    final govIdUrl = await kyc.uploadFile(_governmentIdFile!);
    if (govIdUrl == null) {
      setState(() => _localError = kyc.error ?? 'Failed to upload government ID');
      return;
    }
    final photoUrl = await kyc.uploadFile(_profilePhotoFile!);
    if (photoUrl == null) {
      setState(() => _localError = kyc.error ?? 'Failed to upload profile photo');
      return;
    }

    final success = await kyc.submit(
      categoryId: _selectedCategoryId!,
      experienceYears: int.tryParse(_experienceController.text.trim()) ?? 0,
      address: _addressController.text.trim(),
      governmentIdUrl: govIdUrl,
      profilePhotoUrl: photoUrl,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/technician-status', (route) => false);
    } else {
      setState(() => _localError = kyc.error ?? 'Failed to submit KYC details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Registration'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your KYC',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'An admin will review and approve your profile before you can start accepting jobs.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                Text('Service category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Consumer<CategoryProvider>(
                  builder: (context, catProvider, _) {
                    if (catProvider.isLoading && catProvider.categories.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      hint: const Text('Select your primary category'),
                      items: catProvider.categories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Years of experience',
                    prefixIcon: Icon(Icons.work_history_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Experience is required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid number of years';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Full address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                ),
                const SizedBox(height: 24),

                Text('Documents', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                _DocumentPicker(
                  label: 'Government ID',
                  subtitle: 'Aadhaar, PAN, Driving Licence, or Voter ID',
                  file: _governmentIdFile,
                  onTap: () => _pickImage(true),
                ),
                const SizedBox(height: 12),
                _DocumentPicker(
                  label: 'Profile photo',
                  subtitle: 'A clear photo of your face',
                  file: _profilePhotoFile,
                  onTap: () => _pickImage(false),
                ),

                if (_localError != null) ...[
                  const SizedBox(height: 16),
                  Text(_localError!, style: const TextStyle(color: AppTheme.errorColor)),
                ],

                const SizedBox(height: 28),
                Consumer<TechnicianKycProvider>(
                  builder: (context, kyc, _) {
                    final busy = kyc.isLoading || kyc.isUploading;
                    return SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: busy ? null : _handleSubmit,
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Submit for review'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  final String label;
  final String subtitle;
  final File? file;
  final VoidCallback onTap;

  const _DocumentPicker({
    required this.label,
    required this.subtitle,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightOutline),
        ),
        child: Row(
          children: [
            if (file != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(file!, width: 52, height: 52, fit: BoxFit.cover),
              )
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_file_rounded, color: AppTheme.primaryColor),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    file != null ? 'Selected — tap to change' : subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
