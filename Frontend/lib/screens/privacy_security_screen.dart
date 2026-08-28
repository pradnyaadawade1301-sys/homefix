import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Privacy & Security settings — toggles for account security, data
/// sharing, and quick links to change password and blocked contacts.
/// Toggle states are local for now; wire to your settings API once ready.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _biometricLogin = false;
  bool _twoFactor = false;
  bool _shareLocationWithTechnician = true;
  bool _personalizedAds = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Login Security'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Biometric login', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Use fingerprint or face unlock to sign in', style: TextStyle(fontSize: 12.5)),
                value: _biometricLogin,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _biometricLogin = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Two-factor authentication', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Extra OTP step when logging in on a new device', style: TextStyle(fontSize: 12.5)),
                value: _twoFactor,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _twoFactor = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Data & Privacy'),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Share live location with technician', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Only during an active booking', style: TextStyle(fontSize: 12.5)),
                value: _shareLocationWithTechnician,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _shareLocationWithTechnician = v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Personalized ads', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                subtitle: const Text('Use activity to show more relevant offers', style: TextStyle(fontSize: 12.5)),
                value: _personalizedAds,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (v) => setState(() => _personalizedAds = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Account'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.block_outlined, color: AppTheme.primaryColor),
                title: const Text('Blocked contacts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No blocked contacts yet')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined, color: AppTheme.primaryColor),
                title: const Text('Download my data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('We will email you a copy of your data within 48 hours.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.grey)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}