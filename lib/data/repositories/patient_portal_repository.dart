
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore repository shared by the Patient, Dentist, and Admin portals.
///
/// Patient identity structure:
///
/// users/{firebaseUid}
///   patient_id: PT-XXXXXXXX
///   patient_doc_id: PT-XXXXXXXX
///
/// patients/{patientId}
///   id: PT-XXXXXXXX
///   auth_uid: firebaseUid
///
/// Firebase UID is used for security-scoped ownership.
/// Clinic Patient ID is used for permanent patient record references.
class PatientPortalRepository {
  PatientPortalRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  String get currentUid => _auth.currentUser?.uid ?? '';

  // ============================================================
  // AUTHENTICATION AND PATIENT IDENTITY
  // ============================================================

  String _requireUid() {
    final uid = currentUid;

    if (uid.isEmpty) {
      throw StateError(
        'Your session has expired. Please sign in again.',
      );
    }

    return uid;
  }

  /// Resolves the authenticated Firebase user to the permanent
  /// clinic patient record.
  ///
  /// Returns null when the account does not yet have an approved
  /// patient mapping or the permanent patient record is unavailable.
  ///
  /// Throws if the mapping exists but the patient record belongs
  /// to a different Firebase account.
  Future<Map<String, dynamic>?> _loadMyPatientIdentity() async {
    final uid = _requireUid();

    // Step 1: Resolve Firebase UID through users/{uid}.
    final userSnapshot = await _db.collection('users').doc(uid).get();

    if (!userSnapshot.exists) {
      return null;
    }

    final userData =
        userSnapshot.data() ?? const <String, dynamic>{};

    final role = (userData['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (role != 'patient' || userData['active'] != true) {
      return null;
    }

    final patientId = _firstNonEmpty([
      userData['patient_id'],
      userData['patient_doc_id'],
    ]);

    if (patientId.isEmpty) {
      return null;
    }

    // Step 2: Load patients/{patientId}.
    final patientSnapshot =
        await _db.collection('patients').doc(patientId).get();

    if (!patientSnapshot.exists) {
      return null;
    }

    final patientData =
        patientSnapshot.data() ?? const <String, dynamic>{};

    final storedPatientId = _firstNonEmpty([
      patientData['id'],
    ]);

    final linkedUid = _firstNonEmpty([
      patientData['auth_uid'],
      patientData['uid'],
      patientData['user_uid'],
    ]);

    // Step 3: Verify both sides of the identity mapping.
    if (storedPatientId != patientId || linkedUid != uid) {
      throw StateError(
        'Your patient record does not match your authenticated account. '
        'Please contact the clinic.',
      );
    }

    return <String, dynamic>{
      ...patientData,
      '_docId': patientSnapshot.id,
    };
  }

  Future<Map<String, dynamic>> _requireMyPatientIdentity() async {
    final profile = await _loadMyPatientIdentity();

    if (profile == null) {
      throw StateError(
        'Your clinic Patient ID is not linked to your account. '
        'Please contact the clinic.',
      );
    }

    return profile;
  }

  // ============================================================
  // PATIENT PROFILE
  // ============================================================

  /// Watches the authenticated user's patient profile.
  ///
  /// First observes users/{uid}, then listens to patients/{patientId}.
  Stream<Map<String, dynamic>?> watchMyPatientProfile() {
    final uid = currentUid;

    if (uid.isEmpty) {
      return Stream<Map<String, dynamic>?>.value(null);
    }

    return _db.collection('users').doc(uid).snapshots().asyncExpand<
        Map<String, dynamic>?>((userSnapshot) {
      final userData =
          userSnapshot.data() ?? const <String, dynamic>{};

      final role = (userData['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final patientId = _firstNonEmpty([
        userData['patient_id'],
        userData['patient_doc_id'],
      ]);

      if (!userSnapshot.exists ||
          role != 'patient' ||
          userData['active'] != true ||
          patientId.isEmpty) {
        return Stream<Map<String, dynamic>?>.value(null);
      }

      return _db.collection('patients').doc(patientId).snapshots().map(
        (patientSnapshot) {
          if (!patientSnapshot.exists) {
            return null;
          }

          final patientData =
              patientSnapshot.data() ?? const <String, dynamic>{};

          final linkedUid = _firstNonEmpty([
            patientData['auth_uid'],
            patientData['uid'],
            patientData['user_uid'],
          ]);

          if (patientData['id']?.toString() != patientId ||
              linkedUid != uid) {
            return null;
          }

          return <String, dynamic>{
            ...patientData,
            '_docId': patientSnapshot.id,
          };
        },
      );
    });
  }

  Future<Map<String, dynamic>?> getMyPatientProfile() async {
    return _loadMyPatientIdentity();
  }

  Future<void> updateMyPatientProfile(
    Map<String, dynamic> changes,
  ) async {
    final profile = await _requireMyPatientIdentity();

    final patientDocumentId = _firstNonEmpty([
      profile['_docId'],
      profile['id'],
    ]);

    if (patientDocumentId.isEmpty) {
      throw StateError('Patient document ID is missing.');
    }

    // These fields are currently allowed by firestore.candidate.rules.
    const allowed = {
      'phone',
      'address',
      'emergency_contact',
      'emergency_phone',
    };

    final safeChanges = <String, dynamic>{};

    for (final entry in changes.entries) {
      if (allowed.contains(entry.key)) {
        safeChanges[entry.key] = entry.value;
      }
    }

    if (safeChanges.isEmpty) {
      return;
    }

    safeChanges['updatedAt'] = DateTime.now().toIso8601String();

    await _db
        .collection('patients')
        .doc(patientDocumentId)
        .update(safeChanges);
  }

  // ============================================================
  // PATIENT COLLECTION STREAMS
  // ============================================================

  // Match both the permanent clinic Patient ID and Firebase UID. This keeps
  // the query compatible with the stricter patient appointment read rule.
  Stream<List<Map<String, dynamic>>> watchMyAppointments() =>
      _watchPatientIdCollection('appointments', ownerField: 'patient_uid');

  Stream<List<Map<String, dynamic>>> watchMyNotifications() =>
      _watchPatientCollection('notifications', 'recipient_uid');

  Stream<List<Map<String, dynamic>>> watchMyReceipts() =>
      _watchPatientIdCollection('receipts');

  Stream<List<Map<String, dynamic>>> watchMyPayments() =>
      _watchPatientIdCollection('payments');

  Stream<List<Map<String, dynamic>>> watchMyReviews() =>
      _watchPatientCollection('reviews', 'patient_uid');

  Stream<List<Map<String, dynamic>>> watchMySupportTickets() =>
      _watchPatientCollection('supportTickets', 'patient_uid');

  Stream<List<Map<String, dynamic>>> watchMyConversations() =>
      _watchPatientCollection('conversations', 'patient_uid');

  // ============================================================
  // CLINIC DATA
  // ============================================================

Stream<List<Map<String, dynamic>>> watchPaymentMethods() =>
    _watchCollection(
      _db.collection('paymentMethods').where(
        'status',
        whereIn: const ['Active', 'Setup'],
      ),
    );

  Stream<List<Map<String, dynamic>>> watchDentists() =>
      _watchCollection(_db.collection('dentists'));

  Stream<List<Map<String, dynamic>>> watchServices() =>
      _watchCollection(_db.collection('services'));

  /// Only published announcements intended for patients are returned.
  Stream<List<Map<String, dynamic>>> watchPublishedAnnouncements() =>
      _watchCollection(
        _db.collection('announcements')
            .where('status', isEqualTo: 'Published')
            .where(
              'audience',
              whereIn: const [
                'All Patients',
                'Existing Patients',
                'New Patients',
              ],
            ),
      );

  Stream<Map<String, dynamic>?> watchClinicProfile() {
    return _db
        .collection('clinicSettings')
        .doc('main')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      return <String, dynamic>{
        ...?doc.data(),
        '_docId': doc.id,
      };
    });
  }

  // ============================================================
  // DENTAL CHART AND FILES
  // ============================================================

  Stream<Map<String, dynamic>?> watchMyDentalChart() {
    final uid = currentUid;

    if (uid.isEmpty) {
      return Stream<Map<String, dynamic>?>.value(null);
    }

    return _db.collection('users').doc(uid).snapshots().asyncExpand<Map<String, dynamic>?>((user) {
      final data = user.data() ?? const <String, dynamic>{};
      final patientId = _firstNonEmpty([data['patient_id'], data['patient_doc_id']]);
      if (!user.exists || patientId.isEmpty) return Stream<Map<String, dynamic>?>.value(null);
      return _db.collection('dentalCharts').doc(patientId).snapshots().map((doc) {
        if (!doc.exists) return null;
        return <String, dynamic>{...?doc.data(), '_docId': doc.id};
      });
    });
  }

  Stream<List<Map<String, dynamic>>> watchMyDentalChartHistory() {
    final uid = currentUid;

    if (uid.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _db.collection('users').doc(uid).snapshots().asyncExpand<List<Map<String, dynamic>>>((user) {
      final data = user.data() ?? const <String, dynamic>{};
      final patientId = _firstNonEmpty([data['patient_id'], data['patient_doc_id']]);
      if (!user.exists || patientId.isEmpty) return Stream<List<Map<String, dynamic>>>.value(const []);
      return _watchCollection(_db.collection('dentalChartHistory').doc(patientId).collection('entries'));
    });
  }

  /// File metadata is stored under:
  /// patientFiles/{clinicPatientId}/files/{fileId}.
  Stream<List<Map<String, dynamic>>> watchMyFiles() {
    final uid = currentUid;

    if (uid.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _db.collection('users').doc(uid).snapshots().asyncExpand<List<Map<String, dynamic>>>((user) {
      final data = user.data() ?? const <String, dynamic>{};
      final patientId = _firstNonEmpty([data['patient_id'], data['patient_doc_id']]);
      if (!user.exists || patientId.isEmpty) return Stream<List<Map<String, dynamic>>>.value(const []);
      return _watchCollection(_db.collection('patientFiles').doc(patientId).collection('files'));
    });
  }

  // ============================================================
  // CONVERSATION MESSAGES
  // ============================================================

  Stream<List<Map<String, dynamic>>> watchMessages(
    String conversationId,
  ) {
    if (currentUid.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _watchCollection(
      _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages'),
    );
  }

  // ============================================================
  // APPOINTMENT CREATION
  // ============================================================


Future<String> createAppointment({
  required Map<String, dynamic> patient,
  required Map<String, dynamic> dentist,
  required List<Map<String, dynamic>> services,
  required DateTime scheduledAt,
  required String time24h,
  required String paymentMethod,
  required String paymentMethodId,
  String? patientNotes,
}) async {
  final uid = _requireUid();

  if (services.isEmpty) {
    throw ArgumentError('Choose at least one service.');
  }

  if (paymentMethod.trim().isEmpty ||
      paymentMethodId.trim().isEmpty) {
    throw ArgumentError('Choose an available payment method.');
  }

  // Verify that the selected payment method still exists
  // and is currently Active in Admin's paymentMethods collection.
  final paymentMethodSnapshot =
      await _db.collection('paymentMethods').doc(paymentMethodId).get();

  if (!paymentMethodSnapshot.exists) {
    throw StateError(
      'This payment method is no longer available. '
      'Please select another method.',
    );
  }

  final paymentMethodData =
      paymentMethodSnapshot.data() ?? <String, dynamic>{};

  if (paymentMethodData['status'] != 'Active' ||
      paymentMethodData['name'] != paymentMethod) {
    throw StateError(
      'This payment method is no longer active. '
      'Please select another method.',
    );
  }

  if (time24h.trim().isEmpty) {
    throw ArgumentError('Choose an appointment time.');
  }

  if (_dateOnly(scheduledAt)
      .compareTo(_dateOnly(DateTime.now())) < 0) {
    throw ArgumentError('Choose a valid appointment date.');
  }

  // Verify the authenticated patient's permanent record.
  final storedPatient = await _requireMyPatientIdentity();

  final clinicPatientId = _firstNonEmpty([
    storedPatient['id'],
  ]);

  if (clinicPatientId.isEmpty) {
    throw StateError('Clinic Patient ID is missing.');
  }

  // Resolve the dentist Firebase account.
  final dentistUid = await _resolveDentistUid(dentist);

  if (dentistUid.isEmpty) {
    throw StateError(
      'This dentist profile is not linked to a Firebase account yet. '
      'Ask the clinic to finish the dentist account link.',
    );
  }

  final patientName = _firstNonEmpty([
    storedPatient['name'],
    patient['fullName'],
    patient['name'],
    _auth.currentUser?.displayName,
  ], fallback: 'Patient');

  final dentistName = _firstNonEmpty(
    [dentist['name']],
    fallback: 'Dentist',
  );

  final serviceNames = services
      .map(
        (item) => _firstNonEmpty(
          [item['name']],
          fallback: 'Dental service',
        ),
      )
      .toList(growable: false);

  final serviceIds = services
      .map(
        (item) => _firstNonEmpty([
          item['_docId'],
          item['id'],
        ]),
      )
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  final duration = services.fold<int>(0, (total, item) {
    final raw = item['durationMinutes'] ??
        item['duration'] ??
        item['duration_minutes'];

    return total +
        (raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0);
  });

  final amount = services.fold<num>(0, (total, item) {
    final raw = item['price'] ?? item['amount'];

    final price =
        raw is num ? raw : num.tryParse('$raw') ?? 0;

    return total + price;
  });

  if (amount <= 0) {
    throw ArgumentError(
      'The selected services have an invalid total price.',
    );
  }

  final date = _dateOnly(scheduledAt);
  final now = DateTime.now().toIso8601String();

  final appointment = <String, dynamic>{
    'id': '',

    // Patient identity.
    'patient_id': clinicPatientId,
    'patient_uid': uid,
    'patient_doc_id': clinicPatientId,

    'patient': patientName,
    'patient_name': patientName,

    'patient_snapshot': {
      'name': patientName,
      'phone': storedPatient['phone'] ??
          patient['phoneNumber'] ??
          patient['phone'] ??
          '',
      'email': storedPatient['email'] ??
          patient['email'] ??
          _auth.currentUser?.email ??
          '',
      'address': storedPatient['address'] ??
          patient['address'] ??
          '',
      'dob': storedPatient['dob'] ?? '',
      'gender': storedPatient['gender'] ??
          patient['gender'] ??
          '',
    },

    // Dentist.
    'dentist_id': dentistUid,
    'dentist': dentistName,

    // Services.
    'service_id': serviceIds.isNotEmpty ? serviceIds.first : '',
    'service_ids': serviceIds,
    'service': serviceNames.join(', '),

    // Schedule.
    'date': date,
    'time': _toDisplayTime(time24h),
    'time_24h': time24h,
    'duration': duration,

    // Appointment approval.
    'status': 'Pending',

    // Selected Admin-managed payment method.
    // Booking does not process payment.
    'payment_method': paymentMethod,
    'payment_method_id': paymentMethodId,
    'payment_status': 'Unpaid',
    'payment_provider': 'Manual',

    'notes': (patientNotes ?? '').trim(),
    'amount': amount,

    'source': 'patient-app',
    'booking_source': 'patient-app',

    'createdAt': now,
    'updatedAt': now,
  };

  final reference = _db.collection('appointments').doc();

  appointment['id'] = reference.id;

  await reference.set(appointment);

  return reference.id;
}


  // ============================================================
  // APPOINTMENT CANCELLATION
  // ============================================================

  Future<void> cancelMyAppointment(
    String appointmentId, {
    String reason = '',
  }) async {
    _requireUid();
    final patient = await _requireMyPatientIdentity();
    final patientId = _firstNonEmpty([patient['id'], patient['_docId']]);

    final reference =
        _db.collection('appointments').doc(appointmentId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data?['patient_id'] != patientId) {
      throw StateError(
        'This appointment does not belong to your account.',
      );
    }

    final status =
        (data?['status'] ?? '').toString().toLowerCase();

    if (!['pending', 'confirmed', 'rescheduled'].contains(status)) {
      throw StateError(
        'Only pending or confirmed appointments can be cancelled.',
      );
    }

    await reference.update({
      'status': 'Cancelled',
      'cancelled_by': 'patient',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancellation_reason': reason.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // APPOINTMENT RESCHEDULING
  // ============================================================

  /// Patient rescheduling is stored as a request for Admin review.
  /// The approved appointment date/time is not changed immediately.
  Future<void> requestAppointmentReschedule({
    required String appointmentId,
    required DateTime newDate,
    required String newTime24h,
    String reason = '',
  }) async {
    _requireUid();
    final patient = await _requireMyPatientIdentity();
    final patientId = _firstNonEmpty([patient['id'], patient['_docId']]);

    final reference =
        _db.collection('appointments').doc(appointmentId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data?['patient_id'] != patientId) {
      throw StateError(
        'This appointment does not belong to your account.',
      );
    }

    final status =
        (data?['status'] ?? '').toString().toLowerCase();

    if (!['pending', 'confirmed', 'rescheduled'].contains(status)) {
      throw StateError(
        'This appointment can no longer be rescheduled.',
      );
    }

    if (_dateOnly(newDate)
        .compareTo(_dateOnly(DateTime.now())) < 0) {
      throw ArgumentError('Choose a future appointment date.');
    }

    if (newTime24h.trim().isEmpty) {
      throw ArgumentError('Choose a new appointment time.');
    }

    final now = DateTime.now().toIso8601String();

    await reference.update({
      'reschedule_request_status': 'Pending',
      'requested_date': _dateOnly(newDate),
      'requested_time': _toDisplayTime(newTime24h),
      'requested_time_24h': newTime24h,
      'reschedule_reason': reason.trim(),
      'reschedule_requested_at': now,
      'updatedAt': now,
    });
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Future<void> markNotificationRead(
    String notificationDocumentId,
  ) async {
    final uid = _requireUid();

    final reference =
        _db.collection('notifications').doc(notificationDocumentId);

    final snapshot = await reference.get();

    if (!snapshot.exists ||
        snapshot.data()?['recipient_uid'] != uid) {
      throw StateError(
        'This notification does not belong to your account.',
      );
    }

    await reference.update({
      'read': true,
      'readAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ============================================================
  // PATIENT REVIEWS
  // ============================================================

  Future<void> submitReview({
    required String appointmentId,
    required String dentistUid,
    required String dentistName,
    required int rating,
    required String comment,
    required bool showName,
  }) async {
    final uid = _requireUid();
    final patient = await _requireMyPatientIdentity();
    final patientId = _firstNonEmpty([patient['id'], patient['_docId']]);

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be from 1 to 5.');
    }

    final appointmentRef =
        _db.collection('appointments').doc(appointmentId);

    final appointment = await appointmentRef.get();

    if (!appointment.exists ||
        appointment.data()?['patient_id'] != patientId) {
      throw StateError(
        'This appointment does not belong to your account.',
      );
    }

    if ((appointment.data()?['status'] ?? '')
            .toString()
            .toLowerCase() !=
        'completed') {
      throw StateError(
        'You can review an appointment after it is completed.',
      );
    }

    final now = DateTime.now().toIso8601String();

    await _db
        .collection('reviews')
        .doc('REV-$appointmentId')
        .set({
      'appointment_id': appointmentId,
      'patient_id': appointment.data()?['patient_id'] ?? '',
      'patient_uid': uid,
      'patient': showName
          ? (appointment.data()?['patient'] ?? 'Patient')
          : 'Anonymous',
      'patient_name': showName
          ? (appointment.data()?['patient'] ?? 'Patient')
          : 'Anonymous',
      'show_name': showName,
      'dentist_id': dentistUid,
      'dentist': dentistName,
      'rating': rating,
      'comment': comment.trim(),
      'moderation_status': 'pending',
      'status': 'Pending',
      'createdAt': now,
      'created_at': now,
    });
  }

  // ============================================================
  // PATIENT-DENTIST CONVERSATIONS
  // ============================================================

  Future<String> startConversation({
    required Map<String, dynamic> dentist,
    required String patientName,
  }) async {
    final uid = _requireUid();

    final patientProfile = await _requireMyPatientIdentity();

    final patientId = _firstNonEmpty([
      patientProfile['id'],
    ]);

    if (patientId.isEmpty) {
      throw StateError('Clinic Patient ID is missing.');
    }

    final dentistUid = await _resolveDentistUid(dentist);

    if (dentistUid.isEmpty) {
      throw StateError(
        'This dentist does not have a linked Firebase account yet. '
        'Please contact the clinic.',
      );
    }

    final conversationId = 'c_${uid}_$dentistUid';

    final reference =
        _db.collection('conversations').doc(conversationId);

    final existing = await reference.get();

    if (!existing.exists) {
      final now = DateTime.now().toIso8601String();

      await reference.set({
        'id': conversationId,
        'patient_uid': uid,
        'patient_id': patientId,
        'patient_name': patientName,
        'dentist_uid': dentistUid,
        'dentist_id': dentistUid,
        'dentist_name': _firstNonEmpty(
          [dentist['name']],
          fallback: 'Dentist',
        ),
        'last_message': '',
        'last_message_at': now,
        'last_sender_uid': uid,
        'patient_read_at': now,
        'dentist_read_at': null,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      final data = existing.data() ?? const <String, dynamic>{};

      if (data['patient_uid'] != uid ||
          data['dentist_uid'] != dentistUid) {
        throw StateError(
          'This conversation does not belong to your account.',
        );
      }
    }

    return conversationId;
  }

  Future<void> markConversationRead(
    String conversationId,
  ) async {
    final uid = _requireUid();

    final reference =
        _db.collection('conversations').doc(conversationId);

    final snapshot = await reference.get();

    if (!snapshot.exists ||
        snapshot.data()?['patient_uid'] != uid) {
      throw StateError(
        'This conversation does not belong to your account.',
      );
    }

    await reference.update({
      'patient_read_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendPatientMessage({
    required String conversationId,
    required String text,
    required String senderName,
  }) async {
    final uid = _requireUid();
    final cleaned = text.trim();

    if (cleaned.isEmpty || cleaned.length > 4000) {
      throw ArgumentError(
        'Enter a message of up to 4,000 characters.',
      );
    }

    final conversationRef =
        _db.collection('conversations').doc(conversationId);

    final conversation = await conversationRef.get();

    if (!conversation.exists ||
        conversation.data()?['patient_uid'] != uid) {
      throw StateError(
        'This conversation does not belong to your account.',
      );
    }

    final now = DateTime.now().toIso8601String();

    final messageRef = conversationRef.collection('messages').doc();

    final batch = _db.batch();

    batch.set(messageRef, {
      'id': messageRef.id,
      'conversation_id': conversationId,
      'sender_uid': uid,
      'sender_role': 'patient',
      'sender_name': senderName,
      'text': cleaned,
      'created_at': now,
    });

    batch.update(conversationRef, {
      'last_message': cleaned,
      'last_message_at': now,
      'last_sender_uid': uid,
      'updated_at': now,
      'patient_read_at': now,
      'dentist_read_at': null,
    });

    await batch.commit();
  }

  // ============================================================
  // SUPPORT TICKETS
  // ============================================================

  Future<String> createSupportTicket({
    required String subject,
    required String category,
    required String message,
    required String patientName,
    List<Map<String, String>>? conversation,
  }) async {
    final uid = _requireUid();

    final patientProfile = await _requireMyPatientIdentity();

    final patientId = _firstNonEmpty([
      patientProfile['id'],
    ]);

    if (patientId.isEmpty) {
      throw StateError('Clinic Patient ID is missing.');
    }

    final cleanedMessage = message.trim();
    final cleanedSubject = subject.trim();

    if (cleanedSubject.isEmpty || cleanedMessage.isEmpty) {
      throw ArgumentError('Enter a subject and a message.');
    }

    if (cleanedMessage.length > 4000) {
      throw ArgumentError(
        'Your message must not exceed 4,000 characters.',
      );
    }

    final now = DateTime.now().toIso8601String();

    final reference = _db.collection('supportTickets').doc();
    final ticketMessages = <Map<String, dynamic>>[];
    final sourceMessages = conversation ?? [
      {'role': 'user', 'content': cleanedMessage},
    ];
    for (final item in sourceMessages) {
      final role = item['role'] == 'assistant' ? 'assistant' : 'user';
      final content = (item['content'] ?? '').trim();
      if (content.isEmpty) continue;
      ticketMessages.add({
        'id': 'msg_${DateTime.now().microsecondsSinceEpoch}_${ticketMessages.length}',
        'sender': role == 'user' ? 'patient' : 'alapot_ai',
        'sender_role': role == 'user' ? 'patient' : 'bot',
        'sender_uid': uid,
        'name': role == 'user' ? patientName : 'Alapot AI',
        'time': _displayTime(DateTime.now()),
        'text': content,
        'createdAt': now,
      });
    }
    if (ticketMessages.isEmpty) {
      throw ArgumentError('The conversation is empty.');
    }

    await reference.set({
      'id': reference.id,
      'patient_uid': uid,
      'patient_id': patientId,
      'patient': patientName,
      'patient_name': patientName,
      'initials': _initials(patientName),
      'subject': cleanedSubject,
      'category': category,
      'status': 'waiting',
      'messages': ticketMessages,
      'preview': cleanedMessage,
      'last_message': cleanedMessage,
      'createdAt': now,
      'updatedAt': now,
    });

    return reference.id;
  }

  Future<void> appendSupportTicketMessage({
    required String ticketId,
    required String text,
    required String senderName,
    bool fromAi = false,
  }) async {
    final uid = _requireUid();

    final cleaned = text.trim();

    if (cleaned.isEmpty || cleaned.length > 4000) {
      throw ArgumentError(
        'Enter a message of up to 4,000 characters.',
      );
    }

    final reference =
        _db.collection('supportTickets').doc(ticketId);

    final snapshot = await reference.get();
    final data = snapshot.data();

    if (!snapshot.exists || data?['patient_uid'] != uid) {
      throw StateError(
        'This support ticket does not belong to your account.',
      );
    }

    if (data?['status'] == 'resolved') {
      throw StateError(
        'This support ticket has been resolved.',
      );
    }

    final messages = List<Map<String, dynamic>>.from(
      (data?['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          ),
    );

    final now = DateTime.now().toIso8601String();

    messages.add({
      'id': 'msg_${DateTime.now().microsecondsSinceEpoch}',
      'sender': fromAi ? 'alapot_ai' : 'patient',
      'sender_role': fromAi ? 'bot' : 'patient',
      'sender_uid': uid,
      'name': fromAi ? 'Alapot AI' : senderName,
      'time': _displayTime(DateTime.now()),
      'text': cleaned,
      'createdAt': now,
    });

    await reference.update({
      'messages': messages,
      'preview': cleaned,
      'last_message': cleaned,
      'updatedAt': now,
    });
  }

  // ============================================================
  // PRIVATE FIRESTORE STREAM HELPERS
  // ============================================================

  Stream<List<Map<String, dynamic>>> _watchPatientIdCollection(
    String collection, {
    String? ownerField,
  }) {
    final uid = currentUid;
    if (uid.isEmpty) return Stream<List<Map<String, dynamic>>>.value(const []);
    return _db.collection('users').doc(uid).snapshots().asyncExpand<List<Map<String, dynamic>>>((user) {
      final data = user.data() ?? const <String, dynamic>{};
      final patientId = _firstNonEmpty([data['patient_id'], data['patient_doc_id']]);
      if (!user.exists || patientId.isEmpty) return Stream<List<Map<String, dynamic>>>.value(const []);
      Query<Map<String, dynamic>> query = _db.collection(collection)
          .where('patient_id', isEqualTo: patientId);
      if (ownerField != null) {
        query = query.where(ownerField, isEqualTo: uid);
      }
      return _watchCollection(query);
    });
  }

  Stream<List<Map<String, dynamic>>> _watchPatientCollection(
    String collection,
    String ownerField,
  ) {
    final uid = currentUid;

    if (uid.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(const []);
    }

    return _watchCollection(
      _db.collection(collection).where(
            ownerField,
            isEqualTo: uid,
          ),
    );
  }

  Stream<List<Map<String, dynamic>>> _watchCollection(
    Query<Map<String, dynamic>> query,
  ) {
    return query.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        return <String, dynamic>{
          ...doc.data(),
          '_docId': doc.id,
        };
      }).toList(growable: false),
    );
  }

  // ============================================================
  // DENTIST ID RESOLUTION
  // ============================================================

  Future<String> _resolveDentistUid(
    Map<String, dynamic> dentist,
  ) async {
    final linkedUid = _firstNonEmpty([
      dentist['auth_uid'],
      dentist['uid'],
      dentist['firebase_uid'],
      dentist['firebaseUid'],
    ]);

    if (linkedUid.isNotEmpty) {
      return linkedUid;
    }

    final documentId = _firstNonEmpty([
      dentist['_docId'],
    ]);

    if (documentId.isNotEmpty &&
        !RegExp(r'^DEN-\d+$', caseSensitive: false)
            .hasMatch(documentId)) {
      return documentId;
    }

    final logicalId = _firstNonEmpty([
      dentist['id'],
      documentId,
    ]);

    if (logicalId.isEmpty) {
      return '';
    }

    final direct =
        await _db.collection('dentists').doc(logicalId).get();

    if (direct.exists) {
      final data = direct.data() ?? const <String, dynamic>{};

      final uid = _firstNonEmpty([
        data['auth_uid'],
        data['uid'],
        data['firebase_uid'],
        data['firebaseUid'],
      ]);

      if (uid.isNotEmpty) {
        return uid;
      }

      if (!RegExp(r'^DEN-\d+$', caseSensitive: false)
          .hasMatch(direct.id)) {
        return direct.id;
      }
    }

    final matches = await _db
        .collection('dentists')
        .where('id', isEqualTo: logicalId)
        .limit(1)
        .get();

    if (matches.docs.isEmpty) {
      return '';
    }

    final data = matches.docs.first.data();

    return _firstNonEmpty([
      data['auth_uid'],
      data['uid'],
      data['firebase_uid'],
      data['firebaseUid'],
      if (!RegExp(r'^DEN-\d+$', caseSensitive: false)
          .hasMatch(matches.docs.first.id))
        matches.docs.first.id,
    ]);
  }

  // ============================================================
  // GENERAL HELPERS
  // ============================================================

  static String _firstNonEmpty(
    Iterable<dynamic> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }

    return fallback;
  }

  static String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  static String _toDisplayTime(String value) {
    final parts = value.split(':');

    if (parts.length < 2) {
      return value;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return value;
    }

    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;

    return '$h:${minute.toString().padLeft(2, '0')} $suffix';
  }

  static String _displayTime(DateTime value) {
    final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final m = value.minute.toString().padLeft(2, '0');

    return '$h:$m ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _initials(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
  }
}
