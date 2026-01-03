import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_manager/models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  CollectionReference get _categoriesCollection {
    if (userId == null) throw Exception('Utilisateur non connecté');
    return _firestore.collection('users').doc(userId).collection('categories');
  }

  /// Initialiser les catégories prédéfinies (ne crée QUE si aucune catégorie n'existe)
  Future<void> initializePredefinedCategories() async {
    try {
      // Catégories de dépenses
      List<Map<String, dynamic>> expenseCategories = [
        {'name': 'Alimentation', 'icon': 'food', 'color': 'orange', 'type': 'expense', 'isPredefined': true},
        {'name': 'Transport', 'icon': 'transport', 'color': 'blue', 'type': 'expense', 'isPredefined': true},
        {'name': 'Logement', 'icon': 'home', 'color': 'purple', 'type': 'expense', 'isPredefined': true},
        {'name': 'Santé', 'icon': 'health', 'color': 'pink', 'type': 'expense', 'isPredefined': true},
        {'name': 'Loisirs', 'icon': 'entertainment', 'color': 'green', 'type': 'expense', 'isPredefined': true},
        {'name': 'Shopping', 'icon': 'shopping', 'color': 'pink', 'type': 'expense', 'isPredefined': true},
        {'name': 'Éducation', 'icon': 'education', 'color': 'teal', 'type': 'expense', 'isPredefined': true},
        {'name': 'Autres', 'icon': 'category', 'color': 'amber', 'type': 'expense', 'isPredefined': true},
      ];

      // Catégories de revenus
      List<Map<String, dynamic>> incomeCategories = [
        {'name': 'Salaire', 'icon': 'salary', 'color': 'green', 'type': 'income', 'isPredefined': true},
        {'name': 'Freelance', 'icon': 'money', 'color': 'teal', 'type': 'income', 'isPredefined': true},
        {'name': 'Investissement', 'icon': 'money', 'color': 'blue', 'type': 'income', 'isPredefined': true},
        {'name': 'Autres', 'icon': 'money', 'color': 'amber', 'type': 'income', 'isPredefined': true},
      ];

      WriteBatch batch = _firestore.batch();

      for (var categoryData in [...expenseCategories, ...incomeCategories]) {
        DocumentReference docRef = _categoriesCollection.doc();
        batch.set(docRef, {
          ...categoryData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ ${expenseCategories.length + incomeCategories.length} catégories créées');
    } catch (e) {
      print('❌ Erreur création catégories: $e');
      rethrow;
    }
  }

  /// Vérifier si des catégories existent
  Future<bool> hasCategories() async {
    try {
      QuerySnapshot snapshot = await _categoriesCollection.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur vérification catégories: $e');
      return false;
    }
  }

  /// Ajouter une catégorie personnalisée
  Future<String> addCategory(Category category) async {
    try {
      DocumentReference docRef = await _categoriesCollection.add(category.toMap());
      return docRef.id;
    } catch (e) {
      print('❌ Erreur ajout catégorie: $e');
      rethrow;
    }
  }

  /// Supprimer une catégorie (seulement personnalisée)
  Future<void> deleteCategory(String categoryId) async {
    try {
      DocumentSnapshot doc = await _categoriesCollection.doc(categoryId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['isPredefined'] == true) {
          throw Exception('Impossible de supprimer une catégorie prédéfinie');
        }
        await _categoriesCollection.doc(categoryId).delete();
      }
    } catch (e) {
      print('❌ Erreur suppression catégorie: $e');
      rethrow;
    }
  }

  /// Récupérer toutes les catégories
  Future<List<Category>> getAllCategories() async {
    try {
      QuerySnapshot snapshot = await _categoriesCollection.orderBy('name').get();
      return snapshot.docs.map((doc) {
        return Category.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération catégories: $e');
      return [];
    }
  }

  /// Récupérer les catégories par type
  Future<List<Category>> getCategoriesByType(String type) async {
    try {
      QuerySnapshot snapshot = await _categoriesCollection
          .where('type', isEqualTo: type)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        return Category.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération par type: $e');
      return [];
    }
  }

  /// Récupérer une catégorie par ID
  Future<Category?> getCategoryById(String categoryId) async {
    try {
      DocumentSnapshot doc = await _categoriesCollection.doc(categoryId).get();
      if (doc.exists) {
        return Category.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération catégorie: $e');
      return null;
    }
  }

  /// Compter les catégories
  Future<int> getCategoriesCount() async {
    try {
      QuerySnapshot snapshot = await _categoriesCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Erreur comptage: $e');
      return 0;
    }
  }
}