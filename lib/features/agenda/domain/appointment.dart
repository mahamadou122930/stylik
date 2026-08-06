import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Statuts d'un rendez-vous (`appointments.status`).
enum AppointmentStatus {
  scheduled('scheduled', 'Planifié', AppColors.blue),
  confirmed('confirmed', 'Confirmé', AppColors.accent),
  inProgress('in_progress', 'En cours', AppColors.amber),
  completed('completed', 'Terminé', AppColors.primary),
  cancelled('cancelled', 'Annulé', AppColors.expense),
  noShow('no_show', 'Absent', AppColors.textFaint);

  const AppointmentStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static AppointmentStatus fromValue(String? value) =>
      AppointmentStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => AppointmentStatus.scheduled,
      );

  bool get isActive =>
      this == scheduled || this == confirmed || this == inProgress;
}

/// Prestation attachée à un rendez-vous (colonne `service_items`, JSONB).
class AppointmentService {
  const AppointmentService({
    required this.serviceId,
    required this.name,
    required this.priceFcfa,
    required this.durationMinutes,
    this.stylistName,
  });

  final String serviceId;
  final String name;
  final int priceFcfa;
  final int durationMinutes;
  final String? stylistName;

  factory AppointmentService.fromMap(Map<String, dynamic> map) =>
      AppointmentService(
        serviceId: (map['service_id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        priceFcfa: (map['price_fcfa'] as num?)?.toInt() ?? 0,
        durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 0,
        stylistName: map['stylist_name'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'service_id': serviceId,
        'name': name,
        'price_fcfa': priceFcfa,
        'duration_minutes': durationMinutes,
        'stylist_name': stylistName,
      };
}

/// Rendez-vous — table `appointments`.
class Appointment {
  const Appointment({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.stylistId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.totalPriceFcfa,
    this.services = const [],
    this.notes,
    this.clientName,
    this.stylistName,
    this.clientVisitCount = 0,
    this.clientPhone,
  });

  final String id;
  final String salonId;
  final String? clientId;
  final String stylistId;
  final DateTime startTime;
  final DateTime endTime;
  final AppointmentStatus status;
  final int totalPriceFcfa;

  /// Prestations réservées.
  final List<AppointmentService> services;

  final String? notes;

  /// Champs dénormalisés issus des jointures (affichage agenda).
  final String? clientName;
  final String? stylistName;
  final int clientVisitCount;
  final String? clientPhone;

  Duration get duration => endTime.difference(startTime);

  /// Identifiants des prestations, pour la caisse.
  List<String> get serviceIds =>
      services.map((service) => service.serviceId).toList();

  /// « Coupe + brushing ».
  String get summary => services.isEmpty
      ? 'Prestation'
      : services.map((service) => service.name).join(' + ');

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  factory Appointment.fromMap(Map<String, dynamic> map) => Appointment(
        id: map['id'] as String,
        salonId: map['salon_id'] as String,
        clientId: map['client_id'] as String?,
        stylistId: map['stylist_id'] as String,
        startTime: DateTime.parse(map['start_time'] as String).toLocal(),
        endTime: DateTime.parse(map['end_time'] as String).toLocal(),
        status: AppointmentStatus.fromValue(map['status'] as String?),
        totalPriceFcfa: (map['total_price_fcfa'] as num?)?.toInt() ?? 0,
        services: (map['service_items'] as List?)
                ?.map((e) =>
                    AppointmentService.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        notes: map['notes'] as String?,
        clientName: _joined(map['clients'], 'full_name'),
        stylistName: _joined(map['profiles'], 'full_name'),
        clientVisitCount: map['clients'] is Map<String, dynamic>
            ? ((map['clients'] as Map<String, dynamic>)['visit_count'] as num?)
                    ?.toInt() ??
                0
            : 0,
        clientPhone: _joined(map['clients'], 'phone'),
      );

  Map<String, dynamic> toMap() => {
        'salon_id': salonId,
        'client_id': clientId,
        'stylist_id': stylistId,
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'status': status.value,
        'total_price_fcfa': totalPriceFcfa,
        'service_items': services.map((service) => service.toMap()).toList(),
        'service_ids': serviceIds,
        'notes': notes,
      };

  static String? _joined(Object? relation, String field) {
    if (relation is Map<String, dynamic>) return relation[field] as String?;
    if (relation is List && relation.isNotEmpty) {
      return (relation.first as Map<String, dynamic>)[field] as String?;
    }
    return null;
  }
}
