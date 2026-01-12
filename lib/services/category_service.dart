import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:expense_manager/models/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference get _categoriesCollection {
    if (_userId == null) {
      print('❌ User not authenticated');
      throw Exception('User not authenticated');
    }
    print('📂 Collection path: users/$_userId/categories');
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('categories');
  }

  // Initialize predefined categories for new users
  Future<void> initializePredefinedCategories() async {
    try {
      print('🔵 Initializing predefined categories...');
      print('👤 Current user: $_userId');

      if (_userId == null) {
        print('❌ No user logged in');
        throw Exception('User not authenticated');
      }

      // Check if categories already exist
      final existingCategories = await _categoriesCollection.limit(1).get();
      
      if (existingCategories.docs.isNotEmpty) {
        print('✅ Categories already initialized (${existingCategories.docs.length} found)');
        return;
      }

      print('📂 Loading JSON file...');
      // Load predefined categories from JSON
      final String jsonString = await rootBundle.loadString('assets/data/predefined_categories.json');
      print('✅ JSON loaded (${jsonString.length} chars)');
      
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      print('📋 JSON structure: ${jsonData.keys.toList()}');

      // Add expense categories
      if (jsonData.containsKey('expense_categories')) {
        final expenseCategories = jsonData['expense_categories'] as List;
        print('💰 Adding ${expenseCategories.length} expense categories...');
        
        for (var categoryData in expenseCategories) {
          await _categoriesCollection.add({
            'name': categoryData['name'],
            'icon': categoryData['icon'],
            'color': categoryData['color'],
            'type': 'expense',
            'isPredefined': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('  ✅ Added: ${categoryData['name']}');
        }
      } else {
        print('⚠️ No expense_categories in JSON');
      }

      // Add income categories
      if (jsonData.containsKey('income_categories')) {
        final incomeCategories = jsonData['income_categories'] as List;
        print('💵 Adding ${incomeCategories.length} income categories...');
        
        for (var categoryData in incomeCategories) {
          await _categoriesCollection.add({
            'name': categoryData['name'],
            'icon': categoryData['icon'],
            'color': categoryData['color'],
            'type': 'income',
            'isPredefined': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('  ✅ Added: ${categoryData['name']}');
        }
      } else {
        print('⚠️ No income_categories in JSON');
      }

      print('🎉 Predefined categories initialized successfully');
    } catch (e) {
      print('❌ Error initializing predefined categories: $e');
      if (e.toString().contains('Unable to load asset')) {
        print('⚠️ Make sure assets/data/predefined_categories.json exists');
        print('⚠️ And is declared in pubspec.yaml under assets:');
      }
      rethrow;
    }
  }

  // Get all categories
  Future<List<Category>> getAllCategories() async {
    try {
      print('📥 Getting all categories for user: $_userId');
      
      // Récupérer toutes sans orderBy pour éviter le besoin d'index
      final snapshot = await _categoriesCollection.get();

      print('✅ Found ${snapshot.docs.length} categories');
      
      final categories = snapshot.docs
          .map((doc) {
            print('  - ${doc.id}: ${doc.data()}');
            return Category.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          })
          .toList();

      // Trier en mémoire
      categories.sort((a, b) => a.name.compareTo(b.name));

      return categories;
    } catch (e) {
      print('❌ Error getting all categories: $e');
      return [];
    }
  }

  // Get categories by type - VERSION OPTIMISÉE
  Future<List<Category>> getCategoriesByType(String type) async {
    try {
      print('📥 Getting categories by type: $type for user: $_userId');
      
      if (_userId == null) {
        print('❌ No user authenticated');
        return [];
      }

      // Stratégie: essayer d'abord avec l'index, sinon fallback sur filtrage en mémoire
      try {
        final snapshot = await _categoriesCollection
            .where('type', isEqualTo: type)
            .orderBy('name')
            .get();

        print('✅ Found ${snapshot.docs.length} categories of type $type (avec index)');
        
        return snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              print('  - ${doc.id}: ${data['name']} (${data['type']}) - Predefined: ${data['isPredefined']}');
              return Category.fromMap(data, doc.id);
            })
            .toList();
      } catch (indexError) {
        // Si l'index n'existe pas encore, fallback sur filtrage en mémoire
        print('⚠️ Index not available, filtering in memory: $indexError');
        
        final snapshot = await _categoriesCollection.get();
        
        final categories = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Category.fromMap(data, doc.id);
            })
            .where((category) => category.type == type)
            .toList();

        // Trier par nom en mémoire
        categories.sort((a, b) => a.name.compareTo(b.name));

        print('✅ Found ${categories.length} categories of type $type (filtrage mémoire)');
        
        for (var cat in categories) {
          print('  - ${cat.id}: ${cat.name} (${cat.type}) - Predefined: ${cat.isPredefined}');
        }

        return categories;
      }
    } catch (e) {
      print('❌ Error getting categories by type: $e');
      return [];
    }
  }

  // Get category by ID
  Future<Category?> getCategoryById(String categoryId) async {
    try {
      print('📥 Getting category by ID: $categoryId');
      
      final doc = await _categoriesCollection.doc(categoryId).get();
      
      if (doc.exists) {
        print('✅ Category found: ${doc.data()}');
        return Category.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      
      print('⚠️ Category not found');
      return null;
    } catch (e) {
      print('❌ Error getting category by ID: $e');
      return null;
    }
  }

  // Add new category
  Future<String> addCategory(Category category) async {
    try {
      print('➕ Adding category: ${category.name}');
      
      final docRef = await _categoriesCollection.add({
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'type': category.type,
        'isPredefined': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Category added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding category: $e');
      throw 'Erreur lors de l\'ajout de la catégorie';
    }
  }

  // Update category
  Future<void> updateCategory(Category category) async {
    try {
      print('🔧 Updating category: ${category.id}');
      
      await _categoriesCollection.doc(category.id).update({
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
        'type': category.type,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Category updated');
    } catch (e) {
      print('❌ Error updating category: $e');
      throw 'Erreur lors de la modification de la catégorie';
    }
  }

  // Delete category
  Future<void> deleteCategory(String categoryId) async {
    try {
      print('🗑️ Deleting category: $categoryId');
      
      // Check if category is predefined
      final doc = await _categoriesCollection.doc(categoryId).get();
      final data = doc.data() as Map<String, dynamic>?;
      
      if (data?['isPredefined'] == true) {
        print('❌ Cannot delete predefined category');
        throw 'Impossible de supprimer une catégorie prédéfinie';
      }

      // Check if category has transactions
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .where('categoryId', isEqualTo: categoryId)
          .limit(1)
          .get();

      if (transactionsSnapshot.docs.isNotEmpty) {
        print('❌ Category has transactions');
        throw 'Impossible de supprimer une catégorie avec des transactions';
      }

      await _categoriesCollection.doc(categoryId).delete();
      print('✅ Category deleted');
    } catch (e) {
      print('❌ Error deleting category: $e');
      rethrow;
    }
  }

  // Get categories count by type
  Future<int> getCategoriesCount(String type) async {
    try {
      final snapshot = await _categoriesCollection
          .where('type', isEqualTo: type)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting categories count: $e');
      return 0;
    }
  }

  // Stream of categories - VERSION OPTIMISÉE
  Stream<List<Category>> getCategoriesStream(String type) {
    print('🔄 Creating stream for type: $type');
    
    // Essayer d'abord avec l'index
    try {
      return _categoriesCollection
          .where('type', isEqualTo: type)
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
            print('📡 Stream update: ${snapshot.docs.length} docs (avec index)');
            return snapshot.docs
                .map((doc) => Category.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                .toList();
          });
    } catch (e) {
      // Fallback: stream sans orderBy, puis tri en mémoire
      print('⚠️ Using fallback stream (sans index)');
      return _categoriesCollection
          .snapshots()
          .map((snapshot) {
            final categories = snapshot.docs
                .map((doc) => Category.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                .where((category) => category.type == type)
                .toList();
            
            categories.sort((a, b) => a.name.compareTo(b.name));
            
            print('📡 Stream update: ${categories.length} docs (filtrage mémoire)');
            return categories;
          });
    }
  }

  // Check if category name exists
  Future<bool> categoryNameExists(String name, String type, {String? excludeId}) async {
    try {
      // Simple query sans index composite
      final snapshot = await _categoriesCollection
          .where('name', isEqualTo: name)
          .get();
      
      // Filtrer par type en mémoire
      final matches = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['type'] != type) return false;
        if (excludeId != null && doc.id == excludeId) return false;
        return true;
      });
      
      return matches.isNotEmpty;
    } catch (e) {
      print('❌ Error checking category name: $e');
      return false;
    }
  }
}