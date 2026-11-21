
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_theme.dart';
import '../../shared/widgets/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.openProfile,
    required this.openRecords,
    required this.openReviews,
    required this.openPayments,
    required this.openSupportTickets,
  });

  final VoidCallback openProfile;
  final VoidCallback openRecords;
  final VoidCallback openReviews;
  final VoidCallback openPayments;
  final VoidCallback openSupportTickets;

  Widget _accountLink(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: AppColors.sky,
        child: Icon(
          icon,
          color: AppColors.deepTeal,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.muted,
          height: 1.4,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.muted,
      ),
      onTap: onTap,
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final settingsContext = context;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final key = GlobalKey<FormState>();
    var saving = false;
    var obscureCurrent = true;
    var obscureNext = true;
    String? serverError;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Change password'),
            content: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: current,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(labelText: 'Current password', suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    )),
                    validator: (value) => (value ?? '').isEmpty ? 'Enter your current password.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: next,
                    obscureText: obscureNext,
                    decoration: InputDecoration(labelText: 'New password', helperText: 'Use at least 8 characters.', suffixIcon: IconButton(
                      onPressed: () => setDialogState(() => obscureNext = !obscureNext),
                      icon: Icon(obscureNext ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    )),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.length < 8) return 'Use at least 8 characters.';
                      if (password == current.text) return 'Choose a password different from the current one.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    validator: (value) => value != next.text ? 'The passwords do not match.' : null,
                  ),
                  if (serverError != null) ...[
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: Text(serverError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              FilledButton(
                onPressed: saving ? null : () async {
                  if (!(key.currentState?.validate() ?? false)) return;
                  setDialogState(() { saving = true; serverError = null; });
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    final email = user?.email;
                    if (user == null || email == null || email.isEmpty) {
                      throw StateError('Your signed-in email could not be found. Sign out and sign in again.');
                    }
                    final credential = EmailAuthProvider.credential(email: email, password: current.text);
                    await user.reauthenticateWithCredential(credential);
                    await user.updatePassword(next.text);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (settingsContext.mounted) {
                      await showDialog<void>(context: settingsContext, builder: (ctx) => AlertDialog(
                        icon: const Icon(Icons.verified_user_outlined, color: AppColors.teal),
                        title: const Text('Password updated'),
                        content: const Text('Your password has been changed successfully. Use the new password the next time you sign in.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                      ));
                    }
                  } on FirebaseAuthException catch (error) {
                    final message = switch (error.code) {
                      'wrong-password' || 'invalid-credential' => 'Your current password is incorrect. Please check it and try again.',
                      'weak-password' => 'Choose a stronger password with at least 8 characters.',
                      'requires-recent-login' => 'Your session is too old. Sign out and sign in again, then retry.',
                      'network-request-failed' => 'Network connection failed. Check your internet and retry.',
                      _ => error.message ?? 'The password could not be changed.',
                    };
                    setDialogState(() { serverError = message; saving = false; });
                  } catch (error) {
                    setDialogState(() { serverError = error.toString().replaceFirst('Bad state: ', ''); saving = false; });
                  }
                },
                child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update password'),
              ),
            ],
          ),
        ),
      );
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  void _privacyInformation(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy and information use'),
        content: const SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your account and clinic information', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('The portal uses your account details, contact information, appointment activity, and clinic records to provide patient services. Firebase Authentication and Firestore are used by the application to sign in and store portal data.'),
            SizedBox(height: 12),
            Text('Who can view it', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('Clinic administrators and authorized dental staff may access information needed for clinic operations and your care, according to their portal permissions.'),
            SizedBox(height: 12),
            Text('Alapot AI', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('Questions you send to Alapot AI are processed through the clinic AI server and the configured AI provider. Do not share passwords, full government identification numbers, or payment-card details. Save a conversation to My Tickets only when you want it retained in your clinic ticket history.'),
            SizedBox(height: 12),
            Text('Your choices', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 5),
            Text('If you believe your profile or clinic record is inaccurate, contact the clinic and request a correction. Ask the clinic for its full privacy notice and data-retention policy for formal privacy requests.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  // --------------------------------------------------
  // BUILD SETTINGS SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const PageHeading(
          'Settings',
          subtitle: 'Manage your account, saved AI tickets, and security.',
        ),

        // ACCOUNT
        const SectionTitle('Account'),

        SurfaceCard(
          child: Column(
            children: [
              _accountLink(
                Icons.person_outline_rounded,
                'Patient profile',
                'View your personal and patient information',
                openProfile,
              ),
              const Divider(height: 20),
              _accountLink(
                Icons.folder_open_outlined,
                'My records',
                'Dental chart, visit history, consultation notes and files',
                openRecords,
              ),
              const Divider(height: 20),
              _accountLink(
                Icons.star_outline_rounded,
                'My reviews',
                'Reviews you have submitted',
                openReviews,
              ),
              const Divider(height: 20),
              _accountLink(
                Icons.account_balance_wallet_outlined,
                'Manage payments',
                'View payment history and official clinic receipts',
                openPayments,
              ),
            ],
          ),
        ),

        // SUPPORT
        const SectionTitle('Support'),

        SurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.sky,
              child: Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.deepTeal,
              ),
            ),
            title: const Text(
              'My Tickets',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Open full Alapot AI conversations saved to your ticket history',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.muted,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.muted,
            ),
            onTap: openSupportTickets,
          ),
        ),

        // SECURITY
        const SectionTitle('Security'),

        SurfaceCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline, color: AppColors.teal, size: 23),
                title: const Text('Change password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: const Text('Verify your current password and set a new one', style: TextStyle(fontSize: 10, color: AppColors.muted, height: 1.4)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                onTap: () => _changePassword(context),
              ),
              const Divider(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.teal, size: 23),
                title: const Text('Privacy settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: const Text('Review how your account, clinic, and AI information is used', style: TextStyle(fontSize: 10, color: AppColors.muted, height: 1.4)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                onTap: () => _privacyInformation(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),
      ],
    );
  }
}
