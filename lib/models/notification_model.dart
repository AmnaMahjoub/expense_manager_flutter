import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  budgetWarning, // 90% atteint
  budgetExceeded, // 100% dépassé
  info,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final String? categoryId;
  final String? budgetId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata; // Données supplémentaires

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.categoryId,
    this.budgetId,
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  // Convertir depuis Firestore
  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: _parseNotificationType(map['type']),
      categoryId: map['categoryId'],
      budgetId: map['budgetId'],
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convertir vers Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'categoryId': categoryId,
      'budgetId': budgetId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  // Parser le type de notification
  static NotificationType _parseNotificationType(dynamic type) {
    if (type == null) return NotificationType.info;
    
    switch (type.toString()) {
      case 'budgetWarning':
        return NotificationType.budgetWarning;
      case 'budgetExceeded':
        return NotificationType.budgetExceeded;
      default:
        return NotificationType.info;
    }
  }

  // Créer une copie avec modifications
  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    String? categoryId,
    String? budgetId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      budgetId: budgetId ?? this.budgetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Obtenir l'icône selon le type
  String get iconName {
    switch (type) {
      case NotificationType.budgetWarning:
        return 'warning';
      case NotificationType.budgetExceeded:
        return 'error';
      case NotificationType.info:
        return 'info';
    }
  }

  // Obtenir la couleur selon le type
  String get colorName {
    switch (type) {
      case NotificationType.budgetWarning:
        return 'orange';
      case NotificationType.budgetExceeded:
        return 'red';
      case NotificationType.info:
        return 'blue';
    }
  }

  // Format de date lisible
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}