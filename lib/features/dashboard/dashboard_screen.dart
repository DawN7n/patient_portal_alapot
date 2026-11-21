import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../models/portal_models.dart';
import '../../shared/widgets/ui.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key, required this.name, required this.go, required this.onDentist});
  final String name;
  final ValueChanged<int> go;
  final ValueChanged<Dentist> onDentist;
  final PatientPortalRepository _repo = PatientPortalRepository();

  Dentist _dentist(Map<String, dynamic> d) {
    final full = (d['name'] ?? d['full_name'] ?? 'Dentist').toString();
    final exp = (d['experience'] ?? '').toString();
    final years = exp.isEmpty ? 'Experience not listed' : exp;
    final rating = (d['rating'] as num?)?.toDouble() ?? 0;
    return Dentist(
      id: (d['auth_uid'] ?? d['uid'] ?? d['id'] ?? d['_docId'] ?? '').toString(),
      name: full,
      specialty: (d['specialization'] ?? d['specialty'] ?? 'General Dentistry').toString(),
      experience: years,
      rating: rating,
      reviews: (d['review_count'] ?? d['reviews'] ?? 0) is num ? ((d['review_count'] ?? d['reviews'] ?? 0) as num).toInt() : 0,
      bio: (d['description'] ?? '').toString(),
      color: AppColors.sky,
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.teal, AppColors.deepTeal]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR SMILE, OUR PRIORITY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 14),
          Text('Welcome, $name', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Your clinic information and appointments are kept in sync with Alapot Dental Clinic.', style: TextStyle(color: Colors.white, fontSize: 11)),
          const SizedBox(height: 17),
          SizedBox(height: 43, child: ElevatedButton.icon(
            onPressed: () => go(9), icon: const Icon(Icons.calendar_month_rounded, size: 17),
            label: const Text('Book an appointment'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.deepTeal),
          )),
        ]),
      ),
      const SizedBox(height: 22),
      const SectionTitle('Your next visit'),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repo.watchMyAppointments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return SurfaceCard(child: Text('Appointments could not be loaded: ${snapshot.error}'));
          if (!snapshot.hasData) return const SurfaceCard(child: Center(child: CircularProgressIndicator()));
          final today = DateTime.now();
          final visits = snapshot.data!.where((a) {
            final status = (a['status'] ?? '').toString().toLowerCase();
            final date = DateTime.tryParse((a['date'] ?? '').toString());
            return date != null && !date.isBefore(DateTime(today.year, today.month, today.day)) && !['cancelled','completed','no-show'].contains(status);
          }).toList()..sort((a,b) => (a['date'] ?? '').toString().compareTo((b['date'] ?? '').toString()));
          if (visits.isEmpty) {
            return SurfaceCard(child: Row(children: [
            const Icon(Icons.event_available_outlined, color: AppColors.teal, size: 30),
            const SizedBox(width: 12),
            const Expanded(child: Text('You do not have an upcoming appointment yet.', style: TextStyle(fontSize: 12, color: AppColors.muted))),
            TextButton(onPressed: () => go(9), child: const Text('Book')),
          ]));
          }
          final a = visits.first;
          return SurfaceCard(onTap: () => go(1), child: Row(children: [
            const Icon(Icons.calendar_month_rounded, color: AppColors.teal, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((a['service'] ?? 'Dental appointment').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${a['date'] ?? ''} · ${a['time'] ?? ''}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              Text((a['dentist'] ?? 'Dentist to be confirmed').toString(), style: const TextStyle(color: AppColors.muted, fontSize: 10)),
              const SizedBox(height: 6), StatusPill((a['status'] ?? 'Pending').toString().toUpperCase(), color: AppColors.gold),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]));
        },
      ),
      const SizedBox(height: 22),
      SectionTitle('Meet our dentists', action: 'View all', onTap: () => go(3)),
      SizedBox(height: 178, child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repo.watchDentists(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Dentist directory unavailable: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final live = snapshot.data!.where((d) => (d['active'] ?? d['isActive'] ?? true) != false && (d['status'] ?? 'Active').toString().toLowerCase() != 'inactive').toList();
          if (live.isEmpty) return const SurfaceCard(child: Center(child: Text('No dentist profiles are published yet.', style: TextStyle(color: AppColors.muted, fontSize: 11))));
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: live.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final d = _dentist(live[i]);
              final parts = d.name.split(' ');
              final initials = parts.length > 1 ? '${parts[0][0]}${parts.last[0]}' : d.name.characters.take(2).toString();
              return SizedBox(width: 210, child: SurfaceCard(onTap: () => onDentist(d), padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Avatar(initials: initials.toUpperCase(), size: 48, color: AppColors.sky), const Spacer(), const Icon(Icons.verified_outlined, color: AppColors.teal, size: 18)]),
                const SizedBox(height: 9), Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(d.specialty, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                const Spacer(), Text(d.experience, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
              ])));
            },
          );
        },
      )),
      const SizedBox(height: 20),
      SectionTitle('Clinic updates', action: 'View all', onTap: () => go(6)),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _repo.watchPublishedAnnouncements(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return SurfaceCard(child: Text('Clinic updates unavailable: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const SurfaceCard(child: Text('There are no published clinic updates right now.', style: TextStyle(fontSize: 11, color: AppColors.muted)));
          return Column(children: items.take(2).map((a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SurfaceCard(onTap: () => go(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((a['title'] ?? 'Clinic update').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            Text((a['content'] ?? a['message'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            const SizedBox(height: 5), Text((a['date'] ?? a['createdAt'] ?? '').toString(), style: const TextStyle(fontSize: 9, color: AppColors.muted)),
          ])))).toList());
        },
      ),
    ],
  );
}
