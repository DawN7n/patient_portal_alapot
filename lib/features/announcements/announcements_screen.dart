import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: PatientPortalRepository().watchPublishedAnnouncements(),
    builder: (context, snapshot) {
      final items = [...?snapshot.data]..sort((a,b) => (b['date'] ?? b['createdAt'] ?? '').toString().compareTo((a['date'] ?? a['createdAt'] ?? '').toString()));
      return ListView(padding: const EdgeInsets.all(22), children: [
        const PageHeading('Clinic updates', subtitle: 'Official news, reminders and information published by the clinic.'),
        if (snapshot.hasError) SurfaceCard(child: Text('Could not load clinic updates: ${snapshot.error}'))
        else if (!snapshot.hasData) const Center(child: CircularProgressIndicator())
        else if (items.isEmpty) const SurfaceCard(child: Text('There are no published announcements at the moment.', style: TextStyle(color: AppColors.muted, fontSize: 12)))
        else ...items.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.sky, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.campaign_outlined, color: AppColors.deepTeal)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((a['title'] ?? 'Clinic update').toString(), style: const TextStyle(fontWeight: FontWeight.w700)), Text((a['date'] ?? a['createdAt'] ?? '').toString(), style: const TextStyle(color: AppColors.muted, fontSize: 10))]))]),
          const SizedBox(height: 12), Text((a['content'] ?? a['message'] ?? '').toString(), style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.ink)),
        ])))),
      ]);
    },
  );
}
