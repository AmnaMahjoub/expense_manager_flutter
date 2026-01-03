import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_manager/models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  // Collection reference pour les transactions de l'utilisateur
  CollectionReference get _transactionsCollection {
    if (userId == null) throw Exception('Utilisateur non connecté');
    return _firestore.collection('users').doc(userId).collection('transactions');
  }

  // Ajouter une transaction
  Future<String> addTransaction(TransactionModel transaction) async {
    try {
      DocumentReference docRef = await _transactionsCollection.add(transaction.toMap());
      return docRef.id;
    } catch (e) {
      print('Erreur lors de l\'ajout de la transaction: $e');
      rethrow;
    }
  }

  // Mettre à jour une transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      await _transactionsCollection.doc(transaction.id).update(transaction.toMap());
    } catch (e) {
      print('Erreur lors de la mise à jour de la transaction: $e');
      rethrow;
    }
  }

  // Supprimer une transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _transactionsCollection.doc(transactionId).delete();
    } catch (e) {
      print('Erreur lors de la suppression de la transaction: $e');
      rethrow;
    }
  }

  // Récupérer toutes les transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      QuerySnapshot snapshot = await _transactionsCollection.orderBy('date', descending: true).get();
      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      return [];
    }
  }

  // Récupérer les transactions par type et période
  Future<List<TransactionModel>> getTransactionsByTypeAndPeriod({
    required TransactionType type,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      QuerySnapshot snapshot = await _transactionsCollection
          .where('type', isEqualTo: type == TransactionType.income ? 'income' : 'expense')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions par type et période: $e');
      return [];
    }
  }

  // Récupérer les transactions par catégorie
  Future<List<TransactionModel>> getTransactionsByCategory(String categoryId) async {
    try {
      QuerySnapshot snapshot = await _transactionsCollection
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions par catégorie: $e');
      return [];
    }
  }

  // Récupérer les transactions par catégorie et période
  Future<List<TransactionModel>> getTransactionsByCategoryAndPeriod({
    required String categoryId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      QuerySnapshot snapshot = await _transactionsCollection
          .where('categoryId', isEqualTo: categoryId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Erreur lors de la récupération des transactions: $e');
      return [];
    }
  }

  // Calculer le solde total
  Future<double> calculateBalance() async {
    try {
      List<TransactionModel> transactions = await getAllTransactions();
      double balance = 0;

      for (var transaction in transactions) {
        if (transaction.type == TransactionType.income) {
          balance += transaction.amount;
        } else {
          balance -= transaction.amount;
        }
      }

      return balance;
    } catch (e) {
      print('Erreur lors du calcul du solde: $e');
      return 0;
    }
  }

  // Stream pour les transactions en temps réel
  Stream<List<TransactionModel>> getTransactionsStream() {
    try {
      return _transactionsCollection
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Erreur lors du stream des transactions: $e');
      return Stream.value([]);
    }
  }
}