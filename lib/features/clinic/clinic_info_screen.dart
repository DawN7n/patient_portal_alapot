import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/ui.dart';

class ClinicInfoScreen extends StatelessWidget {
  const ClinicInfoScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
    children: [
      const PageHeading(
        'Clinic information',
        subtitle: 'Official clinic details and visiting information.',
      ),
      SurfaceCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Image.asset('assets/images/alapot_logo.png', width: 62, height: 62, fit: BoxFit.contain),
          const SizedBox(width: 14),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Alapot Dental Clinic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Dental Care Beyond Ordinary!', style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
      const SizedBox(height: 18),
      const SectionTitle('Contact information'),
      const SurfaceCard(child: Column(children: [
        _InfoLine(Icons.email_outlined, 'Email address', 'Not yet published by the clinic administrator'),
        Divider(height: 20),
        _InfoLine(Icons.phone_outlined, 'Contact number', 'Not yet published by the clinic administrator'),
        Divider(height: 20),
        _InfoLine(Icons.location_on_outlined, 'Clinic address', 'Not yet published by the clinic administrator'),
        Divider(height: 20),
        _InfoLine(Icons.facebook, 'Clinic Facebook', 'Not yet published by the clinic administrator'),
        Divider(height: 20),
        _InfoLine(Icons.language, 'Clinic website', 'Not yet published by the clinic administrator'),
        Divider(height: 20),
        _InfoLine(Icons.map_outlined, 'Google Maps link', 'Not yet published by the clinic administrator'),
      ])),
      const SizedBox(height: 18),
      const SectionTitle('Operating hours'),
      const SurfaceCard(child: Column(children: [
        _InfoLine(Icons.calendar_today_outlined, 'Monday – Saturday', 'Hours not yet published'),
        Divider(height: 18),
        _InfoLine(Icons.event_busy_outlined, 'Sunday', 'Schedule not yet published'),
      ])),
      const SizedBox(height: 18),
      const SectionTitle('Before your appointment'),
      const SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Bullet('Arrive 10 minutes before your scheduled time.'),
        _Bullet('Bring relevant dental records or prescriptions, if available.'),
        _Bullet('Inform the clinic about allergies or medical concerns.'),
        _Bullet('Wait for clinic approval before treating a requested schedule as confirmed.'),
      ])),
      const SizedBox(height: 14),
      const Text(
        'Clinic contact details and operating hours are managed by the administrator. They will appear here after the clinic profile is published and connected to the patient app.',
        style: TextStyle(fontSize: 9, color: AppColors.muted, height: 1.5),
      ),
    ],
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.title, this.value);
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.teal),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: AppColors.muted, fontSize: 10, height: 1.5)),
      ])),
    ],
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, height: 1.5))),
    ]),
  );
}
