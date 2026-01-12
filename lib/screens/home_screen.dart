import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/screens/add_transaction_screen.dart';
import 'package:expense_manager/screens/categories_screen.dart';
import 'package:expense_manager/screens/graphics_screen.dart';
import 'package:expense_manager/screens/category_transactions_screen.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/widgets/gradient_card.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  
  bool isLoading = true;
  Map<String, Category> categories = {};
  List<TransactionModel> recentTransactions = [];
  
  double totalIncome = 0;
  double totalExpense = 0;
  double balance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Load categories
      final cats = await _categoryService.getAllCategories();
      categories = {for (var cat in cats) cat.id: cat};

      // Get current month dates
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Load transactions for current month
      final incomes = await _transactionService.getTransactionsByTypeAndPeriod(
        type: TransactionType.income,
        start: startOfMonth,
        end: endOfMonth,
      );
      
      final expenses = await _transactionService.getTransactionsByTypeAndPeriod(
        type: TransactionType.expense,
        start: startOfMonth,
        end: endOfMonth,
      );

      // Load recent transactions
      final recent = await _transactionService.getRecentTransactions(limit: 5);

      // Calculate totals
      double income = incomes.fold(0.0, (sum, t) => sum + t.amount);
      double expense = expenses.fold(0.0, (sum, t) => sum + t.amount);

      setState(() {
        totalIncome = income;
        totalExpense = expense;
        balance = income - expense;
        recentTransactions = recent;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 16),
                      _buildQuickStats(),
                      const SizedBox(height: 24),
                      _buildRecentTransactions(),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildAppBar() {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email?.split('@')[0] ?? 'Utilisateur';

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Bonjour, $userName 👋',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        gradient: balance >= 0 ? AppTheme.incomeGradient : AppTheme.expenseGradient,
        child: Column(
          children: [
            const Text(
              'Solde du mois',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${balance.toStringAsFixed(2)} د.ت',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    'Revenus',
                    totalIncome,
                    Icons.arrow_upward,
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white30,
                ),
                Expanded(
                  child: _buildBalanceItem(
                    'Dépenses',
                    totalExpense,
                    Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(String label, double amount, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} د.ت',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: InfoCard(
              title: 'Transactions',
              value: recentTransactions.length.toString(),
              icon: Icons.receipt_long,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InfoCard(
              title: 'Catégories',
              value: categories.length.toString(),
              icon: Icons.category,
              color: AppTheme.secondaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                ).then((_) => _loadData());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transactions récentes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GraphicsScreen()),
                  );
                },
                child: const Text('Voir tout'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (recentTransactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune transaction',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentTransactions.length,
            itemBuilder: (context, index) {
              final transaction = recentTransactions[index];
              final category = categories[transaction.categoryId];
              
              return _buildTransactionCard(transaction, category);
            },
          ),
      ],
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction, Category? category) {
    final isIncome = transaction.type == TransactionType.income;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: category != null
                ? CategoryIconUtils.getColor(category.color).withOpacity(0.2)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            category != null
                ? CategoryIconUtils.getIcon(category.icon)
                : Icons.category,
            color: category != null
                ? CategoryIconUtils.getColor(category.color)
                : Colors.grey,
          ),
        ),
        title: Text(
          category?.name ?? 'Sans catégorie',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(transaction.formattedDate),
        trailing: Text(
          '${isIncome ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} د.ت',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
          ),
        ),
        onTap: () {
          if (category != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryTransactionsScreen(
                  categoryId: category.id,
                  categoryName: category.name,
                ),
              ),
            ).then((_) => _loadData());
          }
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.account_balance_wallet,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Expense Manager',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Accueil'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Catégories'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    ).then((_) => _loadData());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Graphiques'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GraphicsScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}