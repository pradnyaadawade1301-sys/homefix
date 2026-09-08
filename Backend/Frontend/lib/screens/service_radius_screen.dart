import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Lets the technician set how far they're willing to travel for jobs.
/// UI-only for now; wire the save action to your technician profile API.
class ServiceRadiusScreen extends StatefulWidget {
  const ServiceRadiusScreen({Key? key}) : super(key: key);

  @override
  State<ServiceRadiusScreen> createState() => _ServiceRadiusScreenState();
}

class _ServiceRadiusScreenState extends State<ServiceRadiusScreen> {
  double _radiusKm = 8;
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    // TODO: PATCH technician profile with new service radius.
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Service radius updated to ${_radiusKm.toStringAsFixed(0)} km')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Service Radius')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How far are you willing to travel?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text('You\'ll only see job requests within this distance from your location.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 32),
            Center(
              child: Text('${_radiusKm.toStringAsFixed(0)} km',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _radiusKm,
              min: 1,
              max: 30,
              divisions: 29,
              activeColor: AppTheme.primaryColor,
              label: '${_radiusKm.toStringAsFixed(0)} km',
              onChanged: (v) => setState(() => _radiusKm = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 km', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('30 km', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}