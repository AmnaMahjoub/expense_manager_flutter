import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_manager/models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔐 Référence notifications utilisateur
  CollectionReference<Map<String, dynamic>> _notificationsRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Utilisateur non connecté');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  // =======================
  // 📥 LECTURE
  // =======================

  Future<List<NotificationModel>> getAllNotifications() async {
    final snapshot = await _notificationsRef()
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  // =======================
  // 📝 ÉCRITURE GÉNÉRIQUE
  // =======================

  Future<void> _addNotification(NotificationModel notification) async {
    await _notificationsRef().add(notification.toMap());
  }

  // =======================
  // 🚨 BUDGET : 90%
  // =======================

  Future<void> createBudgetWarningNotification({
    required String categoryName,
    required String categoryId,
    required String budgetId,
    required double spent,
    required double budget,
  }) async {
    await _addNotification(
      NotificationModel(
        id: '',
        title: '⚠️ Budget bientôt atteint',
        message:
            'La catégorie "$categoryName" a atteint ${(spent / budget * 100).toStringAsFixed(0)}% du budget.\n'
            'Dépensé : ${spent.toStringAsFixed(2)} / ${budget.toStringAsFixed(2)}',
        type: NotificationType.budgetWarning,
        categoryId: categoryId,
        budgetId: budgetId,
        createdAt: DateTime.now(),
        metadata: {
          'spent': spent,
          'budget': budget,
        },
      ),
    );
  }

  // =======================
  // 🚨 BUDGET : 100%
  // =======================

  Future<void> createBudgetExceededNotification({
    required String categoryName,
    required String categoryId,
    required String budgetId,
    required double spent,
    required double budget,
  }) async {
    await _addNotification(
      NotificationModel(
        id: '',
        title: '🚨 Budget dépassé',
        message:
            'Le budget de la catégorie "$categoryName" est dépassé.\n'
            'Dépensé : ${spent.toStringAsFixed(2)} / ${budget.toStringAsFixed(2)}',
        type: NotificationType.budgetExceeded,
        categoryId: categoryId,
        budgetId: budgetId,
        createdAt: DateTime.now(),
        metadata: {
          'spent': spent,
          'budget': budget,
        },
      ),
    );
  }

  // =======================
  // ✅ MARQUER COMME LU
  // =======================

  Future<void> markAsRead(String notificationId) async {
    await _notificationsRef()
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final batch = _firestore.batch();
    final snapshot = await _notificationsRef()
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // =======================
  // 🗑️ SUPPRESSION
  // =======================

  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef().doc(notificationId).delete();
  }

  Future<void> deleteAllNotifications() async {
    final batch = _firestore.batch();
    final snapshot = await _notificationsRef().get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
