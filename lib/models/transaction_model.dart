class TransactionModel {
  final String id;
  final String userId;
  final String type; // 'expense' or 'income'
  final String category;
  final double amount;
  final String date;
  final String? note;
  final String? imagePath;
  final double? latitude;
  final double? longitude;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.note,
    this.imagePath,
    this.latitude,
    this.longitude,
  });

  // Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'category': category,
      'amount': amount,
      'date': date,
      'note': note,
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create from SQLite Map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      userId: map['userId'],
      type: map['type'],
      category: map['category'],
      amount: map['amount'],
      date: map['date'],
      note: map['note'],
      imagePath: map['imagePath'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }

  // Create from JSON (for API data)
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      type: json['type'] ?? 'expense',
      category: json['category'] ?? 'Other',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      date: json['date'] ?? '',
      note: json['note'],
      imagePath: json['imagePath'],
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  // Convert to JSON (for API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'category': category,
      'amount': amount,
      'date': date,
      'note': note,
      'imagePath': imagePath,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // CopyWith — useful for editing
  TransactionModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? category,
    double? amount,
    String? date,
    String? note,
    String? imagePath,
    double? latitude,
    double? longitude,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}