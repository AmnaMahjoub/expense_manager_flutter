import 'package:flutter/material.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';
import 'package:expense_manager/widgets/custom_button.dart';

class AddCategoryScreen extends StatefulWidget {
  final String initialType;
  final Category? category; // Pour la modification

  const AddCategoryScreen({
    super.key,
    this.initialType = 'expense',
    this.category,
  });

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final CategoryService _categoryService = CategoryService();

  String selectedType = 'expense';
  String selectedIcon = 'category';
  String selectedColor = 'blue';
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
    
    if (widget.category != null) {
      isEditMode = true;
      _nameController.text = widget.category!.name;
      selectedType = widget.category!.type;
      selectedIcon = widget.category!.icon;
      selectedColor = widget.category!.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (isEditMode) {
          // Vérifier si c'est une catégorie prédéfinie
          if (widget.category!.isPredefined) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Impossible de modifier une catégorie prédéfinie'),
                backgroundColor: AppTheme.expenseColor,
              ),
            );
            return;
          }

          // Modifier la catégorie
          Category updatedCategory = Category(
            id: widget.category!.id,
            name: _nameController.text.trim(),
            icon: selectedIcon,
            color: selectedColor,
            type: selectedType,
            isPredefined: false,
          );

          await _categoryService.updateCategory(updatedCategory);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Catégorie modifiée avec succès'),
                backgroundColor: AppTheme.incomeColor,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          // Ajouter une nouvelle catégorie
          Category newCategory = Category(
            id: '',
            name: _nameController.text.trim(),
            icon: selectedIcon,
            color: selectedColor,
            type: selectedType,
            isPredefined: false,
          );

          await _categoryService.addCategory(newCategory);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Catégorie ajoutée avec succès'),
                backgroundColor: AppTheme.incomeColor,
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppTheme.expenseColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = selectedType == 'expense';
    final themeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isEditMode ? 'Modifier la catégorie' : 'Ajouter une catégorie'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview Card
              _buildPreviewCard(themeColor),
              
              const SizedBox(height: 24),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie',
                  prefixIcon: Icon(Icons.label_outline),
                  hintText: 'Ex: Restaurant, Shopping...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
                onChanged: (value) => setState(() {}),
              ),

              const SizedBox(height: 24),

              // Type Selector
              const Text(
                'Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      label: 'Dépense',
                      type: 'expense',
                      icon: Icons.arrow_downward,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeOption(
                      label: 'Revenu',
                      type: 'income',
                      icon: Icons.arrow_upward,
                      color: AppTheme.incomeColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Icon Selector
              const Text(
                'Icône',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildIconSelector(),

              const SizedBox(height: 24),

              // Color Selector
              const Text(
                'Couleur',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildColorSelector(),

              const SizedBox(height: 32),

              // Save Button
              CustomButton(
                text: isEditMode ? 'Modifier' : 'Enregistrer',
                onPressed: _saveCategory,
                gradient: isExpense 
                    ? AppTheme.expenseGradient 
                    : AppTheme.incomeGradient,
                icon: isEditMode ? Icons.check : Icons.add,
              ),

              if (isEditMode && widget.category!.isPredefined) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.mediumGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.mediumGrey.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.mediumGrey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catégorie prédéfinie - Modification désactivée',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(Color themeColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [themeColor.withOpacity(0.1), themeColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CategoryIconUtils.getColor(selectedColor).withOpacity(0.7),
                    CategoryIconUtils.getColor(selectedColor),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: CategoryIconUtils.getColor(selectedColor).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                CategoryIconUtils.getIcon(selectedIcon),
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aperçu',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nameController.text.isEmpty 
                        ? 'Nom de la catégorie' 
                        : _nameController.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedType == 'expense' ? 'Dépense' : 'Revenu',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String label,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedType == type;

    return InkWell(
      onTap: () => setState(() => selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.lightGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSelector() {
    final icons = selectedType == 'expense'
        ? CategoryIconUtils.getPopularExpenseIcons()
        : CategoryIconUtils.getPopularIncomeIcons();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: icons.map((entry) {
        final isSelected = selectedIcon == entry.key;
        return InkWell(
          onTap: () => setState(() => selectedIcon = entry.key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected 
                  ? CategoryIconUtils.getColor(selectedColor).withOpacity(0.2)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? CategoryIconUtils.getColor(selectedColor)
                    : AppTheme.lightGrey,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(
              entry.value,
              size: 28,
              color: isSelected 
                  ? CategoryIconUtils.getColor(selectedColor)
                  : AppTheme.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector() {
    final colors = CategoryIconUtils.getAvailableColors();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((entry) {
        final isSelected = selectedColor == entry.key;
        return InkWell(
          onTap: () => setState(() => selectedColor = entry.key),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: entry.value,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: entry.value.withOpacity(0.4),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
                : null,
          ),
        );
      }).toList(),
    );
  }
}