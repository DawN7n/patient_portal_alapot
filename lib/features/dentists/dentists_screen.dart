import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../models/portal_models.dart';
import '../../shared/widgets/ui.dart';

class DentistsScreen extends StatelessWidget {
  const DentistsScreen({super.key, required this.onSelect});
  final ValueChanged<Dentist> onSelect;

  Dentist _toDentist(Map<String, dynamic> d) => Dentist(
    id: (d['auth_uid'] ?? d['uid'] ?? d['id'] ?? d['_docId'] ?? '').toString(),
    name: (d['name'] ?? d['full_name'] ?? 'Dentist').toString(),
    specialty: (d['specialization'] ?? d['specialty'] ?? 'General Dentistry').toString(),
    experience: (d['experience'] ?? '').toString(),
    rating: (d['rating'] as num?)?.toDouble() ?? 0,
    reviews: (d['review_count'] ?? d['reviews'] ?? 0) is num ? ((d['review_count'] ?? d['reviews'] ?? 0) as num).toInt() : 0,
    bio: (d['description'] ?? '').toString(),
    color: AppColors.sky,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: PatientPortalRepository().watchDentists(),
    builder: (context, snapshot) {
      final dentists = [...?snapshot.data].where((d) => (d['active'] ?? d['isActive'] ?? true) != false && (d['status'] ?? 'Active').toString().toLowerCase() != 'inactive').map(_toDentist).toList();
      return ListView(padding: const EdgeInsets.all(22), children: [
        const PageHeading('Our dentists', subtitle: 'View the dentist profiles maintained by Alapot Dental Clinic.'),
        const SurfaceCard(color: AppColors.peach, child: Row(children: [Icon(Icons.health_and_safety_rounded, color: AppColors.coral, size: 28), SizedBox(width: 12), Expanded(child: Text('Professional dental care, delivered with a gentle touch.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)))])),
        const SizedBox(height: 16),
        if (snapshot.hasError) SurfaceCard(child: Text('Dentist directory could not be loaded: ${snapshot.error}'))
        else if (!snapshot.hasData) const Center(child: CircularProgressIndicator())
        else if (dentists.isEmpty) const SurfaceCard(child: Text('No active dentist profiles are currently available.', style: TextStyle(color: AppColors.muted, fontSize: 12)))
        else ...dentists.map((d) => Padding(padding: const EdgeInsets.only(bottom: 12), child: SurfaceCard(onTap: () => onSelect(d), child: Row(children: [
          Avatar(initials: _initials(d.name), size: 58, color: AppColors.sky), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), Text(d.specialty, style: const TextStyle(color: AppColors.teal, fontSize: 11)), if (d.experience.isNotEmpty) Text(d.experience, style: const TextStyle(color: AppColors.muted, fontSize: 10)), if (d.rating > 0) Text('★ ${d.rating.toStringAsFixed(1)}${d.reviews > 0 ? ' · ${d.reviews} reviews' : ''}', style: const TextStyle(color: AppColors.gold, fontSize: 10))])), const Icon(Icons.chevron_right, color: AppColors.muted),
        ])))),
      ]);
    },
  );

  static String _initials(String name) { final parts = name.trim().split(RegExp(r'\s+')); return parts.length > 1 ? '${parts.first[0]}${parts.last[0]}'.toUpperCase() : name.characters.take(2).toString().toUpperCase(); }
}

class DentistDetailScreen extends StatelessWidget {
  const DentistDetailScreen({super.key, required this.dentist, required this.onBook, required this.onMessage});
  final Dentist dentist;
  final VoidCallback onBook, onMessage;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(22), children: [
    const Text('Dentist profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    SurfaceCard(child: Column(children: [
      Avatar(initials: dentist.name.split(' ').length > 1 ? '${dentist.name.split(' ').first[0]}${dentist.name.split(' ').last[0]}' : dentist.name.characters.take(2).toString(), size: 94, color: AppColors.sky),
      const SizedBox(height: 13), Text(dentist.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      Text(dentist.specialty, style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
      if (dentist.experience.isNotEmpty) Text(dentist.experience, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      if (dentist.bio.isNotEmpty) ...[const SizedBox(height: 10), Text(dentist.bio, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted))],
      const SizedBox(height: 16), PrimaryButton(label: 'Book an appointment', onPressed: onBook),
      const SizedBox(height: 8), OutlinedButton.icon(onPressed: onMessage, icon: const Icon(Icons.chat_bubble_outline), label: const Text('Message dentist')),
    ])),
    const SizedBox(height: 18),
    const SurfaceCard(child: Text('Patient feedback is shown after it has been submitted and published by the clinic.', style: TextStyle(fontSize: 11, color: AppColors.muted))),
  ]);
}
