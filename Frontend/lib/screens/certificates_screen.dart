import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/technician_theme.dart';
import '../providers/category_provider.dart';

/// Lets the technician upload professional certificates. Reuses the same
/// image-picker pattern as the KYC screen. Each picked image
/// is uploaded and the URL list saved via PATCH /technicians/me/settings.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({Key? key}) : super(key: key);

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _picker = ImagePicker();
  final List<String> _certificates = []; // uploaded certificate URLs
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<TechnicianKycProvider>().loadSettings();
    if (!mounted) return;
    final list = s['certificates'];
    if (list is List) setState(() => _certificates..clear()..addAll(list.whereType<String>()));
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _addCertificate() async {
    if (_busy) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final provider = context.read<TechnicianKycProvider>();
    final url = await provider.uploadFile(File(picked.path));
    if (!mounted) return;
    if (url == null) {
      setState(() => _busy = false);
      _toast(provider.error ?? 'Could not upload certificate');
      return;
    }
    final updated = [..._certificates, url];
    final ok = await provider.saveSettings({'certificates': updated});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _certificates.add(url);
    });
    _toast(ok ? 'Certificate saved' : (provider.error ?? 'Could not save certificate'));
  }

  Future<void> _remove(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    final provider = context.read<TechnicianKycProvider>();
    final updated = [..._certificates]..removeAt(index);
    final ok = await provider.saveSettings({'certificates': updated});
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _certificates.removeAt(index);
    });
    if (!ok) _toast(provider.error ?? 'Could not remove certificate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Certificates')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload trade certificates, training completions, or licenses that build customer trust.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Expanded(
              child: _certificates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('No certificates uploaded yet', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _certificates.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(_certificates[index], fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image_outlined))),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _remove(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _addCertificate,
                style: OutlinedButton.styleFrom(foregroundColor: TechTheme.primary, side: const BorderSide(color: TechTheme.primary)),
                icon: const Icon(Icons.add_rounded),
                label: Text(_busy ? 'Please wait…' : 'Add Certificate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}