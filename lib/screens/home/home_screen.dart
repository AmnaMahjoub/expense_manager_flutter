import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:expense_manager/screens/add_transaction_screen.dart';
import 'package:expense_manager/screens/categories_screen.dart';
import 'package:expense_manager/screens/graphics_screen.dart';
import 'package:expense_manager/screens/category_transactions_screen.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TransactionType selectedType = TransactionType.expense;
  String selectedPeriod = "Mois";
  DateTime periodStart = DateTime.now();
  DateTime periodEnd = DateTime.now();

  Map<String, double> transactionSummary = {};
  double totalAmount = 0;
  bool isLoading = true;

  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  
  Map<String, Category> _categories = {};

  @override
  void initState() {
    super.initState();
    _initializePeriod();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadCategories();
    await _loadTransactions();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getAllCategories();
      setState(() {
        _categories = {for (var cat in categories) cat.id: cat};
      });
      print('✅ ${categories.length} catégories chargées');
    } catch (e) {
      print('❌ Erreur chargement catégories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
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

  Future<void> _loadTransactions() async {
    setState(() => isLoading = true);

    try {
      List<TransactionModel> transactions = await _transactionService.getTransactionsByTypeAndPeriod(
        type: selectedType,
        start: periodStart,
        end: periodEnd,
      );

      Map<String, double> summary = {};
      double total = 0;

      for (var transaction in transactions) {
        String categoryId = transaction.categoryId;
        double amount = transaction.amount;
        
        summary[categoryId] = (summary[categoryId] ?? 0) + amount;
        total += amount;
      }

      setState(() {
        transactionSummary = summary;
        totalAmount = total;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement transactions: $e');
      setState(() => isLoading = false);
    }
  }

  void nextPeriod() {
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
    _loadTransactions();
  }

  void previousPeriod() {
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
    _loadTransactions();
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

  String _getCategoryName(String categoryId) {
    return _categories[categoryId]?.name ?? 'Sans catégorie';
  }

  IconData _getCategoryIcon(String categoryId) {
    String iconName = _categories[categoryId]?.icon ?? 'category';
    
    switch (iconName.toLowerCase()) {
      case 'home': return Icons.home;
      case 'car':
      case 'transport': return Icons.directions_car;
      case 'restaurant':
      case 'food': return Icons.restaurant;
      case 'health':
      case 'medical': return Icons.medical_services;
      case 'entertainment': return Icons.sports_esports;
      case 'school':
      case 'education': return Icons.school;
      case 'shopping': return Icons.shopping_bag;
      case 'money':
      case 'salary': return Icons.attach_money;
      default: return Icons.category;
    }
  }

  Color _getCategoryColor(String categoryId) {
    String colorName = _categories[categoryId]?.color ?? 'blue';
    
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'blue': return Colors.blue;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'teal': return Colors.teal;
      case 'pink': return Colors.pink;
      case 'amber': return Colors.amber;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text("Accueil"),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          _loadData();
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet, size: 50, color: Colors.white),
                SizedBox(height: 10),
                Text("Gestion des Dépenses",
                    style: TextStyle(color: Colors.white, fontSize: 20)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Accueil"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text("Catégories"),
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
            title: const Text("Graphiques"),
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
            title: const Text("Déconnexion", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTotalCard(),
          const SizedBox(height: 12),
          _buildTypeSelector(),
          const SizedBox(height: 12),
          _buildPeriodSelector(),
          const SizedBox(height: 12),
          _buildPieChart(),
          const SizedBox(height: 12),
          Expanded(child: _buildTransactionsList()),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              selectedType == TransactionType.expense ? "Total Dépenses" : "Total Revenus",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              "${totalAmount.toStringAsFixed(2)} د.ت",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: selectedType == TransactionType.expense ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text("Dépenses"),
          selected: selectedType == TransactionType.expense,
          selectedColor: Colors.red.shade100,
          onSelected: (selected) {
            setState(() => selectedType = TransactionType.expense);
            _loadTransactions();
          },
        ),
        const SizedBox(width: 12),
        ChoiceChip(
          label: const Text("Revenus"),
          selected: selectedType == TransactionType.income,
          selectedColor: Colors.green.shade100,
          onSelected: (selected) {
            setState(() => selectedType = TransactionType.income);
            _loadTransactions();
          },
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left),
          onPressed: previousPeriod,
        ),
        Column(
          children: [
            DropdownButton<String>(
              value: selectedPeriod,
              items: ["Jour", "Semaine", "Mois", "Année"]
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedPeriod = value;
                    _initializePeriod();
                  });
                  _loadTransactions();
                }
              },
            ),
            Text(
              _formatPeriod(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: nextPeriod,
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    if (transactionSummary.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          "Aucune transaction pour cette période",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return PieChart(
      dataMap: transactionSummary.map((key, value) => 
          MapEntry(_getCategoryName(key), value)),
      animationDuration: const Duration(milliseconds: 800),
      chartType: ChartType.ring,
      chartRadius: MediaQuery.of(context).size.width / 2.7,
      colorList: transactionSummary.keys
          .map((categoryId) => _getCategoryColor(categoryId))
          .toList(),
      chartValuesOptions: const ChartValuesOptions(
          showChartValuesInPercentage: true),
    );
  }

  Widget _buildTransactionsList() {
    if (transactionSummary.isEmpty) {
      return const Center(
        child: Text(
          "Aucune donnée à afficher",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView(
      children: transactionSummary.entries.map((entry) {
        String categoryId = entry.key;
        double amount = entry.value;
        double percent = (amount / totalAmount) * 100;
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(categoryId).withOpacity(0.7),
              child: Icon(
                _getCategoryIcon(categoryId),
                color: Colors.white,
              ),
            ),
            title: Text(_getCategoryName(categoryId)),
            subtitle: Text("${percent.toStringAsFixed(1)}%"),
            trailing: Text(
              "${amount.toStringAsFixed(2)} د.ت",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryTransactionsScreen(
                    categoryId: categoryId,
                    categoryName: _getCategoryName(categoryId),
                  ),
                ),
              ).then((_) => _loadData());
            },
          ),
        );
      }).toList(),
    );
  }
}