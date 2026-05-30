// --- TRANSACTION MODEL ---
// Data structure for a single expense or income entry.
// Maps between the app, SQLite database, and the Laravel API.
class TransactionModel {
  final String id;
  final String userId;
  final String type;
  final String category;
  final double amount;
  final String date;
  final String? note;
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final String currency;
  final bool isSynced;

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
    this.currency = 'LKR',
    this.isSynced = true,
  });

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
      'currency': currency,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'expense',
      category: map['category']?.toString() ?? 'Other',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date']?.toString() ?? '',
      note: map['note']?.toString(),
      imagePath: map['imagePath']?.toString(),
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      currency: map['currency']?.toString() ?? 'LKR',
      isSynced: (map['isSynced'] as int? ?? 1) == 1,
    );
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'expense',
      category: json['category']?.toString() ?? 'Other',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      date: json['date']?.toString() ?? '',
      note: json['note']?.toString(),
      imagePath: json['imagePath']?.toString(),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      currency: json['currency']?.toString() ?? 'LKR',
      isSynced: true,
    );
  }

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
    String? currency,
    bool? isSynced,
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
      currency: currency ?? this.currency,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}