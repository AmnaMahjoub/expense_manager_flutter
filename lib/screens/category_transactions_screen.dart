import 'package:flutter/material.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/screens/add_transaction_screen.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryTransactionsScreen> createState() => _CategoryTransactionsScreenState();
}

class _CategoryTransactionsScreenState extends State<CategoryTransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  
  List<TransactionModel> transactions = [];
  Category? category;
  bool isLoading = true;
  double totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Charger la catégorie
      Category? cat = await _categoryService.getCategoryById(widget.categoryId);
      
      // Charger les transactions
      List<TransactionModel> trans = await _transactionService.getTransactionsByCategory(widget.categoryId);
      
      // Calculer le total
      double total = 0;
      for (var t in trans) {
        total += t.amount;
      }

      setState(() {
        category = cat;
        transactions = trans;
        totalAmount = total;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
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

  // Supprimer une transaction
  Future<void> _deleteTransaction(TransactionModel transaction) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la transaction'),
        content: Text('Voulez-vous vraiment supprimer cette transaction de ${transaction.formattedAmount} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _transactionService.deleteTransaction(transaction.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction supprimée'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData();
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

  // Modifier une transaction
  void _editTransaction(TransactionModel transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transaction: transaction),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // En-tête avec informations de la catégorie
                if (category != null)
                  Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: _getCategoryColor(category!.color).withOpacity(0.7),
                            child: Icon(
                              _getCategoryIcon(category!.icon),
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            category!.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${transactions.length} transaction(s)',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${totalAmount.toStringAsFixed(2)} د.ت',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: category!.type == 'income' ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Liste des transactions
                Expanded(
                  child: transactions.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune transaction',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            TransactionModel transaction = transactions[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: category != null
                                      ? _getCategoryColor(category!.color).withOpacity(0.7)
                                      : Colors.blue,
                                  child: Text(
                                    '${transaction.date.day}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  transaction.formattedAmount,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(transaction.formattedDate),
                                trailing: PopupMenuButton(
                                  icon: const Icon(Icons.more_vert),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Modifier'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Supprimer', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editTransaction(transaction);
                                    } else if (value == 'delete') {
                                      _deleteTransaction(transaction);
                                    }
                                  },
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
              builder: (_) => AddTransactionScreen(
                categoryId: widget.categoryId,
              ),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}