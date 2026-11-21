import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.onBook, required this.onReviews});
  final VoidCallback onBook;
  final VoidCallback onReviews;
  @override State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _repo = PatientPortalRepository();
  final _search = TextEditingController();
  String _filter = 'All';
  bool _busy = false;
  @override void dispose() { _search.dispose(); super.dispose(); }

  String _status(Map<String,dynamic> a) => (a['status'] ?? 'Pending').toString();
  Color _statusColor(String s) { switch (s.toLowerCase()) { case 'completed': return AppColors.green; case 'confirmed': case 'approved': return AppColors.teal; case 'cancelled': case 'canceled': return AppColors.red; default: return AppColors.gold; } }

  Future<void> _cancel(Map<String,dynamic> appointment) async {
    final reason = TextEditingController();
    final approved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cancel appointment?'),
      content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason (optional)')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Keep appointment')), FilledButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('Submit cancellation'))],
    ));
    if (approved != true) { reason.dispose(); return; }
    setState(() => _busy = true);
    try { await _repo.cancelMyAppointment((appointment['_docId'] ?? appointment['id']).toString(), reason: reason.text); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancellation request failed: $e'))); }
    finally { reason.dispose(); if (mounted) setState(() => _busy = false); }
  }

  Future<void> _reschedule(Map<String,dynamic> appointment) async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: DateTime.now().add(const Duration(days: 1)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() => _busy = true);
    try { await _repo.requestAppointmentReschedule(appointmentId: (appointment['_docId'] ?? appointment['id']).toString(), newDate: date, newTime24h: '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}'); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reschedule request failed: $e'))); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override Widget build(BuildContext context) => StreamBuilder<List<Map<String,dynamic>>>(
    stream: _repo.watchMyAppointments(),
    builder: (context, snapshot) {
      final query = _search.text.trim().toLowerCase();
      final rows = [...?snapshot.data]..sort((a,b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
      final visible = rows.where((a) {
        final status = _status(a).toLowerCase();
        final filterOk = _filter == 'All' || (_filter == 'Upcoming' && ['pending','confirmed','rescheduled'].contains(status)) || (_filter == 'Completed' && status == 'completed') || (_filter == 'Cancelled' && ['cancelled','canceled'].contains(status));
        final text = '${a['id']} ${a['service']} ${a['dentist']} ${a['date']} ${a['status']}'.toLowerCase();
        return filterOk && (query.isEmpty || text.contains(query));
      }).toList();
      return ListView(padding: const EdgeInsets.all(22), children: [
        const PageHeading('Appointments', subtitle: 'View appointment requests and updates recorded by the clinic.'),
        PrimaryButton(label: 'Book an appointment', icon: Icons.add_rounded, onPressed: widget.onBook),
        const SizedBox(height: 16),
        TextField(controller: _search, onChanged: (_) => setState((){}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search appointment, service or dentist')),
        const SizedBox(height: 12),
        Wrap(spacing: 7, children: ['All','Upcoming','Completed','Cancelled'].map((v) => ChoiceChip(label: Text(v), selected: _filter==v, onSelected: (_) => setState(()=>_filter=v))).toList()),
        const SizedBox(height: 14),
        if (snapshot.hasError) SurfaceCard(child: Text('Appointments could not be loaded: ${snapshot.error}'))
        else if (!snapshot.hasData) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (visible.isEmpty) SurfaceCard(child: Column(children: [const Icon(Icons.event_busy_outlined, size: 34, color: AppColors.muted), const SizedBox(height: 8), const Text('No matching appointments', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Your actual clinic appointments will appear here when they are recorded.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)), if (rows.isEmpty) TextButton(onPressed: widget.onBook, child: const Text('Book an appointment'))]))
        else ...visible.map((a) {
          final status = _status(a);
          final statusLower = status.toLowerCase();
          final canChange = ['pending','confirmed','rescheduled'].contains(statusLower);
          return Padding(padding: const EdgeInsets.only(bottom: 11), child: SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text((a['service'] ?? 'Dental appointment').toString(), style: const TextStyle(fontWeight: FontWeight.w700))), StatusPill(status.toUpperCase(), color: _statusColor(status))]),
            const SizedBox(height: 7),
            Text('${a['date'] ?? 'Date not set'} · ${a['time'] ?? 'Time not set'}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            Text((a['dentist'] ?? 'Dentist to be confirmed').toString(), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if ((a['id'] ?? a['_docId'] ?? '').toString().isNotEmpty) Text('Reference: ${a['id'] ?? a['_docId']}', style: const TextStyle(fontSize: 9, color: AppColors.muted)),
            if (a['reschedule_request_status'] != null) Text('Reschedule request: ${a['reschedule_request_status']}', style: const TextStyle(fontSize: 10, color: AppColors.teal)),
            if (canChange) Align(alignment: Alignment.centerRight, child: Wrap(spacing: 5, children: [TextButton(onPressed: _busy ? null : () => _reschedule(a), child: const Text('Request reschedule')), TextButton(onPressed: _busy ? null : () => _cancel(a), style: TextButton.styleFrom(foregroundColor: AppColors.red), child: const Text('Cancel'))])),
          ])));
        }),
        const SizedBox(height: 8), TextButton.icon(onPressed: widget.onReviews, icon: const Icon(Icons.rate_review_outlined), label: const Text('View my reviews')),
        if (_busy) const LinearProgressIndicator(),
      ]);
    },
  );
}
