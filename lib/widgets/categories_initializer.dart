import 'package:flutter/material.dart';
import 'package:expense_manager/services/category_service.dart';

/// Widget qui s'assure que les catégories prédéfinies sont initialisées
/// À placer dans votre arbre de widgets après l'authentification
class CategoriesInitializer extends StatefulWidget {
  final Widget child;

  const CategoriesInitializer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<CategoriesInitializer> createState() => _CategoriesInitializerState();
}

class _CategoriesInitializerState extends State<CategoriesInitializer> {
  final CategoryService _categoryService = CategoryService();
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCategories();
  }

  Future<void> _initializeCategories() async {
    try {
      print('🚀 Initializing categories...');
      await _categoryService.initializePredefinedCategories();
      
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
      
      print('✅ Categories initialization complete');
    } catch (e) {
      print('❌ Error during initialization: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Initialisation des catégories...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initializeCategories();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}