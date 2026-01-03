enum TransactionType { income, expense }

class TransactionModel {
  final String id;
  final double amount;
  final String categoryId;
  final TransactionType type;
  final DateTime date;
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.type,
    required this.date,
    this.createdAt,
  });

  // Convertir depuis Firestore
  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] ?? '',
      type: map['type'] == 'income' 
          ? TransactionType.income 
          : TransactionType.expense,
      date: map['date'] is String
          ? DateTime.parse(map['date'])
          : (map['date'] as dynamic).toDate(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String
              ? DateTime.parse(map['createdAt'])
              : (map['createdAt'] as dynamic).toDate())
          : null,
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'categoryId': categoryId,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'date': date,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  // Convertir le type en string
  String get typeString => type == TransactionType.income ? 'income' : 'expense';

  // Vérifier si c'est une dépense
  bool get isExpense => type == TransactionType.expense;

  // Vérifier si c'est un revenu
  bool get isIncome => type == TransactionType.income;

  // Copier avec modifications
  TransactionModel copyWith({
    String? id,
    double? amount,
    String? categoryId,
    TransactionType? type,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Formatter le montant avec la devise
  String get formattedAmount => '${amount.toStringAsFixed(2)} د.ت';

  // Formatter la date
  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Formatter la date et l'heure
  String get formattedDateTime {
    return '${formattedDate} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, amount: $amount, categoryId: $categoryId, type: $typeString, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is TransactionModel &&
      other.id == id &&
      other.amount == amount &&
      other.categoryId == categoryId &&
      other.type == type &&
      other.date == date;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      amount.hashCode ^
      categoryId.hashCode ^
      type.hashCode ^
      date.hashCode;
  }
}