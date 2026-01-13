import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/utils/budget_checker.dart'; // ← AJOUT
import 'package:expense_manager/services/category_service.dart'; // ← AJOUT

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BudgetChecker _budgetChecker = BudgetChecker(); // ← AJOUT
  final CategoryService _categoryService = CategoryService(); // ← AJOUT

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _transactionsCollection {
    if (_userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('transactions');
  }

  // Add transaction - AVEC VÉRIFICATION DU BUDGET
  Future<String> addTransaction(TransactionModel transaction) async {
    try {
      print('💰 Adding transaction: ${transaction.amount} د.ت for category ${transaction.categoryId}');
      
      final docRef = await _transactionsCollection.add(transaction.toMap());
      print('✅ Transaction added: ${docRef.id}');
      
      // ⚠️ VÉRIFIER LE BUDGET APRÈS AJOUT (uniquement pour les dépenses)
      if (transaction.type == TransactionType.expense) {
        print('🔍 Checking budget after adding transaction...');
        await _checkBudgetAfterTransaction(transaction.categoryId);
      }
      
      return docRef.id;
    } catch (e) {
      print('Error adding transaction: $e');
      throw 'Erreur lors de l\'ajout de la transaction';
    }
  }

  // Update transaction - AVEC VÉRIFICATION DU BUDGET
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      print('✏️ Updating transaction: ${transaction.id}');
      
      await _transactionsCollection.doc(transaction.id).update(transaction.toMap());
      print('✅ Transaction updated');
      
      // ⚠️ VÉRIFIER LE BUDGET APRÈS MODIFICATION (uniquement pour les dépenses)
      if (transaction.type == TransactionType.expense) {
        print('🔍 Checking budget after updating transaction...');
        await _checkBudgetAfterTransaction(transaction.categoryId);
      }
    } catch (e) {
      print('Error updating transaction: $e');
      throw 'Erreur lors de la modification de la transaction';
    }
  }

  // Delete transaction - AVEC VÉRIFICATION DU BUDGET
  Future<void> deleteTransaction(String transactionId) async {
    try {
      print('🗑️ Deleting transaction: $transactionId');
      
      // Récupérer la transaction avant de la supprimer pour connaître la catégorie
      final doc = await _transactionsCollection.doc(transactionId).get();
      final data = doc.data() as Map<String, dynamic>?;
      final categoryId = data?['categoryId'] as String?;
      final type = data?['type'] as String?;
      
      await _transactionsCollection.doc(transactionId).delete();
      print('✅ Transaction deleted');
      
      // ⚠️ VÉRIFIER LE BUDGET APRÈS SUPPRESSION (uniquement pour les dépenses)
      if (categoryId != null && type == 'expense') {
        print('🔍 Checking budget after deleting transaction...');
        await _checkBudgetAfterTransaction(categoryId);
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      throw 'Erreur lors de la suppression de la transaction';
    }
  }

  // ⚠️ NOUVELLE MÉTHODE: Vérifier le budget après une transaction
  Future<void> _checkBudgetAfterTransaction(String categoryId) async {
    try {
      // Charger la catégorie
      final category = await _categoryService.getCategoryById(categoryId);
      
      if (category == null) {
        print('⚠️ Category not found: $categoryId');
        return;
      }
      
      // Vérifier le budget
      await _budgetChecker.checkBudgetForCategory(
        categoryId: categoryId,
        category: category,
      );
      
      print('✅ Budget check completed for category: ${category.name}');
    } catch (e) {
      print('❌ Error checking budget after transaction: $e');
      // Ne pas lancer d'erreur pour ne pas bloquer l'ajout de transaction
    }
  }

  // Get transaction by ID
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    try {
      final doc = await _transactionsCollection.doc(transactionId).get();
      
      if (doc.exists) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting transaction: $e');
      return null;
    }
  }

  // Get all transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      final snapshot = await _transactionsCollection
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting all transactions: $e');
      return [];
    }
  }

  // Get transactions by type
  Future<List<TransactionModel>> getTransactionsByType(TransactionType type) async {
    try {
      final typeString = type == TransactionType.income ? 'income' : 'expense';
      
      final snapshot = await _transactionsCollection
          .where('type', isEqualTo: typeString)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting transactions by type: $e');
      return [];
    }
  }

  // Get transactions by category - SANS INDEX
  Future<List<TransactionModel>> getTransactionsByCategory(String categoryId) async {
    try {
      print('📥 Getting transactions for category: $categoryId (sans index)');
      
      // Récupérer sans orderBy pour éviter l'index
      final snapshot = await _transactionsCollection
          .where('categoryId', isEqualTo: categoryId)
          .get();

      print('✅ Found ${snapshot.docs.length} transactions');
      
      final transactions = snapshot.docs
          .map((doc) {
            try {
              return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            } catch (e) {
              print('⚠️ Error parsing transaction: $e');
              return null;
            }
          })
          .whereType<TransactionModel>()
          .toList();

      // Trier manuellement par date
      transactions.sort((a, b) => b.date.compareTo(a.date));

      return transactions;
    } catch (e) {
      print('Error getting transactions by category: $e');
      return [];
    }
  }

  // Get transactions by type and period - VERSION OPTIMISÉE
  Future<List<TransactionModel>> getTransactionsByTypeAndPeriod({
    required TransactionType type,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      print('📥 Getting transactions: type=$type, start=$start, end=$end');
      final typeString = type == TransactionType.income ? 'income' : 'expense';
      
      // Essayer d'abord avec l'index
      try {
        final snapshot = await _transactionsCollection
            .where('type', isEqualTo: typeString)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .orderBy('date', descending: true)
            .get();

        print('✅ Found ${snapshot.docs.length} transactions (avec index)');
        
        return snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      } catch (indexError) {
        // Fallback: filtrage en mémoire si l'index n'existe pas
        print('⚠️ Index not available, filtering in memory: $indexError');
        
        final snapshot = await _transactionsCollection.get();
        
        final transactions = snapshot.docs
            .map((doc) {
              try {
                return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              } catch (e) {
                print('⚠️ Error parsing transaction ${doc.id}: $e');
                return null;
              }
            })
            .whereType<TransactionModel>()
            .where((transaction) {
              if (transaction.type != type) return false;
              
              final date = transaction.date;
              return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
                     date.isBefore(end.add(const Duration(seconds: 1)));
            })
            .toList();

        transactions.sort((a, b) => b.date.compareTo(a.date));

        print('✅ Found ${transactions.length} transactions (filtrage mémoire)');
        
        return transactions;
      }
    } catch (e) {
      print('❌ Error getting transactions by type and period: $e');
      return [];
    }
  }

  // Get transactions by period
  Future<List<TransactionModel>> getTransactionsByPeriod({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final snapshot = await _transactionsCollection
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting transactions by period: $e');
      return [];
    }
  }

  // Get total amount by type and period
  Future<double> getTotalByTypeAndPeriod({
    required TransactionType type,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final transactions = await getTransactionsByTypeAndPeriod(
        type: type,
        start: start,
        end: end,
      );

      return transactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    } catch (e) {
      print('Error calculating total: $e');
      return 0.0;
    }
  }

  // Get balance (income - expense) for period
  Future<double> getBalanceForPeriod({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final income = await getTotalByTypeAndPeriod(
        type: TransactionType.income,
        start: start,
        end: end,
      );

      final expense = await getTotalByTypeAndPeriod(
        type: TransactionType.expense,
        start: start,
        end: end,
      );

      return income - expense;
    } catch (e) {
      print('Error calculating balance: $e');
      return 0.0;
    }
  }

  // Get transactions count
  Future<int> getTransactionsCount() async {
    try {
      final snapshot = await _transactionsCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting transactions count: $e');
      return 0;
    }
  }

  // Stream of transactions
  Stream<List<TransactionModel>> getTransactionsStream() {
    return _transactionsCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Delete all transactions by category
  Future<void> deleteTransactionsByCategory(String categoryId) async {
    try {
      final snapshot = await _transactionsCollection
          .where('categoryId', isEqualTo: categoryId)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting transactions by category: $e');
      throw 'Erreur lors de la suppression des transactions';
    }
  }

  // Get recent transactions - VERSION OPTIMISÉE
  Future<List<TransactionModel>> getRecentTransactions({int limit = 10}) async {
    try {
      print('📥 Getting recent transactions (limit: $limit)');
      
      try {
        final snapshot = await _transactionsCollection
            .orderBy('date', descending: true)
            .limit(limit)
            .get();

        print('✅ Found ${snapshot.docs.length} recent transactions');
        
        return snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      } catch (e) {
        print('⚠️ Using fallback method: $e');
        
        final snapshot = await _transactionsCollection.get();
        
        final transactions = snapshot.docs
            .map((doc) {
              try {
                return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              } catch (e) {
                print('⚠️ Error parsing transaction ${doc.id}: $e');
                return null;
              }
            })
            .whereType<TransactionModel>()
            .toList();

        transactions.sort((a, b) => b.date.compareTo(a.date));
        final limited = transactions.take(limit).toList();

        print('✅ Found ${limited.length} recent transactions (filtrage mémoire)');
        
        return limited;
      }
    } catch (e) {
      print('❌ Error getting recent transactions: $e');
      return [];
    }
  }
}