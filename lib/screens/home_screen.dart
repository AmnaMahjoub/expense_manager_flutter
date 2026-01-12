import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pie_chart/pie_chart.dart';
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
  
  // Filtres
  TransactionType selectedType = TransactionType.expense;
  String selectedPeriod = "Mois"; // Jour, Semaine, Mois, Année
  DateTime periodStart = DateTime.now();
  DateTime periodEnd = DateTime.now();
  
  // Données
  bool isLoading = true;
  Map<String, Category> categories = {};
  Map<String, double> categorySummary = {};
  double totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _initializePeriod();
    _loadData();
  }

  void _initializePeriod() {
    DateTime now = DateTime.now();
    
    switch (selectedPeriod) {
      case "Jour":
        periodStart = DateTime(now.year, now.month, now.day);
        periodEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case "Semaine":
        int weekday = now.weekday;
        periodStart = now.subtract(Duration(days: weekday - 1));
        periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
        periodEnd = periodStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case "Mois":
        periodStart = DateTime(now.year, now.month, 1);
        periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case "Année":
        periodStart = DateTime(now.year, 1, 1);
        periodEnd = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Charger les catégories
      final cats = await _categoryService.getAllCategories();
      categories = {for (var cat in cats) cat.id: cat};

      // Charger les transactions
      final transactions = await _transactionService.getTransactionsByTypeAndPeriod(
        type: selectedType,
        start: periodStart,
        end: periodEnd,
      );

      // Calculer le résumé par catégorie
      Map<String, double> summary = {};
      double total = 0;

      for (var transaction in transactions) {
        String categoryId = transaction.categoryId;
        double amount = transaction.amount;
        
        summary[categoryId] = (summary[categoryId] ?? 0) + amount;
        total += amount;
      }

      setState(() {
        categorySummary = summary;
        totalAmount = total;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement: $e');
      setState(() => isLoading = false);
    }
  }

  void _nextPeriod() {
    setState(() {
      switch (selectedPeriod) {
        case "Jour":
          periodStart = periodStart.add(const Duration(days: 1));
          periodEnd = periodStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
          break;
        case "Semaine":
          periodStart = periodStart.add(const Duration(days: 7));
          periodEnd = periodStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case "Mois":
          periodStart = DateTime(periodStart.year, periodStart.month + 1, 1);
          periodEnd = DateTime(periodStart.year, periodStart.month + 2, 0, 23, 59, 59);
          break;
        case "Année":
          periodStart = DateTime(periodStart.year + 1, 1, 1);
          periodEnd = DateTime(periodStart.year + 1, 12, 31, 23, 59, 59);
          break;
      }
    });
    _loadData();
  }

  void _previousPeriod() {
    setState(() {
      switch (selectedPeriod) {
        case "Jour":
          periodStart = periodStart.subtract(const Duration(days: 1));
          periodEnd = periodStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
          break;
        case "Semaine":
          periodStart = periodStart.subtract(const Duration(days: 7));
          periodEnd = periodStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          break;
        case "Mois":
          periodStart = DateTime(periodStart.year, periodStart.month - 1, 1);
          periodEnd = DateTime(periodStart.year, periodStart.month, 0, 23, 59, 59);
          break;
        case "Année":
          periodStart = DateTime(periodStart.year - 1, 1, 1);
          periodEnd = DateTime(periodStart.year - 1, 12, 31, 23, 59, 59);
          break;
      }
    });
    _loadData();
  }

  String _formatPeriod() {
    switch (selectedPeriod) {
      case "Jour":
        return "${periodStart.day}/${periodStart.month}/${periodStart.year}";
      case "Semaine":
        return "${periodStart.day}/${periodStart.month} - ${periodEnd.day}/${periodEnd.month}";
      case "Mois":
        const months = ["", "Janvier", "Février", "Mars", "Avril", "Mai", "Juin", 
                       "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
        return "${months[periodStart.month]} ${periodStart.year}";
      case "Année":
        return "${periodStart.year}";
      default:
        return "";
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
                      _buildTotalCard(),
                      const SizedBox(height: 16),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      _buildPeriodSelector(),
                      const SizedBox(height: 24),
                      _buildPieChart(),
                      const SizedBox(height: 24),
                      _buildCategoriesList(),
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
        backgroundColor: selectedType == TransactionType.expense 
            ? AppTheme.expenseColor 
            : AppTheme.incomeColor,
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
      backgroundColor: selectedType == TransactionType.expense 
          ? AppTheme.expenseColor 
          : AppTheme.incomeColor,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: selectedType == TransactionType.expense 
                ? AppTheme.expenseGradient 
                : AppTheme.incomeGradient,
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

  Widget _buildTotalCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        gradient: selectedType == TransactionType.expense 
            ? AppTheme.expenseGradient 
            : AppTheme.incomeGradient,
        child: Column(
          children: [
            Text(
              selectedType == TransactionType.expense ? "Total Dépenses" : "Total Revenus",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${totalAmount.toStringAsFixed(2)} د.ت",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatPeriod(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                type: TransactionType.expense,
                color: AppTheme.expenseColor,
                icon: Icons.arrow_downward,
              ),
            ),
            Expanded(
              child: _buildTypeChip(
                label: 'Revenus',
                type: TransactionType.income,
                color: AppTheme.incomeColor,
                icon: Icons.arrow_upward,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required TransactionType type,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = selectedType == type;
    
    return InkWell(
      onTap: () {
        setState(() => selectedType = type);
        _loadData();
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

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          children: [
            // Dropdown pour sélectionner la période
            DropdownButton<String>(
              value: selectedPeriod,
              isExpanded: true,
              underline: Container(),
              items: ["Jour", "Semaine", "Mois", "Année"]
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedPeriod = value;
                    _initializePeriod();
                  });
                  _loadData();
                }
              },
            ),
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            
            // Navigation de période
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: _previousPeriod,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.lightGrey,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatPeriod(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 20),
                  onPressed: _nextPeriod,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.lightGrey,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (categorySummary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "Aucune transaction pour cette période",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Préparer les données pour le PieChart
    Map<String, double> chartData = {};
    List<Color> chartColors = [];

    for (var entry in categorySummary.entries) {
      String categoryId = entry.key;
      Category? category = categories[categoryId];
      
      if (category != null) {
        chartData[category.name] = entry.value;
        chartColors.add(CategoryIconUtils.getColor(category.color));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Répartition par catégorie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            PieChart(
              dataMap: chartData,
              animationDuration: const Duration(milliseconds: 800),
              chartType: ChartType.disc,
              chartRadius: MediaQuery.of(context).size.width / 2.5,
              colorList: chartColors,
              chartValuesOptions: const ChartValuesOptions(
                showChartValuesInPercentage: true,
                showChartValuesOutside: true,
                decimalPlaces: 1,
                showChartValueBackground: true,
                chartValueBackgroundColor: Colors.white,
                chartValueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              legendOptions: const LegendOptions(
                showLegends: true,
                showLegendsInRow: false,
                legendPosition: LegendPosition.right,
                legendTextStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (categorySummary.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Catégories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categorySummary.length,
          itemBuilder: (context, index) {
            String categoryId = categorySummary.keys.elementAt(index);
            double amount = categorySummary[categoryId]!;
            Category? category = categories[categoryId];
            
            if (category == null) return const SizedBox.shrink();
            
            double percent = (amount / totalAmount) * 100;
            
            return _buildCategoryCard(category, amount, percent);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Category category, double amount, double percent) {
    final categoryColor = CategoryIconUtils.getColor(category.color);
    final categoryIcon = CategoryIconUtils.getIcon(category.icon);

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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryTransactionsScreen(
                categoryId: category.id,
                categoryName: category.name,
                periodStart: periodStart,
                periodEnd: periodEnd,
              ),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
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
                child: Icon(
                  categoryIcon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Info
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
                      '${percent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${amount.toStringAsFixed(2)} د.ت',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
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