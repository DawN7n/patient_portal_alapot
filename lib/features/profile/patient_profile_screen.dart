
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../shared/widgets/ui.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({
    super.key,
    required this.name,
  });

  final String name;

  @override
  State<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool editing = false;

  late final TextEditingController fullName;
  final dob = TextEditingController(text: 'Not provided');
  final patientId = TextEditingController(text: 'Assigned by clinic');
  final registeredDate = TextEditingController(text: 'Not available');
  final lastVisit = TextEditingController(text: 'No completed visit recorded');
  final gender = TextEditingController();
  final address = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final emergencyName = TextEditingController();
  final emergencyPhone = TextEditingController();
  final relationship = TextEditingController();
  final allergies = TextEditingController();
  final bloodType = TextEditingController(text: 'Not provided');
  final medicalNotes = TextEditingController(text: 'Maintained by your dentist.');

  @override
  void initState() {
    super.initState();
    fullName = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    for (final c in [
      fullName,
      dob,
      patientId,
      registeredDate,
      lastVisit,
      gender,
      address,
      email,
      phone,
      emergencyName,
      emergencyPhone,
      relationship,
      allergies,
      bloodType,
      medicalNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void edit() => setState(() => editing = true);

  InputDecoration _inputDecoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffix,
      filled: true,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.line,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.teal,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: _inputDecoration(label),
      ),
    );
  }

  Widget _dateField() {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: dob,
        readOnly: true,
        decoration: _inputDecoration(
          'Date of birth',
          suffix: const Icon(Icons.calendar_month_outlined),
        ),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            initialDatePickerMode: DatePickerMode.year,
          );

          if (d != null) {
            setState(() {
              dob.text = '${d.month}/${d.day}/${d.year}';
            });
          }
        },
      ),
    );
  }

  Widget _genderField() {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<String>(
        initialValue: gender.text.isEmpty ? null : gender.text,
        isExpanded: true,
        decoration: _inputDecoration('Gender'),
        items: const [
          DropdownMenuItem(
            value: 'Male',
            child: Text('Male'),
          ),
          DropdownMenuItem(
            value: 'Female',
            child: Text('Female'),
          ),
        ],
        onChanged: (v) {
          setState(() {
            gender.text = v ?? '';
          });
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(
        color: AppColors.line,
        height: 1,
      ),
    );
  }

  Widget _editForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Personal information'),

        _field('Full name', fullName),
        const SizedBox(height: 14),

        _dateField(),
        const SizedBox(height: 14),

        _genderField(),
        const SizedBox(height: 14),

        _field('Address', address),
        const SizedBox(height: 14),

        _field(
          'Email address',
          email,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        _field(
          'Phone number',
          phone,
          keyboard: TextInputType.phone,
        ),

        _sectionDivider(),

        _sectionTitle('Emergency contact'),

        _field('Full name', emergencyName),
        const SizedBox(height: 14),

        _field(
          'Contact number',
          emergencyPhone,
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        _field('Relationship', relationship),

        _sectionDivider(),

        _sectionTitle('Patient information'),

        TextField(controller: patientId, enabled: false, decoration: _inputDecoration('Patient ID')),
        const SizedBox(height: 14),
        TextField(controller: registeredDate, enabled: false, decoration: _inputDecoration('Registered date')),
        const SizedBox(height: 14),
        TextField(controller: lastVisit, enabled: false, decoration: _inputDecoration('Last clinic visit')),
        const SizedBox(height: 14),

        _field(
          'Allergies',
          allergies,
          maxLines: 3,
        ),
        const SizedBox(height: 14),

        _field('Blood type', bloodType),
        const SizedBox(height: 14),

        TextField(
          controller: medicalNotes,
          enabled: false,
          maxLines: 2,
          decoration: _inputDecoration('Medical notes'),
        ),

        const SizedBox(height: 24),

        _actionButtons(),
      ],
    );
  }

  Widget _actionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 400;

        final cancelButton = OutlinedButton(
          onPressed: () {
            setState(() => editing = false);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cancel',
            maxLines: 1,
          ),
        );

        final saveButton = SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Save changes',
            onPressed: () {
              setState(() => editing = false);
            },
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              saveButton,
              const SizedBox(height: 10),
              cancelButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cancelButton),
            const SizedBox(width: 12),
            Expanded(child: saveButton),
          ],
        );
      },
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? 'Not provided' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Personal information'),
        _line('Full name', fullName.text),
        _line('Date of birth', dob.text),
        _line('Gender', gender.text),
        _line('Address', address.text),
        _line('Email address', email.text),
        _line('Phone number', phone.text),

        _sectionDivider(),

        _sectionTitle('Emergency contact'),
        _line('Full name', emergencyName.text),
        _line('Contact number', emergencyPhone.text),
        _line('Relationship', relationship.text),

        _sectionDivider(),

        _sectionTitle('Patient information'),
        _line('Patient ID', patientId.text),
        _line('Registered date', registeredDate.text),
        _line('Last clinic visit', lastVisit.text),
        _line('Allergies', allergies.text),
        _line('Blood type', bloodType.text),
        _line('Medical notes', medicalNotes.text),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Edit patient information',
            onPressed: edit,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 380
            ? 14.0
            : constraints.maxWidth < 700
                ? 20.0
                : 28.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            22,
            horizontal,
            32,
          ),
          children: [
            PageHeading(
              editing ? 'Edit patient profile' : 'Patient profile',
              subtitle: editing
                  ? 'Update your personal and patient information.'
                  : 'Your personal and patient information.',
            ),

            const SizedBox(height: 18),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 680,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: editing ? _editForm() : _profileView(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
