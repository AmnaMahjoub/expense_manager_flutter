import 'package:flutter/material.dart';

class CategoryIconUtils {
  // Map des icônes disponibles
  static const Map<String, IconData> icons = {
    'category': Icons.category,
    'home': Icons.home,
    'transport': Icons.directions_car,
    'car': Icons.directions_car,
    'food': Icons.restaurant,
    'restaurant': Icons.restaurant,
    'health': Icons.medical_services,
    'medical': Icons.medical_services,
    'entertainment': Icons.sports_esports,
    'games': Icons.sports_esports,
    'education': Icons.school,
    'school': Icons.school,
    'shopping': Icons.shopping_bag,
    'bag': Icons.shopping_bag,
    'salary': Icons.attach_money,
    'money': Icons.monetization_on,
    'work': Icons.work,
    'business': Icons.business,
    'investment': Icons.trending_up,
    'gift': Icons.card_giftcard,
    'bills': Icons.receipt_long,
    'utilities': Icons.lightbulb,
    'phone': Icons.phone,
    'internet': Icons.wifi,
    'gym': Icons.fitness_center,
    'other': Icons.more_horiz,
  };

  // Map des couleurs
  static const Map<String, Color> colors = {
    'red': Color(0xFFE74C3C),
    'green': Color(0xFF2ECC71),
    'blue': Color(0xFF3498DB),
    'orange': Color(0xFFF39C12),
    'purple': Color(0xFF9B59B6),
    'teal': Color(0xFF1ABC9C),
    'pink': Color(0xFFE91E63),
    'amber': Color(0xFFFFC107),
    'indigo': Color(0xFF3F51B5),
    'cyan': Color(0xFF00BCD4),
  };

  // Obtenir une icône par nom
  static IconData getIcon(String iconName) {
    return icons[iconName.toLowerCase()] ?? Icons.category;
  }

  // Obtenir une couleur par nom
  static Color getColor(String colorName) {
    return colors[colorName.toLowerCase()] ?? const Color(0xFF3498DB);
  }

  // Obtenir toutes les couleurs disponibles
  static List<MapEntry<String, Color>> getAvailableColors() {
    return colors.entries.toList();
  }

  // Obtenir les icônes populaires pour dépenses
  static List<MapEntry<String, IconData>> getPopularExpenseIcons() {
    return [
      const MapEntry('food', Icons.restaurant),
      const MapEntry('transport', Icons.directions_car),
      const MapEntry('shopping', Icons.shopping_bag),
      const MapEntry('health', Icons.medical_services),
      const MapEntry('entertainment', Icons.sports_esports),
      const MapEntry('education', Icons.school),
      const MapEntry('home', Icons.home),
      const MapEntry('bills', Icons.receipt_long),
      const MapEntry('phone', Icons.phone),
      const MapEntry('other', Icons.more_horiz),
    ];
  }

  // Obtenir les icônes populaires pour revenus
  static List<MapEntry<String, IconData>> getPopularIncomeIcons() {
    return [
      const MapEntry('salary', Icons.attach_money),
      const MapEntry('work', Icons.work),
      const MapEntry('business', Icons.business),
      const MapEntry('investment', Icons.trending_up),
      const MapEntry('gift', Icons.card_giftcard),
      const MapEntry('money', Icons.monetization_on),
    ];
  }
}