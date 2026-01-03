import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';

class GraphicsScreen extends StatefulWidget {
  const GraphicsScreen({super.key});

  @override
  State<GraphicsScreen> createState() => _GraphicsScreenState();
}

class _GraphicsScreenState extends State<GraphicsScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  
  String selectedPeriod = "Mois"; // Jour, Semaine, Mois, Année
  bool isLoading = true;
  
  Map<String, double> periodData = {};
  Map<String, Category> _categories = {};
  
  // Données pour le graphique
  double totalIncome = 0;
  double totalExpense = 0;
  double balance = 0;
  
  String? selectedBar; // Pour afficher les détails d'une barre

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
      // Charger les catégories
      final categories = await _categoryService.getAllCategories();
      _categories = {for (var cat in categories) cat.id: cat};

      // Calculer les dates selon la période
      DateTime now = DateTime.now();
      DateTime start, end;
      
      if (selectedPeriod == "Jour") {
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (selectedPeriod == "Semaine") {
        int weekday = now.weekday;
        start = now.subtract(Duration(days: weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else if (selectedPeriod == "Mois") {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else { // Année
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
      }

      // Récupérer les transactions
      List<TransactionModel> incomes = await _transactionService.getTransactionsByTypeAndPeriod(
        type: TransactionType.income,
        start: start,
        end: end,
      );
      
      List<TransactionModel> expenses = await _transactionService.getTransactionsByTypeAndPeriod(
        type: TransactionType.expense,
        start: start,
        end: end,
      );

      // Calculer les totaux
      double income = 0;
      double expense = 0;
      
      for (var t in incomes) {
        income += t.amount;
      }
      
      for (var t in expenses) {
        expense += t.amount;
      }

      setState(() {
        totalIncome = income;
        totalExpense = expense;
        balance = income - expense;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Charger les détails par catégorie pour une barre
  Future<Map<String, double>> _loadCategoryDetails(TransactionType type) async {
    try {
      DateTime now = DateTime.now();
      DateTime start, end;
      
      if (selectedPeriod == "Jour") {
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (selectedPeriod == "Semaine") {
        int weekday = now.weekday;
        start = now.subtract(Duration(days: weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else if (selectedPeriod == "Mois") {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else {
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
      }

      List<TransactionModel> transactions = await _transactionService.getTransactionsByTypeAndPeriod(
        type: type,
        start: start,
        end: end,
      );

      Map<String, double> categoryData = {};
      for (var t in transactions) {
        categoryData[t.categoryId] = (categoryData[t.categoryId] ?? 0) + t.amount;
      }

      // Trier par montant décroissant
      var sortedEntries = categoryData.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return Map.fromEntries(sortedEntries);
    } catch (e) {
      print('Erreur: $e');
      return {};
    }
  }

  // Afficher les détails d'une catégorie
  void _showCategoryDetails(String barType) async {
    TransactionType type = barType == 'Revenus' ? TransactionType.income : TransactionType.expense;
    Map<String, double> categoryData = await _loadCategoryDetails(type);
    
    double total = barType == 'Revenus' ? totalIncome : totalExpense;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                barType,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${total.toStringAsFixed(2)} د.ت',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: barType == 'Revenus' ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Répartition par catégorie',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: categoryData.isEmpty
                    ? const Center(child: Text('Aucune donnée'))
                    : ListView(
                        children: categoryData.entries.map((entry) {
                          String categoryName = _categories[entry.key]?.name ?? 'Sans catégorie';
                          double percent = (entry.value / total) * 100;
                          
                          return ListTile(
                            title: Text(categoryName),
                            subtitle: Text('${percent.toStringAsFixed(1)}%'),
                            trailing: Text(
                              '${entry.value.toStringAsFixed(2)} د.ت',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graphiques'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélecteur de période
                  Center(
                    child: DropdownButton<String>(
                      value: selectedPeriod,
                      items: ["Jour", "Semaine", "Mois", "Année"]
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedPeriod = value;
                          });
                          _loadData();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Carte du solde
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Solde',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${balance.toStringAsFixed(2)} د.ت',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: balance >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Graphique en barres
                  const Text(
                    'Vue d\'ensemble',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    height: 300,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: [totalIncome, totalExpense].reduce((a, b) => a > b ? a : b) * 1.2,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchCallback: (FlTouchEvent event, barTouchResponse) {
                            if (event is FlTapUpEvent && barTouchResponse != null && barTouchResponse.spot != null) {
                              int touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                              if (touchedIndex == 0) {
                                _showCategoryDetails('Revenus');
                              } else if (touchedIndex == 1) {
                                _showCategoryDetails('Dépenses');
                              }
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                switch (value.toInt()) {
                                  case 0:
                                    return const Text('Revenus', style: TextStyle(fontSize: 12));
                                  case 1:
                                    return const Text('Dépenses', style: TextStyle(fontSize: 12));
                                  case 2:
                                    return const Text('Profit/Perte', style: TextStyle(fontSize: 12));
                                  default:
                                    return const Text('');
                                }
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: totalIncome,
                                color: Colors.green,
                                width: 40,
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: totalExpense,
                                color: Colors.red,
                                width: 40,
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 2,
                            barRods: [
                              BarChartRodData(
                                toY: balance.abs(),
                                color: balance >= 0 ? Colors.blue : Colors.orange,
                                width: 40,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Résumé des valeurs
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSummaryRow('Revenus', totalIncome, Colors.green),
                          const Divider(),
                          _buildSummaryRow('Dépenses', totalExpense, Colors.red),
                          const Divider(),
                          _buildSummaryRow('Profit/Perte', balance, balance >= 0 ? Colors.blue : Colors.orange),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            '${value.toStringAsFixed(2)} د.ت',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}