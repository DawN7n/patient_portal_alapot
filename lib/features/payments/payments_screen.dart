import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  static final PatientPortalRepository _repository = PatientPortalRepository();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          const PageHeading(
            'Payments & receipts',
            subtitle: 'Review payment records and official receipts issued by Alapot Dental Clinic.',
          ),
          const SizedBox(height: 12),
          const SurfaceCard(
            color: AppColors.sky,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: AppColors.deepTeal, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Only records saved by the clinic are shown here. An appointment request or estimated service price is not proof of payment.',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Payment history'),
          _recordsSection(
            stream: _repository.watchMyPayments(),
            emptyTitle: 'No payment records yet',
            emptyDescription:
                'Your clinic-recorded payments will appear here once the administrator posts them to your patient account.',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 18),
          const SectionTitle('Official receipts'),
          _recordsSection(
            stream: _repository.watchMyReceipts(),
            emptyTitle: 'No receipts issued yet',
            emptyDescription:
                'When the clinic issues a receipt, you will see its receipt number, service, date, amount, and payment method here.',
            icon: Icons.description_outlined,
            isReceipt: true,
          ),
          const SizedBox(height: 18),
          const SectionTitle('Need help with a payment?'),
          const SurfaceCard(
            child: Text(
              'For payment confirmation, billing questions, or receipt corrections, contact clinic reception. Do not share your password, verification code, or full payment-card details in chat.',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.muted,
                height: 1.55,
              ),
            ),
          ),
        ],
      );

  static Widget _recordsSection({
    required Stream<List<Map<String, dynamic>>> stream,
    required String emptyTitle,
    required String emptyDescription,
    required IconData icon,
    bool isReceipt = false,
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SurfaceCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SurfaceCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Could not load ${isReceipt ? 'receipts' : 'payment records'}. Check your connection or contact the clinic. (${snapshot.error})',
                    style: const TextStyle(fontSize: 11, height: 1.45),
                  ),
                ),
              ],
            ),
          );
        }

        final records = [...?snapshot.data];
        records.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));

        if (records.isEmpty) {
          return SurfaceCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.teal, size: 25),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emptyTitle,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(emptyDescription,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: records
              .map((record) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _recordCard(record, isReceipt: isReceipt),
                  ))
              .toList(growable: false),
        );
      },
    );
  }

  static Widget _recordCard(Map<String, dynamic> record,
      {required bool isReceipt}) {
    final recordId = _firstText([
      record['id'],
      record['_docId'],
      record['receipt_number'],
      record['receiptNumber'],
    ], fallback: isReceipt ? 'Clinic receipt' : 'Payment record');
    final service = _firstText([
      record['service'],
      record['service_name'],
      record['description'],
    ], fallback: isReceipt ? 'Dental service' : 'Clinic payment');
    final method = _firstText([
      record['method'],
      record['payment_method'],
      record['paymentMethod'],
    ], fallback: 'Not specified');
    final status = _firstText([
      record['status'],
      record['payment_status'],
      record['paymentStatus'],
    ], fallback: 'Recorded');
    final reference = _firstText([
      record['reference'],
      record['transaction_reference'],
      record['transactionId'],
    ]);
    final amount = _money(record['amount'] ?? record['total'] ?? record['total_amount']);
    final date = _dateLabel(record);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReceipt ? Icons.receipt_long_outlined : Icons.payments_outlined,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(recordId,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(amount,
                  style: const TextStyle(
                      color: AppColors.deepTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _detail(Icons.calendar_today_outlined, date),
              _detail(Icons.account_balance_wallet_outlined, method),
              _detail(Icons.info_outline, status),
            ],
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reference: $reference',
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 10)),
          ],
          finalNote(record),
        ],
      ),
    );
  }

  static Widget finalNote(Map<String, dynamic> record) {
    final note = _firstText([record['notes']]);
    if (note.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(note,
          style: const TextStyle(
              color: AppColors.muted, fontSize: 10, height: 1.45)),
    );
  }

  static Widget _detail(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.muted)),
        ],
      );

  static String _firstText(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  static String _money(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().replaceAll(',', '') ?? '');
    if (parsed == null) return 'Amount pending';
    return '₱${parsed.toStringAsFixed(2)}';
  }

  static DateTime _sortDate(Map<String, dynamic> record) {
    return _recordDate(record) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _dateLabel(Map<String, dynamic> record) {
    final date = _recordDate(record);
    if (date == null) return 'Date not recorded';
    final local = date.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
  }

  static DateTime? _recordDate(Map<String, dynamic> record) {
    for (final key in [
      'date',
      'paid_at',
      'paidAt',
      'createdAt',
      'created_at',
      'updatedAt',
    ]) {
      final value = record[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }
}
