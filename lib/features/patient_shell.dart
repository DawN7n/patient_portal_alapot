import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientShell extends StatelessWidget {
  const PatientShell({
    super.key,
    required this.preferences,
    required this.patientName,
  });

  final SharedPreferences preferences;
  final String patientName;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
