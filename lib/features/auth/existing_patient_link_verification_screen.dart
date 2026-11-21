import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../services/auth_service.dart';

class ExistingPatientLinkVerificationScreen extends StatefulWidget {
  const ExistingPatientLinkVerificationScreen({
    super.key,
    required this.email,
    required this.patientId,
    required this.name,
    required this.phone,
  });

  final String email;
  final String patientId;
  final String name;
  final String phone;

  @override
  State<ExistingPatientLinkVerificationScreen> createState() =>
      _ExistingPatientLinkVerificationScreenState();
}

class _ExistingPatientLinkVerificationScreenState
    extends State<ExistingPatientLinkVerificationScreen>
    with WidgetsBindingObserver {
  final AuthService _auth = AuthService();
  late final TextEditingController _patientId;
  bool _busy = false;
  bool _resending = false;
  bool _emailVerified = false;
  bool _checkingEmail = true;
  bool _submissionStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _patientId = TextEditingController(text: widget.patientId);
    WidgetsBinding.instance.addObserver(this);
    _refreshEmailVerification();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _patientId.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshEmailVerification();
    }
  }

  Future<void> _refreshEmailVerification() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    try {
      await currentUser?.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      final verified = refreshedUser?.emailVerified == true;
      setState(() {
        _emailVerified = verified;
        _checkingEmail = false;
      });
      if (verified && !_submissionStarted) {
        await _submit();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingEmail = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: AppColors.teal),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _auth.sendEmailVerification();
      _message('A new Firebase verification link has been sent.');
    } on FirebaseAuthException catch (error) {
      _message(_friendlyAuthError(error));
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'too-many-requests':
        return 'Too many attempts. Please wait before requesting another email.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again and restart account linking.';
      default:
        return error.message ?? 'Unable to send the verification email.';
    }
  }

  Future<void> _submit() async {
    if (_submissionStarted || _busy) return;
    final value = _patientId.text.trim().toUpperCase();
    if (!RegExp(r'^PT-[A-Z0-9][A-Z0-9-]{0,23}$').hasMatch(value)) {
      setState(() => _error = 'Enter the Patient ID provided by the clinic.');
      return;
    }

    _submissionStarted = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.submitVerifiedExistingPatientLinkRequest(
        patientId: value,
        name: widget.name,
        phone: widget.phone,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_rounded, color: AppColors.teal, size: 38),
          title: const Text('Email verified — request received'),
          content: const Text(
            'Your verified email and Patient ID have been sent to the clinic Admin for review. Clinic review may take a few minutes. Please wait for the Admin decision and do not create another account request. You can close this message now; your existing clinic record has not been duplicated.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      _submissionStarted = false;
      setState(() => _error = _friendlyAuthError(error));
    } catch (error) {
      _submissionStarted = false;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(26, 18, 26, 28),
              shrinkWrap: true,
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    size: 62, color: AppColors.teal),
                const SizedBox(height: 22),
                const Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _emailVerified
                      ? 'Your email address has been verified.'
                      : 'We sent a Firebase verification link to',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _emailVerified
                      ? 'Your email is verified. We are sending your existing-patient account-link request to the clinic automatically.'
                      : 'Open the email and tap Verify Email. Return to this app; when Firebase confirms the verification, your account-link request will be sent automatically.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _patientId,
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Existing clinic Patient ID',
                    hintText: 'PT-XXXXXXXX',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check the Patient ID carefully. The clinic will review your request before linking your existing records.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (!_emailVerified || _busy || _checkingEmail) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: (_busy || _checkingEmail)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_error == null ? 'Request submission is automatic' : 'Try submitting request again'),
                  ),
                ),
                const SizedBox(height: 10),
                if (!_emailVerified)
                  TextButton(
                    onPressed: (_busy || _checkingEmail) ? null : _refreshEmailVerification,
                    child: const Text('I verified my email — check status'),
                  ),
                if (!_emailVerified)
                  TextButton(
                    onPressed: (_busy || _resending || _checkingEmail)
                        ? null
                        : _resend,
                    child: _resending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend verification email'),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'After submission, you will need to wait for clinic Admin approval. Your existing patient record will not be duplicated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
