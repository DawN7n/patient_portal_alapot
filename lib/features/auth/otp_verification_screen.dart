import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../services/auth_service.dart';
import '../shell/patient_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.prefs,
    required this.email,
    required this.password,
    required this.profile,
  });

  final SharedPreferences prefs;
  final String email;
  final String password;
  final Map<String, dynamic> profile;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otp = TextEditingController();
  final _auth = AuthService();
  bool _busy = false;
  bool _resending = false;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'invalid-argument':
          return error.message ?? 'Please check the information and try again.';
        case 'already-exists':
          return 'An account with this email already exists. Please log in.';
        case 'resource-exhausted':
          return error.message ?? 'Please wait before requesting another code.';
        case 'not-found':
          return 'No active verification was found. Please request a new code.';
        case 'permission-denied':
        case 'failed-precondition':
          return error.message ?? 'The code is invalid or has expired.';
        default:
          return error.message ?? 'Unable to verify your email right now.';
      }
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists. Please log in.';
        case 'weak-password':
          return 'Please choose a stronger password.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        default:
          return error.message ?? 'Unable to create your account.';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _verifyAndRegister() async {
    if (_otp.text.trim().length != 6) {
      _showMessage('Enter the complete 6-digit verification code.');
      return;
    }

    setState(() => _busy = true);
    try {
      final user = await _auth.registerPatient(
        email: widget.email,
        password: widget.password,
        otp: _otp.text.trim(),
        profile: widget.profile,
      );

      await widget.prefs.setString(
        'patient_name',
        widget.profile['name']?.toString() ?? user.displayName ?? 'Patient',
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PatientShell(
            prefs: widget.prefs,
            name: widget.profile['name']?.toString() ??
                user.displayName ??
                'Patient',
          ),
        ),
        (_) => false,
      );
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _auth.sendRegistrationOtp(widget.email);
      _otp.clear();
      _showMessage('A new verification code has been sent to your email.');
    } catch (error) {
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
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
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Image.asset(
                      'assets/images/alapot_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Verify your email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'We sent a 6-digit verification code to',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _otp,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                    fontSize: 25,
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: const TextStyle(
                      letterSpacing: 12,
                      color: Color(0xFFB8C5C7),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE3ECEC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE3ECEC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: AppColors.teal,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _verifyAndRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify and create account',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive the code? ",
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    TextButton(
                      onPressed: (_busy || _resending) ? null : _resend,
                      child: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Resend OTP'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'The code expires after 10 minutes. For your security, repeated incorrect attempts are limited.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.5,
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
