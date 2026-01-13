import 'package:expense_manager/models/budget_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/budget_service.dart';
import 'package:expense_manager/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetChecker {
  final BudgetService _budgetService = BudgetService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Vérifier tous les budgets du mois en cours
  Future<void> checkAllBudgets() async {
    try {
      print('🔍 Checking all budgets...');

      final budgets = await _budgetService.getCurrentMonthBudgets();

      if (budgets.isEmpty) {
        print('ℹ️ No budgets to check');
        return;
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      for (var budget in budgets) {
        await _checkBudget(
          budget: budget,
          startDate: startOfMonth,
          endDate: endOfMonth,
        );
      }

      print('✅ Budget check completed');
    } catch (e) {
      print('❌ Error checking budgets: $e');
    }
  }

  // Vérifier un budget spécifique après l'ajout d'une transaction
  Future<void> checkBudgetForCategory({
    required String categoryId,
    required Category category,
  }) async {
    try {
      print('🔍 Checking budget for category: ${category.name}');

      final budget = await _budgetService.getBudget(categoryId: categoryId);

      if (budget == null) {
        print('ℹ️ No budget set for this category');
        return;
      }

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      await _checkBudget(
        budget: budget,
        startDate: startOfMonth,
        endDate: endOfMonth,
        categoryName: category.name,
      );
    } catch (e) {
      print('❌ Error checking budget for category: $e');
    }
  }

  // Vérifier un budget et créer des notifications si nécessaire
  Future<void> _checkBudget({
    required Budget budget,
    required DateTime startDate,
    required DateTime endDate,
    String? categoryName,
  }) async {
    try {
      if (_userId == null) {
        print('❌ No user authenticated');
        return;
      }

      print('📊 Calculating spent amount for category: ${budget.categoryId}');
      
      final totalSpent = await _getDirectCategorySpent(
        categoryId: budget.categoryId,
        startDate: startDate,
        endDate: endDate,
      );

      final percentage = (totalSpent / budget.amount) * 100;

      print('📊 Budget status: ${percentage.toStringAsFixed(1)}% ($totalSpent/${budget.amount})');

      final catName = categoryName ?? 'Catégorie';

      // ✅ ANTI-DOUBLON : Vérifier si une notification similaire existe déjà
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      final existingNotifications = await _getRecentNotifications(
        categoryId: budget.categoryId,
        budgetId: budget.id,
        since: startOfDay,
      );

      // Vérifier si le budget est dépassé (>=100%)
      if (percentage >= 100) {
        // Vérifier si une notification "dépassé" existe déjà aujourd'hui
        final hasExceededNotif = existingNotifications.any(
          (n) => n['type'] == 'budgetExceeded'
        );

        if (!hasExceededNotif) {
          print('🚨 Budget exceeded! Creating notification...');
          await _notificationService.createBudgetExceededNotification(
            categoryName: catName,
            categoryId: budget.categoryId,
            budgetId: budget.id,
            spent: totalSpent,
            budget: budget.amount,
          );
        } else {
          print('ℹ️ Budget exceeded notification already exists today');
        }
      }
      // Vérifier si le budget atteint 90%
      else if (percentage >= 90) {
        // Vérifier si une notification "warning" existe déjà aujourd'hui
        final hasWarningNotif = existingNotifications.any(
          (n) => n['type'] == 'budgetWarning'
        );

        if (!hasWarningNotif) {
          print('⚠️ Budget warning (90%)! Creating notification...');
          await _notificationService.createBudgetWarningNotification(
            categoryName: catName,
            categoryId: budget.categoryId,
            budgetId: budget.id,
            spent: totalSpent,
            budget: budget.amount,
          );
        } else {
          print('ℹ️ Budget warning notification already exists today');
        }
      }
    } catch (e) {
      print('❌ Error in _checkBudget: $e');
    }
  }

  // ✅ NOUVELLE MÉTHODE : Récupérer les notifications récentes pour éviter les doublons
  Future<List<Map<String, dynamic>>> _getRecentNotifications({
    required String categoryId,
    required String budgetId,
    required DateTime since,
  }) async {
    try {
      if (_userId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .where('categoryId', isEqualTo: categoryId)
          .where('budgetId', isEqualTo: budgetId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'type': data['type'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e) {
      print('⚠️ Error fetching recent notifications: $e');
      return [];
    }
  }

  // ✅ MÉTHODE OPTIMISÉE : Calculer les dépenses DIRECTEMENT depuis Firestore
  Future<double> _getDirectCategorySpent({
    required String categoryId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (_userId == null) return 0.0;

      print('💾 Fetching transactions for category: $categoryId');
      print('📅 Period: ${startDate.toString()} -> ${endDate.toString()}');

      // ✅ SOLUTION : Récupérer TOUTES les transactions puis filtrer en mémoire
      // Cela évite le besoin d'un index composite complexe
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .where('categoryId', isEqualTo: categoryId)
          .where('type', isEqualTo: 'expense')
          .get();

      print('📦 Fetched ${snapshot.docs.length} expense transactions');

      double total = 0.0;
      int counted = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp?;
        
        if (timestamp != null) {
          final date = timestamp.toDate();
          
          // Filtrer par date en mémoire
          if (date.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
              date.isBefore(endDate.add(const Duration(seconds: 1)))) {
            final amount = (data['amount'] ?? 0).toDouble();
            total += amount;
            counted++;
          }
        }
      }

      print('💰 Total spent for category $categoryId: $total د.ت ($counted transactions)');
      return total;
    } catch (e) {
      print('❌ Error calculating direct category spent: $e');
      print('Stack trace: ${StackTrace.current}');
      return 0.0;
    }
  }

  // Calculer les dépenses pour une catégorie (méthode publique)
  Future<double> getCategorySpent({
    required String categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      return await _getDirectCategorySpent(
        categoryId: categoryId,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      print('❌ Error getting category spent: $e');
      return 0.0;
    }
  }

  // Obtenir le statut du budget (en cours, dépassé, etc.)
  Future<BudgetStatus> getBudgetStatus({
    required String categoryId,
  }) async {
    try {
      final budget = await _budgetService.getBudget(categoryId: categoryId);

      if (budget == null) {
        return BudgetStatus.noBudget;
      }

      final spent = await getCategorySpent(categoryId: categoryId);
      final percentage = (spent / budget.amount) * 100;

      print('📊 Budget status for $categoryId: ${percentage.toStringAsFixed(1)}%');

      if (percentage >= 100) {
        return BudgetStatus.exceeded;
      } else if (percentage >= 90) {
        return BudgetStatus.warning;
      } else if (percentage >= 75) {
        return BudgetStatus.caution;
      } else {
        return BudgetStatus.safe;
      }
    } catch (e) {
      print('❌ Error getting budget status: $e');
      return BudgetStatus.noBudget;
    }
  }
}

enum BudgetStatus {
  noBudget,
  safe, // < 75%
  caution, // 75-89%
  warning, // 90-99%
  exceeded, // >= 100%
}