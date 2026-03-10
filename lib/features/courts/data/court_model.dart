class Court {
  final String id;
  final String name;
  final String sportType;
  final String description;

  Court({
    required this.id,
    required this.name,
    required this.sportType,
    required this.description,
  });

  factory Court.fromMap(Map<String, dynamic> map) => Court(
        id: map['id'] as String,
        name: map['name'] as String,
        sportType: map['sport_type'] as String,
        description: map['description'] as String? ?? '',
      );
}

