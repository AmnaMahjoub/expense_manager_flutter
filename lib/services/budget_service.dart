import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_manager/models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _budgetsCollection {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('budgets');
  }

  // Créer ou mettre à jour un budget
  Future<String> setBudget({
    required String categoryId,
    required double amount,
    int? month,
    int? year,
  }) async {
    try {
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;

      print('💰 Setting budget: category=$categoryId, amount=$amount, period=$targetMonth/$targetYear');

      // Vérifier si un budget existe déjà pour cette catégorie et période
      final existing = await _budgetsCollection
          .where('categoryId', isEqualTo: categoryId)
          .where('month', isEqualTo: targetMonth)
          .where('year', isEqualTo: targetYear)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Mettre à jour le budget existant
        final docId = existing.docs.first.id;
        await _budgetsCollection.doc(docId).update({
          'amount': amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Budget updated: $docId');
        return docId;
      } else {
        // Créer un nouveau budget
        final docRef = await _budgetsCollection.add({
          'categoryId': categoryId,
          'amount': amount,
          'month': targetMonth,
          'year': targetYear,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ Budget created: ${docRef.id}');
        return docRef.id;
      }
    } catch (e) {
      print('❌ Error setting budget: $e');
      throw 'Erreur lors de la définition du budget';
    }
  }

  // Récupérer le budget d'une catégorie pour une période
  Future<Budget?> getBudget({
    required String categoryId,
    int? month,
    int? year,
  }) async {
    try {
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;

      print('📥 Getting budget: category=$categoryId, period=$targetMonth/$targetYear');

      final snapshot = await _budgetsCollection
          .where('categoryId', isEqualTo: categoryId)
          .where('month', isEqualTo: targetMonth)
          .where('year', isEqualTo: targetYear)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ No budget found');
        return null;
      }

      final budget = Budget.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>,
        snapshot.docs.first.id,
      );
      print('✅ Budget found: ${budget.amount} د.ت');
      return budget;
    } catch (e) {
      print('❌ Error getting budget: $e');
      return null;
    }
  }

  // Récupérer tous les budgets du mois en cours
  Future<List<Budget>> getCurrentMonthBudgets() async {
    try {
      final now = DateTime.now();
      print('📥 Getting current month budgets: ${now.month}/${now.year}');

      final snapshot = await _budgetsCollection
          .where('month', isEqualTo: now.month)
          .where('year', isEqualTo: now.year)
          .get();

      final budgets = snapshot.docs
          .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      print('✅ Found ${budgets.length} budgets for current month');
      return budgets;
    } catch (e) {
      print('❌ Error getting current month budgets: $e');
      return [];
    }
  }

  // Récupérer tous les budgets
  Future<List<Budget>> getAllBudgets() async {
    try {
      print('📥 Getting all budgets');

      final snapshot = await _budgetsCollection.get();

      final budgets = snapshot.docs
          .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Trier par date décroissante
      budgets.sort((a, b) {
        final dateA = DateTime(a.year, a.month);
        final dateB = DateTime(b.year, b.month);
        return dateB.compareTo(dateA);
      });

      print('✅ Found ${budgets.length} budgets');
      return budgets;
    } catch (e) {
      print('❌ Error getting all budgets: $e');
      return [];
    }
  }

  // Supprimer un budget
  Future<void> deleteBudget(String budgetId) async {
    try {
      print('🗑️ Deleting budget: $budgetId');
      await _budgetsCollection.doc(budgetId).delete();
      print('✅ Budget deleted');
    } catch (e) {
      print('❌ Error deleting budget: $e');
      throw 'Erreur lors de la suppression du budget';
    }
  }

  // Stream de tous les budgets du mois en cours
  Stream<List<Budget>> getCurrentMonthBudgetsStream() {
    final now = DateTime.now();
    print('🔄 Creating budgets stream for: ${now.month}/${now.year}');

    return _budgetsCollection
        .where('month', isEqualTo: now.month)
        .where('year', isEqualTo: now.year)
        .snapshots()
        .map((snapshot) {
          print('📡 Budgets stream update: ${snapshot.docs.length} budgets');
          return snapshot.docs
              .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
        });
  }

  // Vérifier si une catégorie a un budget pour le mois en cours
  Future<bool> hasBudget(String categoryId) async {
    final budget = await getBudget(categoryId: categoryId);
    return budget != null;
  }

  // Calculer le pourcentage utilisé du budget
  Future<double> getBudgetUsagePercentage({
    required String categoryId,
    required double spent,
    int? month,
    int? year,
  }) async {
    try {
      final budget = await getBudget(
        categoryId: categoryId,
        month: month,
        year: year,
      );

      if (budget == null || budget.amount == 0) {
        return 0.0;
      }

      final percentage = (spent / budget.amount) * 100;
      print('📊 Budget usage: ${percentage.toStringAsFixed(1)}% ($spent/${budget.amount})');
      return percentage;
    } catch (e) {
      print('❌ Error calculating budget usage: $e');
      return 0.0;
    }
  }
}