import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import 'technician_jobs_screen.dart';

/// Shown to a technician after KYC submission (or on every login) until an admin
/// approves their profile. Approved technicians are sent straight to
/// TechnicianJobsScreen (their jobs list, not the customer home/browse screen);
/// pending/rejected technicians see their status here instead.
class TechnicianStatusScreen extends StatefulWidget {
  const TechnicianStatusScreen({Key? key}) : super(key: key);

  @override
  State<TechnicianStatusScreen> createState() => _TechnicianStatusScreenState();
}

class _TechnicianStatusScreenState extends State<TechnicianStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await context.read<TechnicianKycProvider>().loadMyProfile();
    if (!mounted) return;
    final profile = context.read<TechnicianKycProvider>().profile;
    if (profile != null && profile.isApproved) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TechnicianJobsScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Status'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<TechnicianKycProvider>(
          builder: (context, kyc, _) {
            if (kyc.isLoading && kyc.profile == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = kyc.profile;
            if (profile == null) {
              // No KYC submitted yet — send them to fill it in.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacementNamed('/technician-kyc');
              });
              return const Center(child: CircularProgressIndicator());
            }

            final IconData icon;
            final Color color;
            final String title;
            final String message;

            if (profile.isRejected) {
              icon = Icons.cancel_rounded;
              color = AppTheme.errorColor;
              title = 'Application rejected';
              message = profile.rejectionReason?.isNotEmpty == true
                  ? profile.rejectionReason!
                  : 'Your KYC submission was not approved. Please contact support for details.';
            } else {
              icon = Icons.hourglass_top_rounded;
              color = AppTheme.warningColor;
              title = 'Under review';
              message = 'Your documents have been submitted and are being reviewed by our team. '
                  "This usually takes 24–48 hours — we'll notify you once approved.";
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(icon, size: 56, color: color),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.4)),
                  const SizedBox(height: 28),
                  if (profile.isRejected)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/technician-kyc'),
                        child: const Text('Resubmit documents'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('Refresh status'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}