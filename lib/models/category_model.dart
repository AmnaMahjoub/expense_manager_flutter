class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String type; // 'expense' ou 'income'
  final bool isPredefined; // true si catégorie prédéfinie

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.type = 'expense',
    this.isPredefined = false,
  });

  // Convertir depuis Firestore
  factory Category.fromMap(Map<String, dynamic> map, String id) {
    return Category(
      id: id,
      name: map['name'] ?? 'Sans nom',
      icon: map['icon'] ?? 'category',
      color: map['color'] ?? 'blue',
      type: map['type'] ?? 'expense',
      isPredefined: map['isPredefined'] ?? false,
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
      'isPredefined': isPredefined,
    };
  }
}