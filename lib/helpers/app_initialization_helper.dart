import 'package:expense_manager/services/category_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppInitializationHelper {
  static final CategoryService _categoryService = CategoryService();

  /// Initialiser les catégories pour l'utilisateur connecté
  static Future<void> initializeUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Aucun utilisateur connecté');
        return;
      }

      print('🔄 Vérification des catégories pour ${user.email}');
      
      final hasCategories = await _categoryService.hasCategories();
      
      if (!hasCategories) {
        print('📂 Création des catégories prédéfinies...');
        await _categoryService.initializePredefinedCategories();
        print('✅ Catégories créées avec succès');
      } else {
        print('✅ Catégories déjà présentes');
      }
    } catch (e) {
      print('❌ Erreur initialisation: $e');
      rethrow;
    }
  }
}