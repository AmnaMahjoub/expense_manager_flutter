import 'package:flutter/material.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction; // Pour la modification
  final String? categoryId; // Pour pré-sélectionner une catégorie

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
      // Mode modification
      _amountController.text = widget.transaction!.amount.toString();
      selectedType = widget.transaction!.type;
      selectedCategoryId = widget.transaction!.categoryId;
      selectedDate = widget.transaction!.date;
    } else if (widget.categoryId != null) {
      // Pré-sélection de catégorie
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
    setState(() {
      isLoading = true;
    });

    try {
      String type = selectedType == TransactionType.income ? 'income' : 'expense';
      List<Category> cats = await _categoryService.getCategoriesByType(type);
      
      setState(() {
        categories = cats;
        isLoading = false;
        
        // Si en mode édition et la catégorie actuelle n'est pas dans la liste, la charger
        if (isEditMode && selectedCategoryId != null) {
          bool categoryExists = cats.any((cat) => cat.id == selectedCategoryId);
          if (!categoryExists) {
            // La catégorie existe mais est d'un autre type, réinitialiser
            selectedCategoryId = cats.isNotEmpty ? cats.first.id : null;
          }
        } else if (selectedCategoryId == null && cats.isNotEmpty) {
          selectedCategoryId = cats.first.id;
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      if (selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez sélectionner une catégorie'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        double amount = double.parse(_amountController.text);
        
        if (isEditMode) {
          // Modification
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
                content: Text('Transaction modifiée avec succès'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          // Ajout
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
                content: Text('Transaction ajoutée avec succès'),
                backgroundColor: Colors.green,
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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'home':
        return Icons.home;
      case 'transport':
        return Icons.directions_car;
      case 'food':
        return Icons.restaurant;
      case 'health':
        return Icons.medical_services;
      case 'entertainment':
        return Icons.sports_esports;
      case 'education':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_bag;
      case 'salary':
      case 'money':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Modifier transaction' : 'Ajouter transaction'),
        centerTitle: true,
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
                    // Sélecteur de type
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Dépense'),
                            selected: selectedType == TransactionType.expense,
                            selectedColor: Colors.red.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  selectedType = TransactionType.expense;
                                  selectedCategoryId = null;
                                });
                                _loadCategories();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Revenu'),
                            selected: selectedType == TransactionType.income,
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  selectedType = TransactionType.income;
                                  selectedCategoryId = null;
                                });
                                _loadCategories();
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Montant
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Montant',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        suffixText: 'د.ت',
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
                    ),

                    const SizedBox(height: 20),

                    // Sélection de la date
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sélection de la catégorie
                    const Text(
                      'Catégorie',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (categories.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Aucune catégorie disponible pour ce type',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: categories.map((category) {
                          bool isSelected = selectedCategoryId == category.id;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedCategoryId = category.id;
                              });
                            },
                            child: Container(
                              width: 100,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? _getCategoryColor(category.color).withOpacity(0.3)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected 
                                      ? _getCategoryColor(category.color)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    _getCategoryIcon(category.icon),
                                    size: 30,
                                    color: _getCategoryColor(category.color),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    category.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 30),

                    // Bouton Enregistrer
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedType == TransactionType.expense 
                              ? Colors.red 
                              : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          isEditMode ? 'Modifier' : 'Enregistrer',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}