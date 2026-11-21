
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../models/portal_models.dart';
import '../../shared/widgets/ui.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
    required this.onBook,
  });

  final ValueChanged<DentalService> onBook;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final PatientPortalRepository _repository = PatientPortalRepository();
  final TextEditingController _searchController = TextEditingController();

  late final Stream<List<Map<String, dynamic>>> _servicesStream;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _servicesStream = _repository.watchServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // FIRESTORE DATA CONVERSION
  // ------------------------------------------------------------

  double _parsePrice(dynamic value) {
    if (value is num) return value.toDouble();

    final cleaned = (value ?? '')
        .toString()
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');

    return double.tryParse(cleaned) ?? 0;
  }

  int _parseDuration(dynamic value) {
    if (value is num) return value.toInt();

    final match = RegExp(r'\d+').firstMatch((value ?? '').toString());

    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  String _readText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return fallback;
  }

  bool _isActiveService(Map<String, dynamic> data) {
    final activeValue =
        data['isActive'] ?? data['is_active'] ?? data['active'];

    if (activeValue == false ||
        activeValue == 0 ||
        activeValue?.toString().toLowerCase() == 'false') {
      return false;
    }

    final status = (data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    const hiddenStatuses = {
      'inactive',
      'disabled',
      'archived',
      'deleted',
      'draft',
      'hidden',
    };

    return !hiddenStatuses.contains(status);
  }

  IconData _getServiceIcon(String name) {
    final value = name.toLowerCase();

    if (value.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }

    if (value.contains('extract')) {
      return Icons.medical_services_rounded;
    }

    if (value.contains('fill')) {
      return Icons.health_and_safety_rounded;
    }

    if (value.contains('ortho') || value.contains('braces')) {
      return Icons.sentiment_satisfied_alt_rounded;
    }

    if (value.contains('whiten')) {
      return Icons.auto_awesome_rounded;
    }

    if (value.contains('x-ray') || value.contains('xray')) {
      return Icons.document_scanner_rounded;
    }

    if (value.contains('crown') || value.contains('denture')) {
      return Icons.medical_information_rounded;
    }

    return Icons.health_and_safety_rounded;
  }

  Color _getServiceTint(String name) {
    final value = name.toLowerCase();

    if (value.contains('clean')) return AppColors.mint;
    if (value.contains('extract')) return AppColors.peach;
    if (value.contains('ortho') || value.contains('braces')) {
      return AppColors.lavender;
    }
    if (value.contains('whiten')) return AppColors.sky;

    return AppColors.mint;
  }

  DentalService? _convertService(Map<String, dynamic> data) {
    final id = _readText(
      data,
      ['id', '_docId'],
    );

    final name = _readText(
      data,
      ['name', 'serviceName', 'service_name'],
    );

    if (id.isEmpty || name.isEmpty) return null;

    final description = _readText(
      data,
      ['description', 'details', 'serviceDescription'],
      fallback: 'No description available.',
    );

    final price = _parsePrice(
      data['price'] ?? data['amount'],
    );

    final duration = _parseDuration(
      data['durationMinutes'] ??
          data['duration'] ??
          data['duration_minutes'],
    );

    return DentalService(
      id: id,
      name: name,
      description: description,
      price: price,
      duration: duration,
      icon: _getServiceIcon(name),
      tint: _getServiceTint(name),
    );
  }

  List<DentalService> _convertServices(
    List<Map<String, dynamic>> documents,
  ) {
    final result = <DentalService>[];

    for (final document in documents) {
      if (!_isActiveService(document)) continue;

      final service = _convertService(document);

      if (service != null) {
        result.add(service);
      }
    }

    return result;
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  List<DentalService> _filterServices(List<DentalService> services) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return services;

    return services.where((service) {
      return service.name.toLowerCase().contains(query) ||
          service.description.toLowerCase().contains(query);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth < 400 ? 16.0 : 24.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    22,
                    horizontalPadding,
                    32,
                  ),
                  children: [
                    const PageHeading(
                      'Dental services',
                      subtitle:
                          'Explore our available dental treatments and services.',
                    ),
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    _buildInformationBanner(),
                    const SizedBox(height: 24),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _servicesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildErrorState();
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return _buildLoadingState();
                        }

                        final documents = snapshot.data ?? [];

                        final services = _filterServices(
                          _convertServices(documents),
                        );

                        if (services.isEmpty) {
                          return _buildEmptyState(
                            hasSearch: _searchQuery.trim().isNotEmpty,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(
                              _searchQuery.trim().isEmpty
                                  ? 'Available services (${services.length})'
                                  : 'Search results (${services.length})',
                            ),
                            ...services.map(
                              (service) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: _ServiceCard(
                                  service: service,
                                  onBook: () => widget.onBook(service),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
      decoration: InputDecoration(
        hintText: 'Search dental services...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.teal,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget _buildInformationBanner() {
    return const SurfaceCard(
      color: AppColors.sky,
      padding: EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.teal,
            size: 21,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Service prices and estimated durations are provided by the clinic. '
              'Your dentist will confirm the appropriate treatment after assessment.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.deepTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 65),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: AppColors.teal,
              strokeWidth: 2.5,
            ),
            SizedBox(height: 15),
            Text(
              'Loading dental services...',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SurfaceCard(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.red,
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load services',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please check your internet connection or try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                // Rebuild the StreamBuilder to reconnect to Firestore.
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool hasSearch}) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 35,
      ),
      child: Column(
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.medical_services_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 13),
          Text(
            hasSearch
                ? 'No matching services'
                : 'No services available yet',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try another service name or clear your search.'
                : 'The clinic has not published any services yet. Please check back later.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// SERVICE CARD
// ------------------------------------------------------------

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onBook,
  });

  final DentalService service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  color: service.tint,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  service.icon,
                  color: AppColors.teal,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              height: 1,
              color: AppColors.line,
            ),
          ),
          Row(
            children: [
              if (service.duration > 0) ...[
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 5),
                Text(
                  '${service.duration} min',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '₱${service.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 13),
              SizedBox(
                height: 39,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Book',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}