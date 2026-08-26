import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/category_provider.dart';

/// Technician availability control — a master online/offline toggle.
///
/// FIXED: this used to be UI-only (a local setState switch that never told
/// the backend anything). That meant `is_available` in the DB never
/// actually changed no matter what a technician tapped here — and since
/// both the "nearest available technician" match AND the preferred-
/// technician video-call check require `is_available = true`, a
/// technician could look "Online" in this screen while still being
/// completely invisible/unbookable to customers. Now the switch calls
/// PATCH /technicians/:id/availability (via [TechnicianKycProvider]) and
/// reflects the real, persisted value.
class AvailabilityToggleScreen extends StatefulWidget {
  const AvailabilityToggleScreen({Key? key}) : super(key: key);

  @override
  State<AvailabilityToggleScreen> createState() => _AvailabilityToggleScreenState();
}

class _AvailabilityToggleScreenState extends State<AvailabilityToggleScreen> {
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianKycProvider>().loadMyProfile();
    });
  }

  Future<void> _onToggle(bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final ok = await context.read<TechnicianKycProvider>().setAvailability(value);
    if (mounted) setState(() => _toggling = false);
    if (!ok && mounted) {
      final error = context.read<TechnicianKycProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not update availability. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Availability')),
      body: Consumer<TechnicianKycProvider>(
        builder: (context, kyc, _) {
          if (kyc.isLoading && kyc.profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = kyc.profile;
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  kyc.error ?? 'Could not load your technician profile.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final isOnline = profile.isAvailable;
          final canGoOnline = profile.isApproved;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!canGoOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          profile.isPending
                              ? 'Your KYC is still pending admin approval. You can\'t receive job requests until you\'re approved.'
                              : 'Your KYC was rejected${profile.rejectionReason != null ? ': ${profile.rejectionReason}' : '.'} You can\'t receive job requests.',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (isOnline ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                        color: isOnline ? AppTheme.successColor : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isOnline ? 'You are Online' : 'You are Offline',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                            isOnline ? 'Customers can book you right now' : 'You won\'t receive new job requests',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (_toggling)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Switch(
                        value: isOnline,
                        activeThumbColor: AppTheme.successColor,
                        onChanged: canGoOnline ? _onToggle : null,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}