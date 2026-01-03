import 'package:flutter/material.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/screens/add_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryService _categoryService = CategoryService();
  String selectedType = 'expense'; // 'expense' ou 'income'
  List<Category> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Category> allCategories = await _categoryService.getCategoriesByType(selectedType);
      setState(() {
        categories = allCategories;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Obtenir l'icône de la catégorie
  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'car':
      case 'transport':
        return Icons.directions_car;
      case 'restaurant':
      case 'food':
        return Icons.restaurant;
      case 'health':
      case 'medical':
        return Icons.medical_services;
      case 'entertainment':
        return Icons.sports_esports;
      case 'school':
      case 'education':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_bag;
      case 'money':
      case 'salary':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }

  // Obtenir la couleur de la catégorie
  Color _getCategoryColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'teal':
        return Colors.teal;
      case 'pink':
        return Colors.pink;
      case 'amber':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  // Confirmer la suppression d'une catégorie
  Future<void> _confirmDelete(Category category) async {
    if (category.isPredefined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de supprimer une catégorie prédéfinie'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text('Voulez-vous vraiment supprimer "${category.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _categoryService.deleteCategory(category.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Catégorie supprimée'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadCategories();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sélecteur de type
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Dépenses'),
                  selected: selectedType == 'expense',
                  selectedColor: Colors.red.shade100,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedType = 'expense';
                      });
                      _loadCategories();
                    }
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Revenus'),
                  selected: selectedType == 'income',
                  selectedColor: Colors.green.shade100,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedType = 'income';
                      });
                      _loadCategories();
                    }
                  },
                ),
              ],
            ),
          ),

          // Liste des catégories
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : categories.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune catégorie',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          Category category = categories[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getCategoryColor(category.color).withOpacity(0.7),
                                child: Icon(
                                  _getCategoryIcon(category.icon),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                category.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                category.isPredefined ? 'Prédéfinie' : 'Personnalisée',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(category),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCategoryScreen(initialType: selectedType),
            ),
          );
          _loadCategories();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}