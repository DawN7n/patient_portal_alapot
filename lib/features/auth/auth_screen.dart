import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../services/auth_service.dart';
import '../shell/patient_shell.dart';
import '../startup/onboarding_screen.dart';
import 'existing_patient_link_verification_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.prefs,
    this.showOnboarding = false,
  });

  final SharedPreferences prefs;
  final bool showOnboarding;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();

  bool register = false;
  bool obscure = true;
  bool busy = false;
  bool _resumeExistingLinkChecked = false;

  static const _pendingLinkEmailKey = 'pending_existing_link_email';
  static const _pendingLinkPatientIdKey = 'pending_existing_link_patient_id';
  static const _pendingLinkNameKey = 'pending_existing_link_name';
  static const _pendingLinkPhoneKey = 'pending_existing_link_phone';

  String registrationType = 'existing';

  bool get isExistingPatient => registrationType == 'existing';

  final form = GlobalKey<FormState>();

  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final birthDate = TextEditingController();
  final gender = TextEditingController();
  final address = TextEditingController();
  final patientId = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.showOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingScreen(prefs: widget.prefs),
          ),
        );
        if (mounted) await _resumePendingExistingPatientLink();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resumePendingExistingPatientLink();
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    birthDate.dispose();
    gender.dispose();
    address.dispose();
    patientId.dispose();
    super.dispose();
  }

  // ============================================================
  // DATE OF BIRTH
  // ============================================================

  Future<void> pickBirthDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT DATE OF BIRTH',
    );

    if (picked != null) {
      birthDate.text = DateFormat('MMMM d, yyyy').format(picked);
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? validateEmail(String? value) {
    final v = (value ?? '').trim().toLowerCase();

    final pattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]{2,}$');

    if (v.isEmpty) {
      return 'Please enter your email address.';
    }

    if (!pattern.hasMatch(v)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    if (!RegExp(r'^9\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit mobile number.';
    }

    return null;
  }

  String? validatePatientId(String? value) {
    final id = (value ?? '').trim().toUpperCase();

    if (id.isEmpty) {
      return 'Please enter your clinic Patient ID.';
    }

    if (!RegExp(r'^PT-[A-Z0-9][A-Z0-9-]{0,23}$').hasMatch(id)) {
      return 'Enter a valid Patient ID, such as PT-001.';
    }

    return null;
  }

  void _message(String value) {
    if (!mounted || value.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded, color: AppColors.teal, size: 34),
        content: Text(value),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePendingExistingPatientLink({
    required String emailValue,
    required String patientIdValue,
    required String patientName,
    required String phoneValue,
  }) async {
    await widget.prefs.setString(_pendingLinkEmailKey, emailValue);
    await widget.prefs.setString(_pendingLinkPatientIdKey, patientIdValue);
    await widget.prefs.setString(_pendingLinkNameKey, patientName);
    await widget.prefs.setString(_pendingLinkPhoneKey, phoneValue);
  }

  Future<void> _clearPendingExistingPatientLink() async {
    await widget.prefs.remove(_pendingLinkEmailKey);
    await widget.prefs.remove(_pendingLinkPatientIdKey);
    await widget.prefs.remove(_pendingLinkNameKey);
    await widget.prefs.remove(_pendingLinkPhoneKey);
  }

  Future<void> _resumePendingExistingPatientLink() async {
    if (_resumeExistingLinkChecked || !mounted) return;
    _resumeExistingLinkChecked = true;

    final savedEmail = (widget.prefs.getString(_pendingLinkEmailKey) ?? '')
        .trim()
        .toLowerCase();
    if (savedEmail.isEmpty) return;

    final savedPatientId = widget.prefs.getString(_pendingLinkPatientIdKey) ?? '';
    final savedName = widget.prefs.getString(_pendingLinkNameKey) ?? '';
    final savedPhone = widget.prefs.getString(_pendingLinkPhoneKey) ?? '';
    final currentUser = FirebaseAuth.instance.currentUser;

    // If Android closed the app while the verification screen was open,
    // restore the saved form. The patient can re-enter their password and
    // the service safely resumes the same Auth identity rather than creating
    // a second Auth account.
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        register = true;
        registrationType = 'existing';
        email.text = savedEmail;
        patientId.text = savedPatientId;
        name.text = savedName;
        phone.text = savedPhone;
      });
      _message('Continue your existing-patient registration. Re-enter your password to resume email verification.');
      return;
    }

    if ((currentUser.email ?? '').trim().toLowerCase() != savedEmail) {
      _message('A different Firebase account is signed in. Sign out before resuming the saved patient-link request.');
      return;
    }

    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExistingPatientLinkVerificationScreen(
          email: savedEmail,
          patientId: savedPatientId,
          name: savedName,
          phone: savedPhone.startsWith('+63 ')
              ? savedPhone
              : '+63 $savedPhone',
        ),
      ),
    );

    if (!mounted) return;
    if (submitted == true) {
      await _clearPendingExistingPatientLink();
      if (!mounted) return;
      setState(() {
        register = false;
        registrationType = 'existing';
        patientId.clear();
        password.clear();
      });
      // The verification screen already displayed the dismissible request-received dialog.
    }
  }

  String _authError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'The email or password is incorrect.';

        case 'email-already-in-use':
          return 'This email address already has an account. Try logging in.';

        case 'weak-password':
          return 'Please use a stronger password.';

        case 'invalid-email':
          return 'Please enter a valid email address.';

        case 'user-disabled':
          return 'This account has been disabled. Please contact the clinic.';

        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';

        case 'network-request-failed':
          return 'Network error. Check your internet connection.';

        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    if (!(form.currentState?.validate() ?? false)) return;

    setState(() => busy = true);

    try {
      final patientName = await _auth.signInPatient(
        email: email.text.trim(),
        password: password.text,
      );

      await widget.prefs.setString('patient_name', patientName);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PatientShell(
            prefs: widget.prefs,
            name: patientName,
          ),
        ),
      );
    } catch (error) {
      _message(_authError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ============================================================
  // REGISTRATION
  // ============================================================

  Future<void> _register() async {
    if (!(form.currentState?.validate() ?? false)) return;

    setState(() => busy = true);
    try {
      final normalizedEmail = email.text.trim().toLowerCase();
      final normalizedPhone = '+63 ${phone.text.trim()}';
      final patientName = name.text.trim();
      final normalizedPatientId = patientId.text.trim().toUpperCase();

      await _savePendingExistingPatientLink(
        emailValue: normalizedEmail,
        patientIdValue: normalizedPatientId,
        patientName: patientName,
        phoneValue: phone.text.trim(),
      );

      await _auth.beginExistingPatientLinkVerification(
        email: normalizedEmail,
        password: password.text,
        name: patientName,
      );

      if (!mounted) return;
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ExistingPatientLinkVerificationScreen(
            email: normalizedEmail,
            patientId: normalizedPatientId,
            name: patientName,
            phone: normalizedPhone,
          ),
        ),
      );

      if (!mounted) return;
      if (submitted == true) {
        await _clearPendingExistingPatientLink();
        if (!mounted) return;
        setState(() {
          register = false;
          registrationType = 'existing';
          patientId.clear();
          password.clear();
        });
        // The verification screen already displayed the dismissible request-received dialog.
      }
    } catch (error, stackTrace) {
      debugPrint('Patient account-link registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _message(_authError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(
      text: email.text.trim(),
    );

    final selectedEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'you@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                dialogContext,
                controller.text.trim(),
              );
            },
            child: const Text('Send reset email'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (selectedEmail == null || selectedEmail.isEmpty) return;

    final validation = validateEmail(selectedEmail);

    if (validation != null) {
      _message(validation);
      return;
    }

    setState(() => busy = true);

    try {
      await _auth.sendPasswordReset(selectedEmail);

      _message(
        'If an account exists for that email, a password reset link has been sent.',
      );
    } catch (error) {
      _message(_authError(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ============================================================
  // REUSABLE TEXT FIELD
  // ============================================================

  Widget field(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  // ============================================================
  // REGISTRATION TYPE SELECTOR
  // ============================================================

  Widget _registrationTypeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.badge_outlined, color: AppColors.deepTeal),
            SizedBox(width: 9),
            Text('Register with your clinic Patient ID',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          SizedBox(height: 8),
          Text(
            'Your Patient ID is issued by Alapot Dental Clinic after staff verify your identity document. You may complete verification in person or through an official clinic call. If you do not have an ID yet, contact the clinic first; do not create a second patient record.',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(26),
              shrinkWrap: true,
              children: [
                if (!register) ...[
                  Center(
                    child: Image.asset(
                      'assets/images/alapot_logo.png',
                      width: 76,
                      height: 76,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Alapot Dental Clinic',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Your smile deserves gentle care.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ] else ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Let’s get you started.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                const SizedBox(height: 12),
                Form(
                  key: form,
                  child: Column(
                    children: [
                      if (register) ...[
                        _registrationTypeSelector(),
                        const SizedBox(height: 18),

                        field(
                          'Full name',
                          name,
                          Icons.person_outline,
                        ),

                        const SizedBox(height: 12),

                        // Existing patient: enter clinic Patient ID.
                        if (isExistingPatient) ...[
                          TextFormField(
                            controller: patientId,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9-]'),
                              ),
                              LengthLimitingTextInputFormatter(27),
                            ],
                            validator: validatePatientId,
                            decoration: const InputDecoration(
                              labelText: 'Clinic Patient ID',
                              hintText: 'PT-XXXXXXXX',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                      ],

                      // Email
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.email,
                        ],
                        validator: validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),

                      // Phone number
                      if (register) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            _PhilippinePhoneFormatter(),
                          ],
                          validator: validatePhone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixText: '+63 ',
                            hintText: '900 000 0000',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Password
                      TextFormField(
                        controller: password,
                        obscureText: obscure,
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters.'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => obscure = !obscure);
                            },
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!register)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : (register ? _register : _login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            !register
                                ? 'Log in'
                                : isExistingPatient
                                    ? 'Verify email & request account access'
                                    : 'Create account',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              register = !register;
                              registrationType = 'existing';

                              form.currentState?.reset();

                              name.clear();
                              email.clear();
                              phone.clear();
                              password.clear();
                              birthDate.clear();
                              gender.clear();
                              address.clear();
                              patientId.clear();
                            });
                          },
                    child: Text(
                      register
                          ? 'Already have an account? Log in'
                          : 'New to Alapot? Create an account',
                    ),
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

// ============================================================
// PHILIPPINE PHONE FORMATTER
// ============================================================

class _PhilippinePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('63')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    final output = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index == 3 || index == 6) {
        output.write(' ');
      }

      output.write(digits[index]);
    }

    final formatted = output.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}
