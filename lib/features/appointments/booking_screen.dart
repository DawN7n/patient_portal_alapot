import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../models/portal_models.dart';
import '../../shared/widgets/ui.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.onDone,
    required this.onHome,
    this.initialService,
    this.initialDentist,
  });

  final VoidCallback onDone;
  final VoidCallback onHome;
  final DentalService? initialService;
  final Dentist? initialDentist;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final PatientPortalRepository _repository = PatientPortalRepository();

  late final Stream<List<Map<String, dynamic>>> _servicesStream =
      _repository.watchServices();

  late final Stream<List<Map<String, dynamic>>> _dentistsStream =
      _repository.watchDentists();

  late final Stream<List<Map<String, dynamic>>> _paymentMethodsStream =
      _repository.watchPaymentMethods();

  int step = 0;

  final List<DentalService> selectedServices = [];

  Dentist? dentist;
  DateTime? date;
  String? time;

  String? paymentMethodId;

  bool submitting = false;
  String? submittedId;

  List<Map<String, dynamic>> _latestServiceDocs = [];
  List<Map<String, dynamic>> _latestDentistDocs = [];
  List<Map<String, dynamic>> _latestPaymentMethodDocs = [];

  StreamSubscription<List<Map<String, dynamic>>>? _paymentMethodsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _clinicProfileSubscription;
  Map<String, dynamic>? _latestClinicProfile;
  bool _clinicProfileLoaded = false;
  String? _clinicProfileError;

  @override
  void initState() {
    super.initState();

    if (widget.initialService != null) {
      selectedServices.add(widget.initialService!);
    }

    dentist = widget.initialDentist;

    _paymentMethodsSubscription = _paymentMethodsStream.listen((methods) {
      if (!mounted) return;
      _latestPaymentMethodDocs = methods;
      final selectedStillActive = methods.any((method) =>
          method['status'] == 'Active' &&
          method['_docId']?.toString() == paymentMethodId);
      if (!selectedStillActive && paymentMethodId != null) {
        setState(() => paymentMethodId = null);
      }
    }, onError: (Object error) {
      if (!mounted) return;
      _message('Payment methods could not be loaded. Please retry or contact the clinic.');
    });

    _clinicProfileSubscription = _repository.watchClinicProfile().listen(
      (profile) {
        if (!mounted) return;
        setState(() {
          _latestClinicProfile = profile;
          _clinicProfileLoaded = true;
          _clinicProfileError = null;
          if (date != null && !_isClinicOpenOn(date!)) {
            date = null;
            time = null;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _clinicProfileLoaded = true;
          _clinicProfileError = 'Clinic operating hours could not be loaded. Please try again later.';
        });
      },
    );
  }

  @override
  void dispose() {
    _paymentMethodsSubscription?.cancel();
    _clinicProfileSubscription?.cancel();
    super.dispose();
  }

  double get total => selectedServices.fold(
        0,
        (sum, service) => sum + service.price,
      );

  String get serviceNames =>
      selectedServices.map((service) => service.name).join(', ');

  String get dateLabel => date == null
      ? 'Choose a date'
      : '${_month(date!.month)} ${date!.day}, ${date!.year}';

  String _month(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][month - 1];

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  // --------------------------------------------------
  // FIRESTORE DOCUMENT HELPERS
  // --------------------------------------------------

  String _stringValue(
    List<Object?> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return fallback;
  }

  double _doubleValue(Object? value, {double fallback = 0}) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _intValue(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _isActiveRecord(Map<String, dynamic> data) {
    final activeValue = data['active'] ?? data['isActive'] ?? data['is_active'];

    if (activeValue == false) return false;

    final status = _stringValue([
      data['status'],
    ]).toLowerCase();

    if (status.isEmpty) return true;

    return const {
      'active',
      'available',
      'published',
      'enabled',
    }.contains(status);
  }

  Color _colorFromData(
    Map<String, dynamic> data, {
    Color fallback = AppColors.mint,
  }) {
    final raw = data['tintHex'] ??
        data['tint_hex'] ??
        data['colorHex'] ??
        data['color_hex'];

    if (raw is int) {
      return Color(raw);
    }

    if (raw is! String) return fallback;

    var hex = raw.trim().replaceAll('#', '');

    if (hex.isEmpty) return fallback;

    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    if (hex.length != 8) return fallback;

    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  DentalService _serviceFromDocument(
    Map<String, dynamic> data,
  ) {
    final serviceId = _stringValue([
      data['id'],
      data['_docId'],
    ]);

    final duration = _intValue(
      data['duration'] ?? data['durationMinutes'] ?? data['duration_minutes'],
      fallback: 0,
    );

    final iconKey = _stringValue([
      data['iconKey'],
      data['icon'],
      data['category'],
    ]).toLowerCase();

    IconData icon = Icons.medical_services_outlined;

    if (iconKey.contains('clean')) {
      icon = Icons.cleaning_services_outlined;
    } else if (iconKey.contains('tooth') || iconKey.contains('extract')) {
      icon = Icons.medical_services_outlined;
    } else if (iconKey.contains('braces') || iconKey.contains('ortho')) {
      icon = Icons.tag_faces_outlined;
    } else if (iconKey.contains('consult')) {
      icon = Icons.assignment_outlined;
    }

    return DentalService(
      id: serviceId,
      name: _stringValue([
        data['name'],
        data['service_name'],
      ], fallback: 'Service name not recorded'),
      description: _stringValue([
        data['description'],
      ]),
      price: _doubleValue(
        data['price'] ?? data['amount'],
      ),
      duration: duration,
      icon: icon,
      tint: _colorFromData(data),
    );
  }

  Dentist _dentistFromDocument(
    Map<String, dynamic> data,
  ) {
    final dentistId = _stringValue([
      data['id'],
      data['_docId'],
    ]);

    final experienceValue = data['experience'] ??
        data['experienceYears'] ??
        data['experience_years'];

    String experience;

    if (experienceValue is num) {
      experience = '${experienceValue.toInt()} years experience';
    } else {
      experience = experienceValue?.toString().trim() ?? '';
    }

    if (experience.isEmpty) {
      experience = 'Experience not specified';
    }

    return Dentist(
      id: dentistId,
      name: _stringValue([
        data['name'],
        data['fullName'],
      ], fallback: 'Dentist'),
      specialty: _stringValue([
        data['specialization'],
        data['specialty'],
        data['specialty_name'],
      ], fallback: 'Specialty not specified'),
      experience: experience,
      rating: _doubleValue(data['rating']),
      reviews: _intValue(
        data['reviews'] ?? data['reviewCount'] ?? data['review_count'],
      ),
      bio: _stringValue([
        data['description'],
        data['bio'],
      ]),
      color: _colorFromData(data),
    );
  }

  bool _documentMatchesId(
    Map<String, dynamic> data,
    String id,
  ) {
    return data['_docId']?.toString() == id || data['id']?.toString() == id;
  }

  Map<String, dynamic>? _findServiceDocument(
    DentalService service,
  ) {
    for (final document in _latestServiceDocs) {
      if (_documentMatchesId(document, service.id)) {
        return document;
      }
    }

    return null;
  }

  Map<String, dynamic>? _findDentistDocument(
    Dentist selectedDentist,
  ) {
    for (final document in _latestDentistDocs) {
      if (_documentMatchesId(document, selectedDentist.id)) {
        return document;
      }
    }

    return null;
  }

  // --------------------------------------------------
  // BOOKING NAVIGATION
  // --------------------------------------------------

  void next() {
    if (step == 0 && selectedServices.isEmpty) {
      _message('Please select at least one dental service.');
      return;
    }

    if (step == 1 && dentist == null) {
      _message('Please select your preferred dentist.');
      return;
    }

    if (step == 2 && (date == null || time == null)) {
      _message('Choose your preferred date and time.');
      return;
    }
    if (step == 2 && !_preferredTimesFromDentistSchedule().contains(time)) {
      _message('Choose a time within the selected dentist’s published working hours.');
      return;
    }

    if (step == 2) {
      final selectedDateTime = _selectedDateTime();

      if (selectedDateTime == null ||
          !selectedDateTime.isAfter(DateTime.now())) {
        _message('Please choose a future appointment time.');
        return;
      }
    }

    if (step < 3) {
      setState(() => step++);
    }
  }

  void back() {
    if (submitting) return;

    if (step == 0) {
      widget.onHome();
    } else {
      setState(() => step--);
    }
  }

  Future<void> chooseDate() async {
    if (!_clinicProfileLoaded) {
      _message('Loading the clinic schedule. Please try again in a moment.');
      return;
    }
    if (_clinicProfileError != null) {
      _message(_clinicProfileError!);
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final lastDate = today.add(const Duration(days: 180));
    DateTime? firstOpenDay;
    for (var candidate = today; !candidate.isAfter(lastDate); candidate = candidate.add(const Duration(days: 1))) {
      if (_isClinicOpenOn(candidate)) {
        firstOpenDay = candidate;
        break;
      }
    }
    if (firstOpenDay == null) {
      _message('The clinic has no published operating days in the next 180 days. Please contact the clinic.');
      return;
    }
    final currentDateIsSelectable = date != null && _isClinicOpenOn(date!);
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDateIsSelectable ? date! : firstOpenDay,
      firstDate: today,
      lastDate: lastDate,
      selectableDayPredicate: _isClinicOpenOn,
      helpText: 'Choose a clinic operating day',
    );
    if (picked != null && mounted) {
      setState(() {
        if (date == null || !DateUtils.isSameDay(date, picked)) time = null;
        date = picked;
      });
    }
  }

  String _to24Hour(String displayTime) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(displayTime.trim());

    if (match == null) {
      throw const FormatException('Invalid appointment time.');
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();

    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  DateTime? _selectedDateTime() {
    if (date == null || time == null) return null;

    try {
      final time24 = _to24Hour(time!);
      final parts = time24.split(':');

      return DateTime(
        date!.year,
        date!.month,
        date!.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }


  int? _minutesFromClock(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final twentyFourHour = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (twentyFourHour != null) {
      final hour = int.tryParse(twentyFourHour.group(1)!);
      final minute = int.tryParse(twentyFourHour.group(2)!);
      if (hour == null || minute == null || hour > 23 || minute > 59) return null;
      return hour * 60 + minute;
    }
    try {
      final parsed = _to24Hour(value);
      final normalized = parsed.split(':');
      return int.parse(normalized[0]) * 60 + int.parse(normalized[1]);
    } catch (_) {
      return null;
    }
  }

  Map<String, int>? _clinicMinutesFor(DateTime day) {
    final rawHours = _latestClinicProfile?['hours'];
    if (rawHours is! Map) return null;
    const weekdayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final dayName = weekdayNames[day.weekday - 1];
    final rawDay = rawHours[dayName];
    if (rawDay is! Map || rawDay['closed'] == true) return null;
    final open = _minutesFromClock(rawDay['open']);
    final close = _minutesFromClock(rawDay['close']);
    if (open == null || close == null || close <= open) return null;
    return {'open': open, 'close': close};
  }

  bool _isClinicOpenOn(DateTime day) {
    if (_clinicMinutesFor(day) == null) return false;
    final selectedDentist = dentist;
    if (selectedDentist == null) return true;
    final document = _findDentistDocument(selectedDentist);
    if (document == null) return false;
    final rawDays = document['working_days'] ?? document['workingDays'] ?? document['days'];
    if (rawDays is! List || rawDays.isEmpty) return true;
    final days = rawDays.map((value) => value.toString().toLowerCase()).toSet();
    const weekdayNames = ['', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final selectedDay = weekdayNames[day.weekday];
    return days.contains(selectedDay) || days.contains(selectedDay.substring(0, 3));
  }

  String _displayClock(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  List<String> _preferredTimesFromDentistSchedule() {
    if (date == null || dentist == null || !_clinicProfileLoaded) return const [];
    final clinicHours = _clinicMinutesFor(date!);
    if (clinicHours == null) return const [];

    var start = clinicHours['open']!;
    var end = clinicHours['close']!;
    final document = _findDentistDocument(dentist!);
    if (document == null) return const [];

    // The Admin Clinic Profile is the master operating schedule. If a dentist
    // has a more restrictive personal schedule, intersect it with clinic hours.
    final rawDays = document['working_days'] ?? document['workingDays'] ?? document['days'];
    final hasDentistDays = rawDays is List && rawDays.isNotEmpty;
    if (hasDentistDays) {
      final days = rawDays.map((d) => d.toString().toLowerCase()).toSet();
      const weekdayNames = ['', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final selectedDay = weekdayNames[date!.weekday];
      final selectedShortDay = selectedDay.substring(0, 3);
      if (!days.contains(selectedDay) && !days.contains(selectedShortDay)) return const [];
    }

    final dentistStart = _minutesFromClock(document['start_time'] ?? document['startTime']);
    final dentistEnd = _minutesFromClock(document['end_time'] ?? document['endTime']);
    if (dentistStart != null) start = start > dentistStart ? start : dentistStart;
    if (dentistEnd != null) end = end < dentistEnd ? end : dentistEnd;
    if (end <= start) return const [];

    final breakStart = _minutesFromClock(document['break_start'] ?? document['breakStart']);
    final breakEnd = _minutesFromClock(document['break_end'] ?? document['breakEnd']);
    final duration = selectedServices.fold<int>(0, (sum, service) => sum + service.duration);
    if (duration <= 0) return const [];

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    final slots = <String>[];
    for (var slot = start; slot + duration <= end; slot += 30) {
      final overlapsBreak = breakStart != null && breakEnd != null &&
          slot < breakEnd && slot + duration > breakStart;
      final alreadyPassed = isToday && slot <= now.hour * 60 + now.minute;
      if (!overlapsBreak && !alreadyPassed) slots.add(_displayClock(slot));
    }
    return slots;
  }

  // --------------------------------------------------
  // FIRESTORE APPOINTMENT SUBMISSION
  // --------------------------------------------------

  Future<void> submit() async {
    if (submitting) return;

    if (selectedServices.isEmpty) {
      _message('Please select at least one dental service.');
      return;
    }

    if (dentist == null) {
      _message('Please select your preferred dentist.');
      return;
    }

    final scheduledAt = _selectedDateTime();

    if (!_preferredTimesFromDentistSchedule().contains(time)) {
      _message('The selected time is not part of the dentist’s published schedule. Please choose another time.');
      return;
    }

    if (scheduledAt == null || !scheduledAt.isAfter(DateTime.now())) {
      _message('Please choose a valid future appointment schedule.');
      return;
    }

    final selectedPaymentMethod = _latestPaymentMethodDocs.firstWhere(
      (method) =>
          method['_docId']?.toString() == paymentMethodId &&
          method['status'] == 'Active',
      orElse: () => <String, dynamic>{},
    );

    final selectedPaymentMethodName =
        _stringValue([selectedPaymentMethod['name']]);

    if (paymentMethodId == null || selectedPaymentMethodName.isEmpty) {
      _message('Please choose an active payment method.');
      return;
    }

    final dentistDocument = _findDentistDocument(dentist!);

    if (dentistDocument == null) {
      _message(
        'The selected dentist could not be matched to a clinic record. '
        'Please select a dentist from the list.',
      );
      return;
    }

    final serviceDocuments = <Map<String, dynamic>>[];

    for (final service in selectedServices) {
      final document = _findServiceDocument(service);

      if (document == null) {
        _message(
          'One of your selected services could not be found. '
          'Please select your services again.',
        );
        return;
      }

      serviceDocuments.add(document);
    }

    setState(() => submitting = true);

    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text('Submitting your appointment request...'),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Retrieve the signed-in patient's permanent clinic profile.
      final patientProfile = await _repository.getMyPatientProfile();

      if (patientProfile == null) {
        throw StateError(
          'Your patient profile could not be found. '
          'Please sign in again or contact the clinic.',
        );
      }

      // The repository resolves the patient identity and dentist account link,
      // then creates the appointment in Firestore.
      final appointmentId = await _repository.createAppointment(
        patient: patientProfile,
        dentist: dentistDocument,
        services: serviceDocuments,
        scheduledAt: scheduledAt,
        time24h: _to24Hour(time!),
        paymentMethod: selectedPaymentMethodName,
        paymentMethodId: paymentMethodId!,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      await progressDialog;

      if (!mounted) return;

      setState(() {
        submittedId = appointmentId;
        submitting = false;
        step = 4;
      });
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      await progressDialog;

      if (!mounted) return;

      setState(() => submitting = false);

      final errorText = error.toString();

      if (errorText.contains('permission-denied')) {
        _message(
          'Firebase blocked this appointment request. '
          'Please check the deployed Firestore rules before trying again.',
        );
      } else {
        _message(
          errorText
              .replaceFirst('Bad state:', '')
              .replaceFirst('Exception:', '')
              .trim(),
        );
      }
    }
  }

  // --------------------------------------------------
  // MAIN LAYOUT
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        if (step == 4) {
          return SizedBox.expand(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _successStep(),
                ),
              ),
            ),
          );
        }

        final horizontal = bounds.maxWidth < 380
            ? 14.0
            : bounds.maxWidth < 700
                ? 18.0
                : 28.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            20,
            horizontal,
            32,
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Book an appointment',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 5, bottom: 18),
              child: Text(
                'Choose your care and preferred schedule.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
            Center(
              child: _progress(
                bounds.maxWidth - horizontal * 2,
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (step == 0) _serviceStep(),
                    if (step == 1) _dentistStep(),
                    if (step == 2) _scheduleStep(),
                    if (step == 3) _paymentStep(),
                    const SizedBox(height: 22),
                    _navigationButtons(
                      bounds.maxWidth - horizontal * 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // PROGRESS INDICATOR
  // --------------------------------------------------

  Widget _progress(double availableWidth) {
    final connectorWidth = ((availableWidth - 4 * 27) / 3 - 8).clamp(8.0, 38.0);

    return SizedBox(
      width: availableWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final active = index <= step;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.teal : AppColors.line,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (index < 3)
                Container(
                  width: connectorWidth,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: index < step ? AppColors.teal : AppColors.line,
                ),
            ],
          );
        }),
      ),
    );
  }

  // --------------------------------------------------
  // NAVIGATION BUTTONS
  // --------------------------------------------------

  Widget _navigationButtons(double availableWidth) {
    final narrow = availableWidth < 330;
    final hasActivePaymentSelection = paymentMethodId != null &&
        _latestPaymentMethodDocs.any((method) =>
            method['_docId']?.toString() == paymentMethodId &&
            method['status'] == 'Active');

    final backButton = SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: submitting ? null : back,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepTeal,
          side: const BorderSide(color: AppColors.teal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          step == 0 ? 'Cancel' : 'Back',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    final continueButton = SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: submitting || (step == 3 && !hasActivePaymentSelection)
            ? null
            : step == 3
                ? submit
                : next,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          step == 3 ? 'Submit request' : 'Continue',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          continueButton,
          const SizedBox(height: 10),
          backButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: backButton),
        const SizedBox(width: 12),
        Expanded(child: continueButton),
      ],
    );
  }

  // --------------------------------------------------
  // STEP 1: SERVICES FROM FIRESTORE
  // --------------------------------------------------

  Widget _serviceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Select services',
          subtitle: 'You can choose more than one service.',
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _servicesStream,
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
                child: Text(
                  'Unable to load clinic services: ${snapshot.error}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              );
            }

            final documents = snapshot.data ?? const [];
            _latestServiceDocs = documents;

            final activeDocuments =
                documents.where(_isActiveRecord).where((document) {
              return _stringValue([
                document['name'],
                document['service_name'],
              ]).isNotEmpty;
            }).toList();

            final availableServices =
                activeDocuments.map(_serviceFromDocument).toList();

            if (availableServices.isEmpty) {
              return const SurfaceCard(
                child: Text(
                  'There are currently no active dental services. '
                  'Please check again later.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              );
            }

            return Column(
              children: [
                ...availableServices.map((service) {
                  final chosen = selectedServices.any(
                    (item) => item.id == service.id,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SurfaceCard(
                      color: chosen ? AppColors.sky : Colors.white,
                      onTap: () {
                        setState(() {
                          if (chosen) {
                            selectedServices.removeWhere(
                              (item) => item.id == service.id,
                            );
                          } else {
                            selectedServices.add(service);
                          }
                        });
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 43,
                            height: 43,
                            decoration: BoxDecoration(
                              color: service.tint,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              service.icon,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  service.description,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${service.duration} minutes',
                                  style: const TextStyle(
                                    color: AppColors.teal,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${service.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Icon(
                                chosen
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color:
                                    chosen ? AppColors.teal : AppColors.muted,
                                size: 19,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
        if (selectedServices.isNotEmpty)
          SurfaceCard(
            color: AppColors.sky,
            child: Text(
              '${selectedServices.length} service(s) selected • '
              'Total: ₱${total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.deepTeal,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------
  // STEP 2: DENTISTS FROM FIRESTORE
  // --------------------------------------------------

  Widget _dentistStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Choose your dentist',
          subtitle: 'Select who you would prefer to see.',
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _dentistsStream,
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
                child: Text(
                  'Unable to load clinic dentists: ${snapshot.error}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              );
            }

            final documents = snapshot.data ?? const [];
            _latestDentistDocs = documents;
            if (dentist != null && date != null && time != null &&
                !_isClinicOpenOn(date!) ) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && date != null && !_isClinicOpenOn(date!)) {
                  setState(() { date = null; time = null; });
                }
              });
            }

            final activeDocuments =
                documents.where(_isActiveRecord).where((document) {
              return _stringValue([
                document['name'],
                document['fullName'],
              ]).isNotEmpty;
            }).toList();

            final availableDentists =
                activeDocuments.map(_dentistFromDocument).toList();

            if (availableDentists.isEmpty) {
              return const SurfaceCard(
                child: Text(
                  'There are currently no active dentists available. '
                  'Please contact the clinic.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              );
            }

            return Column(
              children: [
                ...availableDentists.map((item) {
                  final chosen = dentist?.id == item.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: SurfaceCard(
                      color: chosen ? AppColors.sky : Colors.white,
                      onTap: () {
                        setState(() {
                          dentist = item;
                          date = null;
                          time = null;
                        });
                      },
                      child: Row(
                        children: [
                          Avatar(
                            initials: item.name
                                .split(' ')
                                .where((part) => part.isNotEmpty)
                                .map((part) => part[0])
                                .take(2)
                                .join()
                                .toUpperCase(),
                            size: 48,
                            color: item.color,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  item.specialty,
                                  style: const TextStyle(
                                    color: AppColors.teal,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  item.experience,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            chosen
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: AppColors.teal,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  // --------------------------------------------------
  // STEP 3: DATE AND TIME
  // --------------------------------------------------

  Widget _scheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Date & time',
          subtitle: 'Choose your preferred appointment schedule.',
        ),
        const Text(
          'Select date',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        SurfaceCard(
          onTap: chooseDate,
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.teal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Preferred time',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final times = _preferredTimesFromDentistSchedule();
          if (times.isEmpty) {
            return SurfaceCard(
              child: Text(
                date == null
                    ? 'Choose a date to see the clinic operating hours.'
                    : !_clinicProfileLoaded
                        ? 'Loading the clinic operating schedule…'
                        : _clinicProfileError != null
                            ? _clinicProfileError!
                            : _clinicMinutesFor(date!) == null
                                ? 'The clinic is closed or its hours are not configured for this day. Choose another date.'
                                : 'No available time fits the selected services and dentist schedule. Choose another clinic day.',
                style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
              ),
            );
          }
          return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: times.map((slot) {
            final selected = time == slot;

            return ChoiceChip(
              label: Text(
                slot,
                style: const TextStyle(fontSize: 11),
              ),
              selected: selected,
              onSelected: (_) {
                setState(() => time = slot);
              },
              selectedColor: AppColors.teal.withValues(alpha: .15),
              side: BorderSide(
                color: selected ? AppColors.teal : AppColors.line,
              ),
            );
          }).toList(),
        );
        }),
        const SizedBox(height: 15),
        const Text(
          'Your preferred schedule will be reviewed by the clinic. '
          'The appointment is not confirmed until approved.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // STEP 4: PAYMENT METHOD
  // --------------------------------------------------

  Widget _paymentStep() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _paymentMethodsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeading(
                'Payment method',
                subtitle: 'Choose your preferred payment method.',
              ),
              SurfaceCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading(
                'Payment method',
                subtitle: 'Choose your preferred payment method.',
              ),
              SurfaceCard(
                child: Text(
                  'Unable to load payment methods: ${snapshot.error}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        }

        final methods = snapshot.data ?? const <Map<String, dynamic>>[];
        _latestPaymentMethodDocs = methods;
        if (paymentMethodId != null && !methods.any((method) => method['_docId']?.toString() == paymentMethodId && method['status'] == 'Active')) {
          paymentMethodId = null;
        }

        final visibleMethods = methods.where((method) {
          final status = method['status']?.toString();
          return status == 'Active' || status == 'Setup';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeading(
              'Payment method',
              subtitle: 'Choose how you prefer to pay. '
                  'Payment options are managed by the clinic.',
            ),
            if (visibleMethods.isEmpty)
              const SurfaceCard(
                child: Text(
                  'There are currently no payment methods available. '
                  'Please contact the clinic.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              )
            else
              ...visibleMethods.map((method) {
                final name = _stringValue([
                  method['name'],
                  method['type'],
                ], fallback: 'Payment method');

                final status = method['status']?.toString() ?? '';
                final enabled = status == 'Active';
                final methodId = method['_docId']?.toString() ?? '';
                final chosen = enabled &&
                    methodId.isNotEmpty &&
                    paymentMethodId == methodId;

                final icon = name.toLowerCase().contains('cash')
                    ? Icons.payments_outlined
                    : name.toLowerCase().contains('bank')
                        ? Icons.account_balance_outlined
                        : name.toLowerCase().contains('card')
                            ? Icons.credit_card
                            : Icons.account_balance_wallet_outlined;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    color: chosen ? AppColors.sky : Colors.white,
                    onTap: enabled && methodId.isNotEmpty
                        ? () {
                            setState(() {
                              paymentMethodId = methodId;
                            });
                          }
                        : null,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.mint,
                          radius: 20,
                          child: Icon(
                            icon,
                            color: AppColors.teal,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: enabled ? null : AppColors.muted,
                                ),
                              ),
                              if (!enabled)
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Text(
                                    'This payment option is not available yet.',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!enabled)
                          const Text(
                            'Coming soon',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Icon(
                            chosen
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: AppColors.teal,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            if (visibleMethods.any((method) => method['status'] == 'Active') && paymentMethodId == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select one active payment method before submitting your request.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ),
              ),
            const SurfaceCard(
              color: AppColors.sky,
              child: Text(
                'Your appointment request will remain Pending until the '
                'clinic reviews and approves it. Selecting a payment method '
                'does not charge you or mark the appointment as Paid. '
                'Payment remains Unpaid until it is verified.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // SUCCESS SCREEN
  // --------------------------------------------------

  Widget _successStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 43,
            backgroundColor: AppColors.mint,
            child: Icon(
              Icons.check_rounded,
              color: AppColors.green,
              size: 46,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Request submitted!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your request ${submittedId ?? ''} has been sent to the clinic. '
            'You can check its status in your appointments.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'View appointment',
              onPressed: widget.onDone,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: widget.onHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepTeal,
                side: const BorderSide(color: AppColors.teal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Back to home',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
