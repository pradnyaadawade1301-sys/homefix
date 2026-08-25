import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PolicySection(
            title: '1. Acceptance of Terms',
            body:
                'By creating an account or using HomeFix Live, you agree to be bound by these Terms & Conditions. '
                'If you do not agree, please do not use the app.',
          ),
          _PolicySection(
            title: '2. Services Provided',
            body:
                'HomeFix Live connects customers with independent technicians for home repair and maintenance '
                'services. HomeFix Live acts as a platform facilitating these connections and is not itself the '
                'service provider.',
          ),
          _PolicySection(
            title: '3. Customer Responsibilities',
            body:
                'Customers must provide accurate information when booking a service, including address and problem '
                'description. Customers are responsible for payments as agreed for completed services.',
          ),
          _PolicySection(
            title: '4. Technician Responsibilities',
            body:
                'Technicians registering on the platform must provide accurate identification and professional '
                'details. Technicians are independent contractors and are responsible for the quality of their own '
                'work.',
          ),
          _PolicySection(
            title: '5. Payments',
            body:
                'All payments made through the app are processed via supported payment methods. Refunds and '
                'disputes are handled according to the platform\'s dispute resolution process.',
          ),
          _PolicySection(
            title: '6. Cancellations',
            body:
                'Bookings may be cancelled subject to the cancellation policy in effect at the time of booking. '
                'Repeated cancellations may affect account standing.',
          ),
          _PolicySection(
            title: '7. Limitation of Liability',
            body:
                'HomeFix Live is not liable for damages arising from services performed by independent technicians. '
                'Disputes regarding service quality should be raised through the in-app dispute process.',
          ),
          _PolicySection(
            title: '8. Changes to Terms',
            body:
                'These terms may be updated periodically. Continued use of the app after changes constitutes '
                'acceptance of the revised terms.',
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _PolicySection(
            title: '1. Information We Collect',
            body:
                'We collect information you provide directly, such as your name, phone number, email, address, and '
                'for technicians, identification and professional details submitted during registration.',
          ),
          _PolicySection(
            title: '2. How We Use Your Information',
            body:
                'Your information is used to provide and improve our services, connect you with technicians or '
                'customers, process payments, send booking-related notifications, and ensure platform safety.',
          ),
          _PolicySection(
            title: '3. Location Data',
            body:
                'With your permission, we collect location data to match you with nearby technicians and to enable '
                'live tracking during a booking.',
          ),
          _PolicySection(
            title: '4. Data Sharing',
            body:
                'Your name, phone number and relevant booking details are shared with the technician or customer '
                'assigned to your booking, solely to facilitate the service.',
          ),
          _PolicySection(
            title: '5. Data Security',
            body:
                'We take reasonable technical and organizational measures to protect your personal data from '
                'unauthorized access, alteration, or disclosure.',
          ),
          _PolicySection(
            title: '6. Your Rights',
            body:
                'You may request access to, correction of, or deletion of your personal data by contacting support '
                'or through the account deletion option in the app.',
          ),
          _PolicySection(
            title: '7. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. Material changes will be communicated within '
                'the app.',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: Colors.grey[700], fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }
}