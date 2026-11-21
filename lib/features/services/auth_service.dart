import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please create your account first.');
    await user.sendEmailVerification();
  }

  // ============================================================
  // CLINIC-ISSUED PATIENT ID POLICY
  // ============================================================

  /// Self-service creation of a new clinic patient record is intentionally
  /// disabled. Clinic Admin verifies identity and issues the permanent
  /// Patient ID first. The patient then uses the existing-patient flow below.
  @Deprecated('Obtain a Patient ID from Alapot Dental Clinic before registering.')
  Future<User> registerPatient({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    throw StateError(
      'A clinic-issued Patient ID is required. Please contact Alapot Dental Clinic. Staff can verify your identity in person or through an official clinic call, then issue your Patient ID.',
    );
  }

  @Deprecated('Patient IDs are issued by clinic Admin after identity verification.')
  Future<User> completeNewPatientRegistration({
    required Map<String, dynamic> profile,
  }) async {
    throw StateError(
      'A clinic-issued Patient ID is required. Please contact Alapot Dental Clinic to verify your identity and receive your Patient ID.',
    );
  }

  @Deprecated('Use the existing-patient email verification flow.')
  Future<User> registerNewPatient({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    throw StateError(
      'Please obtain a Patient ID from the clinic first, then register using Existing Patient and verify your email.',
    );
  }

  // ============================================================
  // EXISTING PATIENT ACCOUNT LINK REQUEST
  // ============================================================

  /// Creates an Auth account and sends Firebase's built-in verification link.
  /// No Firestore link request is written until the patient verifies the email.
  Future<User> beginExistingPatientLinkVerification({
    required String email,
    required String password,
    required String name,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = name.trim();
    if (normalizedName.length < 2 || normalizedName.length > 120) {
      throw ArgumentError('Please enter a valid patient name.');
    }
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ArgumentError('Email and password are required.');
    }

    User? user = _auth.currentUser;
    var createdHere = false;
    if (user != null && (user.email ?? '').trim().toLowerCase() != normalizedEmail) {
      throw StateError(
        'Another Firebase account is currently signed in. Sign out before starting a different account-link request.',
      );
    }

    if (user == null) {
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        user = credential.user;
        createdHere = true;
      } on FirebaseAuthException catch (error) {
        // Recover safely if a previous attempt created the Auth identity but
        // the app was closed before the Firestore link request was submitted.
        if (error.code != 'email-already-in-use') rethrow;
        final credential = await _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        user = credential.user;
      }
    }

    if (user == null || (user.email ?? '').trim().toLowerCase() != normalizedEmail) {
      throw StateError('Firebase could not confirm the account email.');
    }

    // Do not let an already linked patient, dentist, or admin reuse the
    // existing email to start a second patient-link request.
    final mappedUser = await _firestore.collection('users').doc(user.uid).get();
    if (mappedUser.exists) {
      await _auth.signOut();
      throw StateError(
        'This email already has a clinic portal account. Please use the login screen.',
      );
    }

    try {
      await user.updateDisplayName(normalizedName);
      await user.reload();
      user = _auth.currentUser;
      if (user == null) throw StateError('Your Firebase session expired. Please try again.');
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
      return user;
    } catch (_) {
      if (createdHere) {
        try {
          await _auth.currentUser?.delete();
        } catch (_) {
          // Preserve the original error. A failed cleanup can be resumed by
          // signing in with the same email and password on the next attempt.
        }
      }
      rethrow;
    }
  }

  /// Writes a pending link request only after Firebase confirms the email.
  /// Admin approval later performs the one-to-one users/{uid} <->
  /// patients/{patientId} link in one Firestore commit.
  Future<void> submitVerifiedExistingPatientLinkRequest({
    required String patientId,
    required String name,
    required String phone,
  }) async {
    var user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please return to the verification screen and sign in again.');
    }

    await user.reload();
    user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Please verify your email using the link we sent first.');
    }
    await user.getIdToken(true);

    final normalizedPatientId = patientId.trim().toUpperCase();
    if (!RegExp(r'^PT-[A-Z0-9][A-Z0-9-]{0,23}$').hasMatch(normalizedPatientId)) {
      throw ArgumentError('Enter a valid clinic Patient ID.');
    }

    final normalizedEmail = (user.email ?? '').trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw StateError('Your verified Firebase email could not be read.');
    }

    final requestRef = _firestore
        .collection('patientAccountLinkRequests')
        .doc(user.uid);
    final existingRequest = await requestRef.get();
    if (existingRequest.exists) {
      final existingData = existingRequest.data() ?? <String, dynamic>{};
      final existingStatus = (existingData['status'] ?? '').toString().toLowerCase();
      if (existingData['patient_id'] == normalizedPatientId &&
          existingStatus == 'pending' &&
          existingData['email_verified'] == true &&
          existingData['verification_method'] == 'firebase-email-link') {
        await _auth.signOut();
        return;
      }
      if (existingStatus == 'pending') {
        throw StateError(
          'An older account-link request is still pending and cannot be upgraded safely. Please contact the clinic and ask Admin to close the old request; then submit a fresh request after verifying your email.',
        );
      }
      if (existingStatus == 'rejected' || existingStatus == 'cancelled') {
        await requestRef.update({
          'patient_id': normalizedPatientId,
          'requester_name': name.trim(),
          'phone': phone.trim(),
          'email_verified': true,
          'verification_method': 'firebase-email-link',
          'email_verified_at': DateTime.now().toIso8601String(),
          'account_created_at': user.metadata.creationTime?.toIso8601String() ?? '',
          'status': 'Pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _auth.signOut();
        return;
      }
      throw StateError(
        'A link request is already being reviewed for this account. Please wait for the clinic decision.',
      );
    }

    try {
      await requestRef.set({
        'patient_id': normalizedPatientId,
        'requester_uid': user.uid,
        'requester_email': normalizedEmail,
        'requester_name': name.trim(),
        'phone': phone.trim(),
        'email_verified': true,
        'verification_method': 'firebase-email-link',
        'email_verified_at': DateTime.now().toIso8601String(),
        'account_created_at': user.metadata.creationTime?.toIso8601String() ?? '',
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'not-found') {
        throw StateError(
          'The Patient ID was not found, has not yet been verified and issued by the clinic, or is already linked to another account. Check the ID or contact Alapot Dental Clinic.',
        );
      }
      rethrow;
    }

    // Patient must wait for Admin review before the clinic record is exposed.
    await _auth.signOut();
  }

  // ============================================================
  // PATIENT LOGIN
  // ============================================================

  Future<String> signInPatient({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    var user = credential.user;

    if (user == null) {
      throw StateError('Unable to sign in. Please try again.');
    }

    try {
      await user.reload();
      user = _auth.currentUser;
      if (user == null || !user.emailVerified) {
        await _auth.signOut();
        throw StateError('Please verify your email before signing in. Check your inbox for the Firebase verification link.');
      }
      // Find the Firebase account mapping.
      final userSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      // Check whether an existing clinic patient is awaiting approval.
      if (!userSnapshot.exists) {
        final requestSnapshot = await _firestore
            .collection('patientAccountLinkRequests')
            .doc(user.uid)
            .get();

        if (requestSnapshot.exists) {
          final requestData =
              requestSnapshot.data() ?? <String, dynamic>{};

          final status =
              requestData['status']?.toString().toLowerCase();

          await _auth.signOut();

          if (status == 'pending') {
            throw StateError(
              'Your account linking request is still awaiting '
              'clinic approval. Please try again later.',
            );
          }

          if (status == 'rejected' || status == 'cancelled') {
            final reason = (requestData['cancellationReason'] ?? requestData['rejectionNote'] ?? '').toString().trim();
            throw StateError(
              reason.isEmpty
                  ? 'Your account-link request was cancelled. Please contact the clinic before submitting another request.'
                  : 'Your account-link request was cancelled: $reason',
            );
          }
        }

        await _auth.signOut();

        throw StateError(
          'No approved patient profile is connected to this account. '
          'Please contact the clinic.',
        );
      }

      final userData =
          userSnapshot.data() ?? <String, dynamic>{};

      if (userData['role'] != 'patient') {
        await _auth.signOut();

        throw StateError(
          'This account is not registered as a patient account.',
        );
      }

      if (userData['active'] != true) {
        await _auth.signOut();

        throw StateError(
          'This patient account is inactive. Please contact the clinic.',
        );
      }

      final patientId =
          userData['patient_id']?.toString() ?? '';

      final patientDocId =
          userData['patient_doc_id']?.toString() ?? '';

      if (patientId.isEmpty || patientDocId != patientId) {
        await _auth.signOut();

        throw StateError(
          'Your patient account mapping is incomplete. '
          'Please contact the clinic.',
        );
      }

      // Retrieve the permanent clinic patient record.
      final patientSnapshot = await _firestore
          .collection('patients')
          .doc(patientId)
          .get();

      if (!patientSnapshot.exists) {
        await _auth.signOut();

        throw StateError(
          'Your clinic patient record could not be found.',
        );
      }

      final patientData =
          patientSnapshot.data() ?? <String, dynamic>{};

      if (patientData['auth_uid'] != user.uid ||
          patientData['id'] != patientId) {
        await _auth.signOut();

        throw StateError(
          'Your patient account could not be verified. '
          'Please contact the clinic.',
        );
      }

      if (patientData['status']?.toString().toLowerCase() ==
          'disabled') {
        await _auth.signOut();

        throw StateError(
          'This patient account is currently disabled.',
        );
      }

      return (
        patientData['name'] ??
        user.displayName ??
        'Patient'
      ).toString();
    } catch (_) {
      if (_auth.currentUser != null) {
        try {
          await _auth.signOut();
        } catch (_) {
          // Preserve the original error.
        }
      }

      rethrow;
    }
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;
}
