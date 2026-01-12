import 'package:flutter/material.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/screens/add_category_screen.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryService _categoryService = CategoryService();
  String selectedType = 'expense';
  List<Category> categories = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    print('🟢 CategoriesScreen: initState appelé');
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    print('🔵 Début du chargement des catégories pour type: $selectedType');
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      List<Category> allCategories = await _categoryService.getCategoriesByType(selectedType);
      print('✅ Catégories chargées: ${allCategories.length}');
      
      for (var cat in allCategories) {
        print('  - ${cat.name} (${cat.type}) - Prédéfinie: ${cat.isPredefined}');
      }
      
      setState(() {
        categories = allCategories;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur lors du chargement des catégories: $e');
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.isPredefined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Impossible de supprimer une catégorie prédéfinie'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la catégorie'),
        content: Text('Voulez-vous vraiment supprimer "${category.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _categoryService.deleteCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Catégorie supprimée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadCategories();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editCategory(Category category) async {
    print('🔧 Modification de la catégorie: ${category.name}');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCategoryScreen(
          category: category,
          initialType: selectedType,
        ),
      ),
    );
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Catégories'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Type selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeChip(
                      label: 'Dépenses',
                      type: 'expense',
                      color: AppTheme.expenseColor,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  Expanded(
                    child: _buildTypeChip(
                      label: 'Revenus',
                      type: 'income',
                      color: AppTheme.incomeColor,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Debug info
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  'Erreur: $errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),

          // Categories list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : categories.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _buildCategoryCard(category);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddCategoryScreen(initialType: selectedType),
            ),
          );
          _loadCategories();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: selectedType == 'expense' 
            ? AppTheme.expenseColor 
            : AppTheme.incomeColor,
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required String type,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = selectedType == type;
    
    return InkWell(
      onTap: () {
        print('🔄 Changement de type: $type');
        setState(() => selectedType = type);
        _loadCategories();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    final categoryColor = CategoryIconUtils.getColor(category.color);
    final categoryIcon = CategoryIconUtils.getIcon(category.icon);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: category.isPredefined 
              ? categoryColor.withOpacity(0.3) 
              : Colors.transparent,
          width: category.isPredefined ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Afficher un menu d'options
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.edit, color: AppTheme.primaryColor),
                    title: const Text('Modifier'),
                    onTap: () {
                      Navigator.pop(context);
                      _editCategory(category);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete,
                      color: category.isPredefined 
                          ? Colors.grey 
                          : Colors.red,
                    ),
                    title: Text(
                      'Supprimer',
                      style: TextStyle(
                        color: category.isPredefined 
                            ? Colors.grey 
                            : Colors.red,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteCategory(category);
                    },
                  ),
                ],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      categoryColor.withOpacity(0.7),
                      categoryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  categoryIcon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Category Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          category.isPredefined 
                              ? Icons.lock_outline 
                              : Icons.edit_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category.isPredefined ? 'Prédéfinie' : 'Personnalisée',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.lightGrey,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.category_outlined,
              size: 60,
              color: AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune catégorie',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre première catégorie ${selectedType == 'expense' ? 'de dépense' : 'de revenu'}',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCategoryScreen(initialType: selectedType),
                ),
              );
              _loadCategories();
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une catégorie'),
          ),
        ],
      ),
    );
  }
}