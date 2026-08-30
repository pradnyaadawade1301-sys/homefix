import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/user_model.dart';
import '../booking/bookings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../technician/technician_jobs_screen.dart';
import '../technician/repeat_customers_screen.dart';
import '../personal_info_screen.dart';
import '../saved_addresses_screen.dart';
import '../legal_screens.dart';
import '../change_password_screen.dart';
import '../service_history_screen.dart';
import '../payment_methods_screen.dart';
import '../payment/transaction_history_screen.dart';
import '../privacy_security_screen.dart';
import '../help_center_screen.dart';
import '../contact_support_screen.dart';
import '../service_radius_screen.dart';
import '../bank_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  /// Optional anchor the Guided Tour can spotlight when it walks onto this
  /// screen. Attached to the AppBar title so it's always present, even while
  /// the profile is still loading.
  final GlobalKey? tourKey;

  const ProfileScreen({Key? key, this.tourKey}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userProvider = context.read<UserProvider>();
      await userProvider.fetchProfile();
      if (!mounted) return;

      if (userProvider.user?.isTechnician == true) {
        context.read<TechnicianKycProvider>().loadMyProfile();
      }
      final categoryProvider = context.read<CategoryProvider>();
      if (categoryProvider.categories.isEmpty) {
        categoryProvider.fetchCategories();
      }
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to book services.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This will permanently delete your account and all associated data. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    _openPlaceholder(context, 'Delete Account', Icons.delete_outline_rounded);
  }

  void _openPlaceholder(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PlaceholderScreen(title: title, icon: icon)),
    );
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _openChangePassword(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: Text('Profile', key: widget.tourKey)),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.user;
          if (userProvider.isLoading && user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (user == null) {
            return Center(
              child: SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Log In'),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: userProvider.fetchProfile,
            child: user.isTechnician
                ? _TechnicianProfileBody(
                    user: user,
                    onLogout: () => _confirmLogout(context),
                    onDelete: () => _confirmDeleteAccount(context),
                    openPlaceholder: (t, i) => _openPlaceholder(context, t, i),
                    openChangePassword: () => _openChangePassword(context),
                    openScreen: (w) => _openScreen(context, w),
                  )
                : _CustomerProfileBody(
                    user: user,
                    onLogout: () => _confirmLogout(context),
                    onDelete: () => _confirmDeleteAccount(context),
                    openPlaceholder: (t, i) => _openPlaceholder(context, t, i),
                    openChangePassword: () => _openChangePassword(context),
                    openScreen: (w) => _openScreen(context, w),
                  ),
          );
        },
      ),
    );
  }
}

typedef _OpenPlaceholder = void Function(String title, IconData icon);

// ============================================================================
// CUSTOMER PROFILE
// ============================================================================

