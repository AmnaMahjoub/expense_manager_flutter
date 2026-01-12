import 'package:flutter/material.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/screens/add_transaction_screen.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';

class CategoryTransactionsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const CategoryTransactionsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.periodStart,
    this.periodEnd,
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
    setState(() => isLoading = true);

    try {
      print('🔵 Loading data for category: ${widget.categoryId}');
      print('📅 Period: ${widget.periodStart} to ${widget.periodEnd}');
      
      // Charger la catégorie
      Category? cat = await _categoryService.getCategoryById(widget.categoryId);
      print('✅ Category loaded: ${cat?.name}');
      
      // Charger les transactions
      List<TransactionModel> allTransactions = await _transactionService.getTransactionsByCategory(widget.categoryId);
      print('📊 Total transactions in category: ${allTransactions.length}');
      
      // Filtrer par période si spécifiée
      List<TransactionModel> filteredTransactions = allTransactions;
      if (widget.periodStart != null && widget.periodEnd != null) {
        print('🔍 Filtering by period...');
        filteredTransactions = allTransactions.where((t) {
          final isInPeriod = t.date.isAfter(widget.periodStart!.subtract(const Duration(seconds: 1))) &&
                             t.date.isBefore(widget.periodEnd!.add(const Duration(seconds: 1)));
          
          if (isInPeriod) {
            print('  ✅ Transaction ${t.id}: ${t.amount} د.ت on ${t.formattedDate} - IN period');
          } else {
            print('  ❌ Transaction ${t.id}: ${t.amount} د.ت on ${t.formattedDate} - OUT of period');
          }
          
          return isInPeriod;
        }).toList();
        print('✅ Filtered transactions: ${filteredTransactions.length}');
      } else {
        print('ℹ️ No period filter, showing all transactions');
      }
      
      // Calculer le total
      double total = filteredTransactions.fold(0.0, (sum, t) => sum + t.amount);
      print('💰 Total amount: $total د.ت');

      setState(() {
        category = cat;
        transactions = filteredTransactions;
        totalAmount = total;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la transaction'),
        content: Text('Voulez-vous vraiment supprimer cette transaction de ${transaction.formattedAmount} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionService.deleteTransaction(transaction.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Transaction supprimée'),
              backgroundColor: AppTheme.incomeColor,
            ),
          );
          _loadData();
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

  void _editTransaction(TransactionModel transaction) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(transaction: transaction),
      ),
    );
    _loadData();
  }

  void _showTransactionOptions(TransactionModel transaction) {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mediumGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: const Icon(Icons.edit, color: AppTheme.primaryColor),
              ),
              title: const Text('Modifier'),
              subtitle: const Text('Modifier cette transaction'),
              onTap: () {
                Navigator.pop(context);
                _editTransaction(transaction);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.expenseColor.withOpacity(0.1),
                child: const Icon(Icons.delete, color: AppTheme.expenseColor),
              ),
              title: const Text('Supprimer', style: TextStyle(color: AppTheme.expenseColor)),
              subtitle: const Text('Supprimer cette transaction'),
              onTap: () {
                Navigator.pop(context);
                _deleteTransaction(transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // En-tête avec informations de la catégorie
                if (category != null) _buildHeader(),

                // Liste des transactions
                Expanded(
                  child: transactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(transactions[index]);
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
              builder: (_) => AddTransactionScreen(
                categoryId: widget.categoryId,
              ),
            ),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: category?.type == 'income' 
            ? AppTheme.incomeColor 
            : AppTheme.expenseColor,
      ),
    );
  }

  Widget _buildHeader() {
    final categoryColor = CategoryIconUtils.getColor(category!.color);
    final categoryIcon = CategoryIconUtils.getIcon(category!.icon);
    final isIncome = category!.type == 'income';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [categoryColor.withOpacity(0.7), categoryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              categoryIcon,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            category!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isIncome ? 'Revenu' : 'Dépense',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Afficher la période si filtrée
          if (widget.periodStart != null && widget.periodEnd != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatPeriod(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          Text(
            '${transactions.length} transaction${transactions.length > 1 ? 's' : ''}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${totalAmount.toStringAsFixed(2)} د.ت',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeriod() {
    if (widget.periodStart == null || widget.periodEnd == null) return '';
    
    final start = widget.periodStart!;
    final end = widget.periodEnd!;
    
    // Même jour
    if (start.day == end.day && start.month == end.month && start.year == end.year) {
      return "${start.day}/${start.month}/${start.year}";
    }
    
    // Même mois
    if (start.month == end.month && start.year == end.year) {
      return "${start.day}-${end.day}/${start.month}/${start.year}";
    }
    
    // Différents mois
    return "${start.day}/${start.month} - ${end.day}/${end.month}/${end.year}";
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final categoryColor = category != null 
        ? CategoryIconUtils.getColor(category!.color)
        : AppTheme.primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: categoryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showTransactionOptions(transaction),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date circle
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor.withOpacity(0.7), categoryColor],
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${transaction.date.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getMonthName(transaction.date.month),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.formattedAmount,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      transaction.formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.more_vert,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.receipt_long_outlined,
                size: 60,
                color: AppTheme.mediumGrey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucune transaction',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez votre première transaction\npour cette catégorie',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ["", "Jan", "Fév", "Mar", "Avr", "Mai", "Juin", 
                   "Jul", "Aoû", "Sep", "Oct", "Nov", "Déc"];
    return months[month];
  }
}