/// Salon — table `salons`.
class Salon {
  const Salon({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.email,
    this.logoUrl,
    this.openingHours = const {},
    this.currency = 'FCFA',
    this.inviteCode,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String? email;
  final String? logoUrl;

  /// Horaires d'ouverture, indexés par jour de la semaine (1 = lundi) :
  /// `{"1": {"open": "09:00", "close": "19:00"}}`. Un jour absent ou marqué
  /// `{"closed": true}` est considéré fermé.
  final Map<String, dynamic> openingHours;

  final String currency;

  /// Code à six caractères que le gérant dicte à un employé pour qu'il
  /// rejoigne le salon. Généré côté base, jamais réécrit depuis l'app.
  final String? inviteCode;

  factory Salon.fromMap(Map<String, dynamic> map) => Salon(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        phone: (map['phone'] as String?) ?? '',
        address: (map['address'] as String?) ?? '',
        email: map['email'] as String?,
        logoUrl: map['logo_url'] as String?,
        openingHours:
            (map['opening_hours'] as Map<String, dynamic>?) ?? const {},
        currency: (map['currency'] as String?) ?? 'FCFA',
        inviteCode: map['invite_code'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'address': address,
        'email': email,
        'logo_url': logoUrl,
        'opening_hours': openingHours,
        'currency': currency,
      };

  Salon copyWith({
    String? name,
    String? phone,
    String? address,
    String? email,
    String? logoUrl,
    Map<String, dynamic>? openingHours,
  }) =>
      Salon(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        email: email ?? this.email,
        logoUrl: logoUrl ?? this.logoUrl,
        openingHours: openingHours ?? this.openingHours,
        currency: currency,
        inviteCode: inviteCode,
      );
}

/// Créneau d'ouverture affiché dans la fiche salon.
class SalonOpeningSlot {
  const SalonOpeningSlot({
    required this.label,
    required this.open,
    required this.close,
    this.isClosed = false,
  });

  /// Libellé du jour ou du groupe de jours (« Lun – Ven »).
  final String label;
  final String open;
  final String close;
  final bool isClosed;
}

/// Lecture des horaires d'ouverture, avec regroupement des jours identiques
/// (« Lun – Ven · 9:00 – 19:00 »), comme dans la maquette.
class SalonOpeningHours {
  const SalonOpeningHours(this.slots);

  final List<SalonOpeningSlot> slots;

  static const List<String> _shortDays = [
    'Lun',
    'Mar',
    'Mer',
    'Jeu',
    'Ven',
    'Sam',
    'Dim',
  ];

  static const List<String> _fullDays = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  factory SalonOpeningHours.fromJson(Map<String, dynamic> json) {
    // Clé de comparaison par jour : "09:00-19:00" ou "" si fermé.
    final ranges = <String>[];
    for (var weekday = 1; weekday <= 7; weekday++) {
      final raw = json['$weekday'];
      if (raw is! Map<String, dynamic> || raw['closed'] == true) {
        ranges.add('');
        continue;
      }
      final open = (raw['open'] as String?) ?? '';
      final close = (raw['close'] as String?) ?? '';
      ranges.add(open.isEmpty || close.isEmpty ? '' : '$open-$close');
    }

    final slots = <SalonOpeningSlot>[];
    var start = 0;
    for (var i = 1; i <= 7; i++) {
      final isLast = i == 7;
      final sameAsPrevious = !isLast && ranges[i] == ranges[start];
      if (sameAsPrevious) continue;

      final end = i - 1;
      final label = start == end
          ? _fullDays[start]
          : '${_shortDays[start]} – ${_shortDays[end]}';
      final parts = ranges[start].split('-');

      slots.add(
        SalonOpeningSlot(
          label: label,
          open: parts.length == 2 ? parts.first : '',
          close: parts.length == 2 ? parts.last : '',
          isClosed: ranges[start].isEmpty,
        ),
      );
      start = i;
    }

    return SalonOpeningHours(slots);
  }
}
