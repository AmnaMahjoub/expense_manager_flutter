import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_manager/helpers/app_initialization_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Récupérer l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Stream de l'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inscription avec initialisation automatique des catégories
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;

      if (user != null) {
        // Créer le document utilisateur
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'createdAt': Timestamp.now(),
        });

        // Initialiser les catégories prédéfinies
        await AppInitializationHelper.initializeUserData();
        print('✅ Utilisateur créé avec catégories prédéfinies');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur inscription: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Connexion avec vérification des catégories
  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;

      if (user != null) {
        // Vérifier et créer les catégories si manquantes
        await AppInitializationHelper.initializeUserData();
        print('✅ Utilisateur connecté');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur connexion: ${e.code}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Erreur inattendue: $e');
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    try {
      await _auth.signOut();
      print('✅ Déconnexion réussie');
    } catch (e) {
      print('❌ Erreur déconnexion: $e');
      rethrow;
    }
  }

  /// Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Email de réinitialisation envoyé');
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur réinitialisation: ${e.code}');
      throw _handleAuthException(e);
    }
  }

  /// Changer le mot de passe
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      // Ré-authentifier l'utilisateur
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      print('✅ Mot de passe modifié');
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur changement mot de passe: ${e.code}');
      throw _handleAuthException(e);
    }
  }

  /// Récupérer les données utilisateur
  Future<Map<String, dynamic>?> getUserData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        return doc.data();
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur récupération données: $e');
      return null;
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<void> updateUserProfile({
    String? displayName,
    Map<String, dynamic>? additionalData,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    try {
      // Mettre à jour Firebase Auth si displayName fourni
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }

      // Mettre à jour Firestore
      Map<String, dynamic> updateData = {
        'updatedAt': Timestamp.now(),
      };

      if (displayName != null) {
        updateData['displayName'] = displayName;
      }

      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await _db.collection('users').doc(user.uid).update(updateData);
      print('✅ Profil mis à jour');
    } catch (e) {
      print('❌ Erreur mise à jour profil: $e');
      rethrow;
    }
  }

  /// Supprimer le compte avec toutes ses données
  Future<void> deleteAccount(String password) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      // Ré-authentifier l'utilisateur
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Supprimer toutes les données utilisateur
      await _deleteUserData(user.uid);

      // Supprimer le document utilisateur
      await _db.collection('users').doc(user.uid).delete();

      // Supprimer le compte Firebase Auth
      await user.delete();
      print('✅ Compte supprimé');
    } on FirebaseAuthException catch (e) {
      print('❌ Erreur suppression compte: ${e.code}');
      throw _handleAuthException(e);
    }
  }

  /// Supprimer toutes les données utilisateur (transactions + catégories)
  Future<void> _deleteUserData(String uid) async {
    try {
      final batch = _db.batch();

      // Supprimer les transactions
      final transactionsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .get();

      for (var doc in transactionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Supprimer les catégories
      final categoriesSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('categories')
          .get();

      for (var doc in categoriesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Données utilisateur supprimées');
    } catch (e) {
      print('❌ Erreur suppression données: $e');
      rethrow;
    }
  }

  /// Obtenir les statistiques du compte
  Future<Map<String, int>> getAccountStats() async {
    final user = currentUser;
    if (user == null) return {};

    try {
      // Compter les transactions
      final transactionsSnapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .get();

      // Compter les catégories
      final categoriesSnapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get();

      return {
        'transactions': transactionsSnapshot.docs.length,
        'categories': categoriesSnapshot.docs.length,
      };
    } catch (e) {
      print('❌ Erreur statistiques: $e');
      return {};
    }
  }

  /// Gérer les exceptions d'authentification avec messages en français
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (minimum 6 caractères)';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé par un autre compte';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'invalid-email':
        return 'Adresse email invalide';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives. Veuillez réessayer plus tard';
      case 'operation-not-allowed':
        return 'Opération non autorisée';
      case 'network-request-failed':
        return 'Erreur de connexion. Vérifiez votre connexion internet';
      case 'invalid-credential':
        return 'Identifiants invalides';
      case 'account-exists-with-different-credential':
        return 'Un compte existe déjà avec cet email';
      case 'requires-recent-login':
        return 'Cette opération nécessite une connexion récente. Reconnectez-vous';
      default:
        return 'Erreur d\'authentification: ${e.message ?? e.code}';
    }
  }

  /// Vérifier si l'utilisateur est connecté
  bool isUserLoggedIn() {
    return currentUser != null;
  }

  /// Obtenir l'email de l'utilisateur connecté
  String? getUserEmail() {
    return currentUser?.email;
  }

  /// Obtenir l'UID de l'utilisateur connecté
  String? getUserId() {
    return currentUser?.uid;
  }
}