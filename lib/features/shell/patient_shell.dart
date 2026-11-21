import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';


import '../../models/portal_models.dart';


import '../appointments/appointments_screen.dart';

import '../appointments/booking_screen.dart';

import '../appointments/request_detail_screen.dart';

import '../auth/auth_screen.dart';

import '../chatbot/chatbot_screen.dart';

import '../clinic/clinic_info_screen.dart';

import '../dashboard/dashboard_screen.dart';

import '../dentists/dentists_screen.dart';

import '../notifications/notifications_screen.dart';

import '../profile/profile_screen.dart';

import '../profile/patient_profile_screen.dart';

import '../profile/records_screen.dart';

import '../payments/payments_screen.dart';

import '../reviews/reviews_screen.dart';

import '../services/services_screen.dart';

import '../settings/settings_screen.dart';

import '../support/support_tickets_screen.dart';

import '../messages/messages_screen.dart';

class PatientShell extends StatefulWidget {

  const PatientShell({

    super.key,

    required this.prefs,

    required this.name,

  });

  final SharedPreferences prefs;

  final String name;

  @override

  State<PatientShell> createState() => _PatientShellState();

}

class _PatientShellState extends State<PatientShell> {

  int selected = 0;

  Dentist? selectedDentist;

  DentalService? selectedService;

  final List<int> history = [];
  String? _resumeTicketId;
  List<Map<String, dynamic>> _resumeTicketMessages = const [];

  // --------------------------------------------------

  // NAVIGATION

  // --------------------------------------------------

  void go(int index) {

    if (index == selected) return;

    setState(() {

      history.add(selected);

      selected = index;

    });

  }

  void back() {

    if (history.isNotEmpty) {

      setState(() {

        selected = history.removeLast();

      });

    } else if (selected != 0) {

      setState(() {

        selected = 0;

      });

    }

  }

  void openDentist(Dentist dentist) {

    selectedDentist = dentist;

    go(13);

  }

  void bookService(DentalService service) {
    selectedService = service;
    go(9);
  }

