import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import 'patient_shell.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.preferences});
  final SharedPreferences preferences;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 450));
    final savedLogin = widget.preferences.getString('demo_login');
    final savedPassword = widget.preferences.getString('demo_password');
    final isDemoAccount = savedLogin == null ||
        (savedLogin == _email.text.trim() && savedPassword == _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!isDemoAccount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Email or password does not match this local demo account.')));
      return;
    }
    final name = widget.preferences.getString('demo_name') ?? 'Smile Guest';
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            PatientShell(preferences: widget.preferences, patientName: name)));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AuthBrand(),
        const SizedBox(height: 32),
        const Text('Welcome back',
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 7),
        const Text('Log in to continue your dental care journey.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 27),
        Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email or phone number',
                      hintText: 'you@example.com or 09XX XXX XXXX',
                      prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => v == null ||
                          (v.contains('@')
                              ? !v.contains('.')
                              : v.replaceAll(RegExp(r'\D'), '').length < 10)
                      ? 'Enter a valid email or phone number.'
                      : null),
              const SizedBox(height: 15),
              TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password.' : null),
            ])),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const AlertDialog(
                        title: Text('Password help'),
                        content: Text(
                            'Password recovery will be connected to the secure account service in a later integration phase. For this prototype, create a local account or use its saved credentials.'))),
                child: const Text('Forgot password?'))),
        const SizedBox(height: 8),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _busy ? null : _login,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Log In'))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('New to Alapot? ',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      RegisterScreen(preferences: widget.preferences))),
              child: const Text('Create account'))
        ]),
        const SizedBox(height: 16),
        const DemoNote(),
      ]));
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.preferences});
  final SharedPreferences preferences;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _dob = TextEditingController(),
      _address = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController();
  String? _gender;
  bool _showPassword = false;
  bool _busy = false;

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        initialDate: DateTime(2000),
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: AppColors.teal)),
            child: child!));
    if (picked != null) {
      _dob.text =
          '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your gender.')));
      return;
    }
    setState(() => _busy = true);
    await widget.preferences.setString('demo_name', _name.text.trim());
    await widget.preferences.setString('demo_email', _email.text.trim());
    await widget.preferences.setString(
        'demo_login',
        _email.text.trim().isNotEmpty
            ? _email.text.trim()
            : _phone.text.trim());
    await widget.preferences.setString('demo_password', _password.text);
    await widget.preferences.setString('demo_phone', _phone.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => PatientShell(
                preferences: widget.preferences,
                patientName: _name.text.trim())),
        (route) => false);
  }

  @override
  void dispose() {
    for (final c in [_name, _dob, _address, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AuthBrand(),
        const SizedBox(height: 25),
        const Text('Create your account',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 6),
        const Text('A few details to get your patient profile started.',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 22),
        Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => v == null || v.trim().length < 2
                      ? 'Enter your full name.'
                      : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _dob,
                        readOnly: true,
                        onTap: _pickDob,
                        decoration: const InputDecoration(
                            labelText: 'Date of birth',
                            prefixIcon: Icon(Icons.calendar_today_outlined)),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Select your birth date.'
                            : null)),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: const [
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Prefer not to say',
                              child: Text('Prefer not to say'))
                        ],
                        onChanged: (v) => setState(() => _gender = v)))
              ]),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your address.'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '09XX XXX XXXX',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) =>
                      v == null || v.replaceAll(RegExp(r'\D'), '').length < 10
                          ? 'Enter a valid phone number.'
                          : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email address (optional)',
                      prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) =>
                      v != null && v.isNotEmpty && !v.contains('@')
                          ? 'Enter a valid email address.'
                          : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _password,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined))),
                  validator: (v) => v == null || v.length < 8
                      ? 'Use at least 8 characters.'
                      : null),
            ])),
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Account'))),
        const SizedBox(height: 12),
        Center(
            child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Log in'))),
        const SizedBox(height: 8),
        const DemoNote(),
      ]));
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 760;
        return Center(
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 980 : 520),
                child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 40 : 25, vertical: 24),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                Expanded(child: _AuthWelcome()),
                                const SizedBox(width: 55),
                                Expanded(child: child)
                              ])
                        : child)));
      })));
}

class _AuthWelcome extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: AppColors.mint, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset('assets/images/alapot_logo.png', width: 90, height: 90),
        const SizedBox(height: 25),
        const Text('A brighter smile starts with care.',
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 12),
        const Text(
            'Manage your appointments and stay connected with Alapot Dental Clinic.',
            style: TextStyle(color: AppColors.muted, height: 1.7))
      ]));
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Image.asset('assets/images/alapot_logo.png', width: 46, height: 46),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alapot Dental Clinic',
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
          Text('Dental Care Beyond Ordinary!',
              style: TextStyle(fontSize: 10, color: AppColors.muted))
        ])
      ]);
}

class DemoNote extends StatelessWidget {
  const DemoNote({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF8E9),
          borderRadius: BorderRadius.circular(12)),
      child: const Text(
          'Prototype mode: account details are stored locally on this device only. This is not secure production authentication and is not connected to Firebase.',
          style:
              TextStyle(fontSize: 11, color: Color(0xFF856B39), height: 1.5)));
}