class _CustomerProfileBody extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;
  final VoidCallback onDelete;
  final _OpenPlaceholder openPlaceholder;
  final VoidCallback openChangePassword;
  final void Function(Widget) openScreen;

  const _CustomerProfileBody({
    required this.user,
    required this.onLogout,
    required this.onDelete,
    required this.openPlaceholder,
    required this.openChangePassword,
    required this.openScreen,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _ProfileHeader(
          name: user.name.isNotEmpty ? user.name : 'Guest',
          subtitle: user.phone,
          roleLabel: 'Customer',
          photoUrl: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? user.photoUrl : null,
          verifiedBadge: user.phoneVerified,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Account',
          children: [
            _ActionTile(
              icon: Icons.person_outline_rounded,
              label: 'Personal Information',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.location_on_outlined,
              label: 'Saved Addresses',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.history_rounded,
              label: 'Service History',
              onTap: () => openScreen(const ServiceHistoryScreen()),
            ),
            _ActionTile(
              icon: Icons.calendar_month_outlined,
              label: 'Bookings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookingsScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.payment_outlined,
              label: 'Payment Methods',
              onTap: () => openScreen(const PaymentMethodsScreen()),
            ),
            _ActionTile(
              icon: Icons.receipt_long_outlined,
              label: 'Transaction History',
              onTap: () => openScreen(const TransactionHistoryScreen()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'App Settings',
          children: [
            _ActionTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Support',
          children: [
            _ActionTile(
              icon: Icons.help_outline_rounded,
              label: 'Help Center',
              onTap: () => openScreen(const HelpCenterScreen()),
            ),
            
            _ActionTile(
              icon: Icons.support_agent_outlined,
              label: 'Contact Support',
              onTap: () => openScreen(const ContactSupportScreen()),
            ),
            _ActionTile(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.shield_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            label: const Text('Log Out', style: TextStyle(color: AppTheme.errorColor)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.errorColor)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onDelete,
          child: const Text('Delete Account', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

// ============================================================================
// TECHNICIAN PROFILE
// ============================================================================

class _TechnicianProfileBody extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;
  final VoidCallback onDelete;
  final _OpenPlaceholder openPlaceholder;
  final VoidCallback openChangePassword;
  final void Function(Widget) openScreen;

  const _TechnicianProfileBody({
    required this.user,
    required this.onLogout,
    required this.onDelete,
    required this.openPlaceholder,
    required this.openChangePassword,
    required this.openScreen,
  });

  @override
  State<_TechnicianProfileBody> createState() => _TechnicianProfileBodyState();
}

class _TechnicianProfileBodyState extends State<_TechnicianProfileBody> {
  bool _togglingAvailability = false;

  Future<void> _onToggleAvailability(bool value) async {
    if (_togglingAvailability) return;
    setState(() => _togglingAvailability = true);
    final ok = await context.read<TechnicianKycProvider>().setAvailability(value);
    if (mounted) setState(() => _togglingAvailability = false);
    if (!ok && mounted) {
      final error = context.read<TechnicianKycProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not update availability. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TechnicianKycProvider, CategoryProvider>(
      builder: (context, kycProvider, categoryProvider, _) {
        final profile = kycProvider.profile;

        if (kycProvider.isLoading && profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (profile == null) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ProfileHeader(
                name: widget.user.name.isNotEmpty ? widget.user.name : 'Technician',
                subtitle: widget.user.phone,
                roleLabel: 'Technician',
                photoUrl: (widget.user.photoUrl != null && widget.user.photoUrl!.isNotEmpty) ? widget.user.photoUrl : null,
                verifiedBadge: widget.user.phoneVerified,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.badge_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'You haven\'t completed technician registration yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/technician-kyc'),
                      child: const Text('Complete Registration'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                  label: const Text('Log Out', style: TextStyle(color: AppTheme.errorColor)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.errorColor)),
                ),
              ),
            ],
          );
        }

        String categoryName = profile.categoryId;
        for (final c in categoryProvider.categories) {
          if (c.id == profile.categoryId) {
            categoryName = c.name;
            break;
          }
        }

        final isOnline = profile.isAvailable;
        final canGoOnline = profile.isApproved;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _ProfileHeader(
              name: widget.user.name.isNotEmpty ? widget.user.name : 'Technician',
              subtitle: widget.user.phone,
              roleLabel: categoryName,
              photoUrl: profile.profilePhotoUrl.isNotEmpty ? profile.profilePhotoUrl : null,
              verifiedBadge: profile.isVerified,
              extra: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    icon: Icons.star_rounded,
                    label: profile.ratingCount > 0
                        ? '${profile.ratingAvg.toStringAsFixed(1)} (${profile.ratingCount})'
                        : 'No ratings yet',
                    color: Colors.amber[700]!,
                  ),
                  _ApprovalBadge(status: profile.approvalStatus),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isOnline ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                      color: isOnline ? AppTheme.successColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isOnline ? 'You are Online' : 'You are Offline',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(
                          canGoOnline
                              ? (isOnline ? 'Customers can book you right now' : "You won't receive new job requests")
                              : 'Complete KYC approval to go online',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (_togglingAvailability)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  else
                    Switch(
                      value: isOnline,
                      activeThumbColor: AppTheme.successColor,
                      onChanged: canGoOnline ? _onToggleAvailability : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Professional Details',
              children: [
                _InfoRow(label: 'Primary Service', value: categoryName),
                _InfoRow(label: 'Years of Experience', value: '${profile.experienceYears} yrs'),
                _InfoRow(label: 'Address', value: profile.address.isNotEmpty ? profile.address : '-'),
                _ActionTile(
                  icon: Icons.map_outlined,
                  label: 'Service Radius',
                  onTap: () => widget.openScreen(const ServiceRadiusScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Trust & Verification',
              children: [
                _VerificationRow(label: 'Phone Verified', verified: widget.user.phoneVerified),
                _VerificationRow(label: 'Profile Verified', verified: profile.isVerified),
                _VerificationRow(
                  label: 'Government ID Uploaded',
                  verified: profile.governmentIdUrl.isNotEmpty,
                ),
                if (profile.isRejected && profile.rejectionReason != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Rejection reason: ${profile.rejectionReason}',
                      style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Documents',
              children: [
                _VerificationRow(
                  label: 'Government ID',
                  verified: profile.governmentIdUrl.isNotEmpty,
                ),
                _ActionTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Bank / UPI Details',
                  onTap: () => widget.openScreen(const BankDetailsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Work',
              children: [
                _ActionTile(
                  icon: Icons.work_outline_rounded,
                  label: 'My Jobs',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TechnicianJobsScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.people_alt_outlined,
                  label: 'My Customers',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RepeatCustomersScreen()),
                  ),
                ),
                _ActionTile(
                  icon: Icons.videocam_rounded,
                  label: 'Live Consultation Requests',
                  onTap: () => Navigator.of(context).pushNamed('/consultation-requests'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'App Settings',
              children: [
                _ActionTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notification Settings',
                  onTap: () => widget.openPlaceholder('Notification Settings', Icons.notifications_outlined),
                ),
                _ActionTile(
                  icon: Icons.payment_outlined,
                  label: 'Payment Settings',
                  onTap: () => widget.openPlaceholder('Payment Settings', Icons.payment_outlined),
                ),
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy & Security',
                  onTap: () => widget.openScreen(const PrivacySecurityScreen()),
                ),
                _ActionTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password / PIN',
                  onTap: widget.openChangePassword,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Support',
              children: [
                _ActionTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help Center',
                  onTap: () => widget.openScreen(const HelpCenterScreen()),
                ),
                _ActionTile(
                  icon: Icons.support_agent_outlined,
                  label: 'Contact Support',
                  onTap: () => widget.openScreen(const ContactSupportScreen()),
                ),
                
                _ActionTile(
                  icon: Icons.description_outlined,
                  label: 'Terms & Conditions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                label: const Text('Log Out', style: TextStyle(color: AppTheme.errorColor)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.errorColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onDelete,
              child: const Text('Delete Account', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// SHARED WIDGETS
// ============================================================================

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final String roleLabel;
  final String? photoUrl;
  final bool verifiedBadge;
  final Widget? extra;

  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.roleLabel,
    required this.photoUrl,
    required this.verifiedBadge,
    this.extra,
  });

  static const Color _accent = Color(0xFF0F766E);
  static const Color _accentDark = Color(0xFF115E59);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, _accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.1),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _accent),
                        )
                      : null,
                ),
              ),
              if (verifiedBadge)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, color: _accent, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleLabel,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 12),
            extra!,
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13.5)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  final String label;
  final bool verified;

  const _VerificationRow({required this.label, required this.verified});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        verified ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: verified ? AppTheme.successColor : Colors.grey,
        size: 22,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
      trailing: verified
          ? const Text('Verified', style: TextStyle(color: AppTheme.successColor, fontSize: 12.5))
          : const Text('Pending', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  final String status;

  const _ApprovalBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = AppTheme.successColor;
        label = 'Approved';
        break;
      case 'rejected':
        color = AppTheme.errorColor;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending Approval';
    }
    return _StatChip(icon: Icons.verified_user_outlined, label: label, color: color);
  }
}

// ============================================================================
// PLACEHOLDER SCREEN
// ============================================================================

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We\'re working on this feature. It will be available in an upcoming update.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}