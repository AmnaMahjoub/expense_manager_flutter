import 'package:flutter/material.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';
import 'package:expense_manager/widgets/custom_button.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final String? categoryId;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.categoryId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();

  TransactionType selectedType = TransactionType.expense;
  String? selectedCategoryId;
  DateTime selectedDate = DateTime.now();
  List<Category> categories = [];
  bool isLoading = true;
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    isEditMode = widget.transaction != null;
    
    if (isEditMode) {
      _amountController.text = widget.transaction!.amount.toString();
      selectedType = widget.transaction!.type;
      selectedCategoryId = widget.transaction!.categoryId;
      selectedDate = widget.transaction!.date;
    } else if (widget.categoryId != null) {
      selectedCategoryId = widget.categoryId;
    }
    
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => isLoading = true);

    try {
      String type = selectedType == TransactionType.income ? 'income' : 'expense';
      List<Category> cats = await _categoryService.getCategoriesByType(type);
      
      setState(() {
        categories = cats;
        isLoading = false;
        
        if (isEditMode && selectedCategoryId != null) {
          bool categoryExists = cats.any((cat) => cat.id == selectedCategoryId);
          if (!categoryExists) {
            selectedCategoryId = cats.isNotEmpty ? cats.first.id : null;
          }
        } else if (selectedCategoryId == null && cats.isNotEmpty) {
          selectedCategoryId = cats.first.id;
        }
      });
    } catch (e) {
      print('Erreur: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: selectedType == TransactionType.expense 
                  ? AppTheme.expenseColor 
                  : AppTheme.incomeColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      if (selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une catégorie'),
            backgroundColor: AppTheme.expenseColor,
          ),
        );
        return;
      }

      try {
        double amount = double.parse(_amountController.text);
        
        if (isEditMode) {
          TransactionModel updatedTransaction = widget.transaction!.copyWith(
            amount: amount,
            categoryId: selectedCategoryId!,
            type: selectedType,
            date: selectedDate,
          );
          
          await _transactionService.updateTransaction(updatedTransaction);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Transaction modifiée avec succès'),
                backgroundColor: AppTheme.incomeColor,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          TransactionModel newTransaction = TransactionModel(
            id: '',
            amount: amount,
            categoryId: selectedCategoryId!,
            type: selectedType,
            date: selectedDate,
            createdAt: DateTime.now(),
          );
          
          await _transactionService.addTransaction(newTransaction);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Transaction ajoutée avec succès'),
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
              content: Text('❌ Erreur: $e'),
              backgroundColor: AppTheme.expenseColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = selectedType == TransactionType.expense;
    final themeColor = isExpense ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isEditMode ? 'Modifier transaction' : 'Ajouter transaction'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeSelector(themeColor),
                    const SizedBox(height: 20),
                    _buildAmountField(themeColor),
                    const SizedBox(height: 20),
                    _buildDateSelector(themeColor),
                    const SizedBox(height: 20),
                    _buildCategorySelector(),
                    const SizedBox(height: 30),
                    _buildSaveButton(themeColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeSelector(Color themeColor) {
    return Container(
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
            child: _buildTypeOption(
              label: 'Dépense',
              type: TransactionType.expense,
              icon: Icons.arrow_downward,
              color: AppTheme.expenseColor,
            ),
          ),
          Expanded(
            child: _buildTypeOption(
              label: 'Revenu',
              type: TransactionType.income,
              icon: Icons.arrow_upward,
              color: AppTheme.incomeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String label,
    required TransactionType type,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = selectedType == type;

    return InkWell(
      onTap: () {
        setState(() {
          selectedType = type;
          selectedCategoryId = null;
        });
        _loadCategories();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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

  Widget _buildAmountField(Color themeColor) {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Montant',
        prefixIcon: Icon(Icons.attach_money, color: themeColor),
        suffixText: 'د.ت',
        suffixStyle: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Veuillez entrer un montant';
        }
        if (double.tryParse(value) == null) {
          return 'Montant invalide';
        }
        if (double.parse(value) <= 0) {
          return 'Le montant doit être positif';
        }
        return null;
      },
    );
  }

  Widget _buildDateSelector(Color themeColor) {
    return InkWell(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.lightGrey),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: themeColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catégorie',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Aucune catégorie disponible pour ce type',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: categories.map((category) {
              bool isSelected = selectedCategoryId == category.id;
              final categoryColor = CategoryIconUtils.getColor(category.color);
              final categoryIcon = CategoryIconUtils.getIcon(category.icon);
              
              return InkWell(
                onTap: () => setState(() => selectedCategoryId = category.id),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? categoryColor.withOpacity(0.2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? categoryColor : AppTheme.lightGrey,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ] : [],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        categoryIcon,
                        size: 32,
                        color: categoryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSaveButton(Color themeColor) {
    return CustomButton(
      text: isEditMode ? 'Modifier' : 'Enregistrer',
      onPressed: _saveTransaction,
      gradient: selectedType == TransactionType.expense 
          ? AppTheme.expenseGradient 
          : AppTheme.incomeGradient,
      icon: isEditMode ? Icons.check : Icons.add,
    );
  }
}