  void continueTicketWithAi(Map<String, dynamic> ticket) {
    _resumeTicketId = (ticket['_docId'] ?? ticket['id'] ?? '').toString();
    _resumeTicketMessages = (ticket['messages'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (selected == 8) {
      setState(() {});
    } else {
      go(8);
    }
  }

  // --------------------------------------------------

  // PAGE ROUTES

  // --------------------------------------------------

  List<Widget> get pages => [

        // 0 - Dashboard

        DashboardScreen(

          name: widget.name,

          go: go,

          onDentist: openDentist,

        ),

        // 1 - Appointments

        AppointmentsScreen(

          onBook: () => go(9),

          onReviews: () => go(11),

        ),

        // 2 - Profile

        ProfileScreen(

          name: widget.name,

          openPatientProfile: () => go(17),

          openRecords: () => go(10),

          openReviews: () => go(11),

          openSettings: () => go(12),

          openPayments: () => go(16),

          logout: logout,

        ),

        // 3 - Dentists

        DentistsScreen(

          onSelect: openDentist,

        ),

        // 4 - Services

        ServicesScreen(

          onBook: bookService,

        ),

        // 5 - Clinic Information

        const ClinicInfoScreen(),

        // 6 - Notifications

        const NotificationsScreen(),

        // 7 - Reserved legacy slot. Patient support is handled by Alapot AI.
        const SizedBox.shrink(),

        // 8 - Alapot AI

        ChatbotScreen(
          key: ValueKey(_resumeTicketId ?? 'new-alapot-ai'),
          initialTicketId: _resumeTicketId,
          initialMessages: _resumeTicketMessages,
        ),

        // 9 - Booking

        BookingScreen(

          initialService: selectedService,

          initialDentist: selectedDentist,

          onDone: () {

            setState(() {

              selectedService = null;

              selectedDentist = null;

            });

            go(18);

          },

          onHome: () {

            setState(() {

              selectedService = null;

              selectedDentist = null;

            });

            go(0);

          },

        ),

        // 10 - My Records

        const RecordsScreen(),

        // 11 - My Reviews

        const ReviewsScreen(),

        // 12 - Settings

        SettingsScreen(

          openProfile: () => go(17),

          openRecords: () => go(10),

          openReviews: () => go(11),

          openPayments: () => go(16),

          openSupportTickets: () => go(19),

        ),

        // 13 - Dentist Details

        if (selectedDentist != null)

          DentistDetailScreen(

            dentist: selectedDentist!,

            onBook: () => go(9),

            onMessage: () => go(15),

          )

        else

          const SizedBox.shrink(),

        // 14 - Additional Notifications Route

        const NotificationsScreen(),

        // 15 - Messages

        MessagesScreen(

          initialDentist: selectedDentist,

        ),

        // 16 - Payments

        const PaymentsScreen(),

        // 17 - Patient Profile

        PatientProfileScreen(

          name: widget.name,

        ),

        // 18 - Booking Request Details

        RequestDetailScreen(

          onAppointments: () => go(1),

        ),

        // 19 - Patient support tickets connected to the Admin Support Center
        SupportTicketsScreen(onContinueWithAi: continueTicketWithAi),

      ];

  // --------------------------------------------------

  // MAIN BUILD

  // --------------------------------------------------

  @override

  Widget build(BuildContext context) {

    return LayoutBuilder(

      builder: (context, box) {

        final desktop = box.maxWidth >= 900;

        final surface = Theme.of(context).cardColor;

        final shell = Scaffold(

          backgroundColor: Theme.of(context).scaffoldBackgroundColor,

          drawer: desktop

              ? null

              : Drawer(

                  width: 250,

                  child: SafeArea(

                    child: _sidebarContent(true),

                  ),

                ),

          appBar: desktop

              ? null

              : AppBar(

                  leading: selected == 0

                      ? Builder(

                          builder: (c) => IconButton(

                            onPressed: () {

                              Scaffold.of(c).openDrawer();

                            },

                            icon: const Icon(Icons.menu_rounded),

                          ),

                        )

                      : IconButton(

                          onPressed: back,

                          icon: const Icon(Icons.arrow_back_rounded),

                        ),

                  title: const Text(

                    'Alapot Dental',

                    style: TextStyle(fontSize: 14),

                  ),

                  actions: [

                    IconButton(

                      tooltip: 'Notifications',

                      onPressed: () => go(6),

                      icon: const Icon(

                        Icons.notifications_none_rounded,

                      ),

                    ),

                    IconButton(

                      tooltip: 'Book an appointment',

                      onPressed: () => go(9),

                      icon: const Icon(

                        Icons.add_circle_outline_rounded,

                      ),

                    ),

                    const SizedBox(width: 6),

                  ],

                ),

          body: Row(

            children: [

              if (desktop)

                SizedBox(

                  width: 168,

                  child: _sidebarContent(false),

                ),

              Expanded(

                child: Column(

                  children: [

                    if (desktop)

                      Container(

                        height: 64,

                        color: surface,

                        padding: const EdgeInsets.symmetric(

                          horizontal: 25,

                        ),

                        child: Row(

                          children: [

                            if (selected != 0)

                              IconButton(

                                tooltip: 'Back',

                                onPressed: back,

                                icon: const Icon(

                                  Icons.arrow_back_rounded,

                                ),

                              ),

                            const Text(

                              'Alapot Dental Clinic',

                              style: TextStyle(

                                fontSize: 14,

                                fontWeight: FontWeight.w700,

                              ),

                            ),

                            const Spacer(),

                            IconButton(

                              tooltip: 'Notifications',

                              onPressed: () => go(6),

                              icon: const Icon(

                                Icons.notifications_none_rounded,

                              ),

                            ),

                            IconButton(

                              tooltip: 'Book an appointment',

                              onPressed: () => go(9),

                              icon: const Icon(

                                Icons.add_circle_outline_rounded,

                              ),

                            ),

                          ],

                        ),

                      ),

                    Expanded(

                      child: AnimatedSwitcher(

                        duration: const Duration(milliseconds: 230),

                        switchInCurve: Curves.easeOutCubic,

                        switchOutCurve: Curves.easeInCubic,

                        transitionBuilder: (child, animation) {

                          return FadeTransition(

                            opacity: animation,

                            child: SlideTransition(

                              position: Tween<Offset>(

                                begin: const Offset(.025, 0),

                                end: Offset.zero,

                              ).animate(animation),

                              child: child,

                            ),

                          );

                        },

                        child: KeyedSubtree(

                          key: ValueKey(selected),

                          child: pages[selected],

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        );

        return PopScope(

          canPop: false,

          onPopInvokedWithResult: (didPop, result) {

            if (!didPop) {

              back();

            }

          },

          child: shell,

        );

      },

    );

  }

  // --------------------------------------------------

  // SIDEBAR

  // --------------------------------------------------

  Widget _sidebarContent(bool closeAfterTap) {

    return Container(

      color: Theme.of(context).cardColor,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(12, 14, 9, 12),

            child: Row(

              children: [

                Image.asset(

                  'assets/images/alapot_logo.png',

                  width: 42,

                  height: 42,

                  fit: BoxFit.contain,

                ),

                const SizedBox(width: 7),

                const Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        'Alapot Dental',

                        style: TextStyle(

                          fontSize: 12,

                          fontWeight: FontWeight.w800,

                        ),

                      ),

                      Text(

                        'PATIENT PORTAL',

                        style: TextStyle(

                          fontSize: 6.5,

                          color: AppColors.muted,

                          letterSpacing: 1.0,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          const Divider(

            height: 1,

            color: AppColors.line,

          ),

          Expanded(

            child: ListView(

              padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),

              children: [

                // HOME

                _group('HOME'),

                _item(

                  0,

                  Icons.home_rounded,

                  'Home',

                  closeAfterTap,

                ),

                _item(

                  1,

                  Icons.calendar_month_rounded,

                  'Appointments',

                  closeAfterTap,

                ),

                const SizedBox(height: 7),

                // DENTAL CARE

                _group('DENTAL CARE'),

                _item(

                  3,

                  Icons.medical_services_outlined,

                  'Our Dentists',

                  closeAfterTap,

                ),

                _item(

                  4,

                  Icons.spa_outlined,

                  'Dental Services',

                  closeAfterTap,

                ),

                _item(

                  5,

                  Icons.local_hospital_outlined,

                  'Clinic Info',

                  closeAfterTap,

                ),

                const SizedBox(height: 7),

                // UPDATES

                _group('UPDATES'),

                _item(

                  6,

                  Icons.notifications_none_rounded,

                  'Notifications',

                  closeAfterTap,

                ),

                const SizedBox(height: 7),

                // COMMUNICATION

                _group('COMMUNICATION'),

                _item(

                  15,

                  Icons.chat_bubble_outline_rounded,

                  'Messages',

                  closeAfterTap,

                ),

                _item(

                  8,

                  Icons.smart_toy_outlined,

                  'Alapot AI',

                  closeAfterTap,

                ),

                const SizedBox(height: 7),

                // ACCOUNT

                _group('ACCOUNT'),

                _item(

                  12,

                  Icons.settings_outlined,

                  'Settings',

                  closeAfterTap,

                ),

              ],

            ),

          ),

          const Divider(

            height: 1,

            color: AppColors.line,

          ),

          Padding(

            padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),

            child: Row(

              children: [

                Expanded(

                  child: InkWell(

                    borderRadius: BorderRadius.circular(10),

                    onTap: () {

                      go(17);

                      if (closeAfterTap) {

                        Navigator.of(context).pop();

                      }

                    },

                    child: Padding(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 7,

                        vertical: 10,

                      ),

                      child: Text(

                        widget.name,

                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,

                        style: const TextStyle(

                          fontSize: 10,

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                    ),

                  ),

                ),

                const SizedBox(width: 5),

                InkWell(

                  borderRadius: BorderRadius.circular(10),

                  onTap: logout,

                  child: const Padding(

                    padding: EdgeInsets.symmetric(

                      horizontal: 8,

                      vertical: 10,

                    ),

                    child: Row(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Icon(

                          Icons.logout_rounded,

                          size: 16,

                          color: AppColors.red,

                        ),

                        SizedBox(width: 5),

                        Text(

                          'Log out',

                          style: TextStyle(

                            fontSize: 9,

                            fontWeight: FontWeight.w600,

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

  // --------------------------------------------------

  // SIDEBAR GROUP

  // --------------------------------------------------

  Widget _group(String text) {

    return Padding(

      padding: const EdgeInsets.fromLTRB(11, 7, 8, 5),

      child: Text(

        text,

        style: const TextStyle(

          fontSize: 8,

          letterSpacing: 1.1,

          fontWeight: FontWeight.w800,

          color: AppColors.muted,

        ),

      ),

    );

  }

  // --------------------------------------------------

  // SIDEBAR ITEM

  // --------------------------------------------------

  Widget _item(

    int index,

    IconData icon,

    String label,

    bool close,

  ) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 1),

      child: ListTile(

        dense: true,

        minVerticalPadding: 4,

        minLeadingWidth: 19,

        contentPadding: const EdgeInsets.symmetric(

          horizontal: 7,

        ),

        visualDensity: const VisualDensity(vertical: -2),

        selected: selected == index,

        selectedTileColor: AppColors.teal.withValues(

          alpha: .11,

        ),

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(10),

        ),

        leading: Icon(

          icon,

          size: 16,

          color: selected == index

              ? AppColors.teal

              : AppColors.muted,

        ),

        title: Text(

          label,

          style: TextStyle(

            fontSize: 9.5,

            fontWeight: selected == index

                ? FontWeight.w700

                : FontWeight.w500,

            color: selected == index

                ? AppColors.deepTeal

                : Theme.of(context).colorScheme.onSurface,

          ),

        ),

        onTap: () {

          go(index);

          if (close) {

            Navigator.of(context).pop();

          }

        },

      ),

    );

  }

  // --------------------------------------------------

  // LOGOUT

  // --------------------------------------------------

  Future<void> logout() async {

    final confirm = await showDialog<bool>(

      context: context,

      builder: (dialogContext) => AlertDialog(

        title: const Text('Log out?'),

        content: const Text(

          'Are you sure you want to log out of your account?',

        ),

        actions: [

          TextButton(

            onPressed: () {

              Navigator.pop(dialogContext, false);

            },

            child: const Text('Cancel'),

          ),

          FilledButton(

            onPressed: () {

              Navigator.pop(dialogContext, true);

            },

            child: const Text('Log out'),

          ),

        ],

      ),

    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    await widget.prefs.remove('session_active');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(

      context,

      MaterialPageRoute(

        builder: (_) => AuthScreen(

          prefs: widget.prefs,

        ),

      ),

      (_) => false,

    );

  }

}
