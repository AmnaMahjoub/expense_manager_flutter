import 'dart:async';

import 'package:flutter/material.dart';
import 'package:expense_manager/models/budget_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/budget_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/utils/budget_checker.dart';
import 'package:expense_manager/screens/set_budget_screen.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  final CategoryService _categoryService = CategoryService();
  final BudgetChecker _budgetChecker = BudgetChecker();

  List<Budget> budgets = [];
  Map<String, Category> categories = {};
  Map<String, double> spentAmounts = {};
  bool isLoading = true;
  Timer? _autoRefreshTimer;
  StreamSubscription? _budgetSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupBudgetStream(); // ✅ Utiliser Stream au lieu de Timer
    _startAutoRefresh(); // ✅ Rafraîchir toutes les minutes
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _budgetSubscription?.cancel();
    super.dispose();
  }

  // ✅ NOUVEAU: Écouter les changements en temps réel via Stream
  void _setupBudgetStream() {
    _budgetSubscription = _budgetService.getCurrentMonthBudgetsStream().listen(
      (updatedBudgets) async {
        if (!mounted) return;
        
        print('📡 Budget stream update: ${updatedBudgets.length} budgets');
        
        // Calculer les montants dépensés pour chaque budget
        final Map<String, double> spent = {};
        for (var budget in updatedBudgets) {
          final amount = await _budgetChecker.getCategorySpent(
            categoryId: budget.categoryId,
          );
          spent[budget.categoryId] = amount;
        }

        if (mounted) {
          setState(() {
            budgets = updatedBudgets;
            spentAmounts = spent;
          });
        }
      },
      onError: (error) {
        print('❌ Error in budget stream: $error');
      },
    );
  }

  // ✅ Rafraîchissement automatique toutes les minutes
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        print('🔄 Auto-refresh budgets (every 1 minute)');
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    // ✅ Ne mettre isLoading = true que si c'est le premier chargement
    if (budgets.isEmpty) {
      setState(() => isLoading = true);
    }

    try {
      // Charger les catégories
      final cats = await _categoryService.getAllCategories();
      if (!mounted) return;
      
      categories = {for (var cat in cats) cat.id: cat};

      // Charger les budgets du mois en cours
      final currentBudgets = await _budgetService.getCurrentMonthBudgets();
      if (!mounted) return;

      // Calculer les montants dépensés pour chaque budget
      final Map<String, double> spent = {};
      for (var budget in currentBudgets) {
        final amount = await _budgetChecker.getCategorySpent(
          categoryId: budget.categoryId,
        );
        spent[budget.categoryId] = amount;
      }

      if (!mounted) return;
      
      setState(() {
        budgets = currentBudgets;
        spentAmounts = spent;
        isLoading = false;
      });
      
      print('✅ Budgets loaded: ${budgets.length} budgets');
    } catch (e) {
      print('❌ Error loading budgets: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le budget'),
        content: const Text('Voulez-vous vraiment supprimer ce budget ?'),
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
        await _budgetService.deleteBudget(budget.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Budget supprimé'),
              backgroundColor: Colors.green,
            ),
          );
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

  void _editBudget(Budget budget) async {
    final category = categories[budget.categoryId];
    if (category == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetBudgetScreen(
          category: category,
          existingBudget: budget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final currentMonth = '${months[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Budgets'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // En-tête du mois
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Période actuelle',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentMonth,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${budgets.length} budget${budgets.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Liste des budgets
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : budgets.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: budgets.length,
                          itemBuilder: (context, index) {
                            final budget = budgets[index];
                            final category = categories[budget.categoryId];
                            final spent = spentAmounts[budget.categoryId] ?? 0.0;
                            
                            if (category == null) return const SizedBox();
                            
                            return _buildBudgetCard(budget, category, spent);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCategorySelector,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un budget'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget, Category category, double spent) {
    final percentage = budget.amount > 0 ? (spent / budget.amount * 100) : 0.0;
    final remaining = budget.amount - spent;
    
    Color statusColor;
    String statusText;
    
    if (percentage >= 100) {
      statusColor = Colors.red;
      statusText = 'Dépassé';
    } else if (percentage >= 90) {
      statusColor = Colors.orange;
      statusText = 'Attention';
    } else if (percentage >= 75) {
      statusColor = Colors.amber;
      statusText = 'Prudence';
    } else {
      statusColor = Colors.green;
      statusText = 'OK';
    }

    final categoryColor = CategoryIconUtils.getColor(category.color);
    final categoryIcon = CategoryIconUtils.getIcon(category.icon);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
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
                      _editBudget(budget);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteBudget(budget);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec catégorie et statut
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          '${spent.toStringAsFixed(2)} / ${budget.amount.toStringAsFixed(2)} د.ت',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Barre de progression
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(0)}% utilisé',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        remaining >= 0 
                            ? 'Reste: ${remaining.toStringAsFixed(2)} د.ت'
                            : 'Dépassement: ${(-remaining).toStringAsFixed(2)} د.ت',
                        style: TextStyle(
                          fontSize: 12,
                          color: remaining >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage > 100 ? 1.0 : percentage / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
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
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: AppTheme.mediumGrey,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun budget',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Définissez des budgets pour mieux\ngérer vos dépenses',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCategorySelector,
            icon: const Icon(Icons.add),
            label: const Text('Créer mon premier budget'),
          ),
        ],
      ),
    );
  }

  // ✅ CORRIGÉ: BottomSheet scrollable avec toutes les catégories
  Future<void> _showCategorySelector() async {
    final expenseCategories = categories.values
        .where((cat) => cat.type == 'expense')
        .toList();

    if (expenseCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Aucune catégorie de dépense disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true, // ✅ Permet le scroll
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // ✅ 60% de l'écran au départ
        minChildSize: 0.4,
        maxChildSize: 0.9, // ✅ Maximum 90% de l'écran
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête fixe
              const Text(
                'Choisir une catégorie',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${expenseCategories.length} catégorie${expenseCategories.length > 1 ? 's' : ''} disponible${expenseCategories.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Liste scrollable
              Expanded(
                child: ListView.separated(
                  controller: scrollController, // ✅ Important pour le scroll
                  itemCount: expenseCategories.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final category = expenseCategories[index];
                    final categoryColor = CategoryIconUtils.getColor(category.color);
                    final categoryIcon = CategoryIconUtils.getIcon(category.icon);
                    
                    // Vérifier si un budget existe déjà pour cette catégorie
                    final hasBudget = budgets.any((b) => b.categoryId == category.id);
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(categoryIcon, color: categoryColor, size: 20),
                      ),
                      title: Text(category.name),
                      trailing: hasBudget
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Défini',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => Navigator.pop(context, category),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetBudgetScreen(category: selected),
        ),
      );
    }
  }
}