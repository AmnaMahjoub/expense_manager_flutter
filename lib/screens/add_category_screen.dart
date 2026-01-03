import 'package:flutter/material.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/category_service.dart';

class AddCategoryScreen extends StatefulWidget {
  final String initialType;

  const AddCategoryScreen({super.key, this.initialType = 'expense'});

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

  // Liste des icônes disponibles
  final Map<String, IconData> availableIcons = {
    'category': Icons.category,
    'home': Icons.home,
    'transport': Icons.directions_car,
    'food': Icons.restaurant,
    'health': Icons.medical_services,
    'entertainment': Icons.sports_esports,
    'education': Icons.school,
    'shopping': Icons.shopping_bag,
    'salary': Icons.attach_money,
    'money': Icons.monetization_on,
  };

  // Liste des couleurs disponibles
  final Map<String, Color> availableColors = {
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'teal': Colors.teal,
    'pink': Colors.pink,
    'amber': Colors.amber,
  };

  @override
  void initState() {
    super.initState();
    selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      try {
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
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une catégorie'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom de la catégorie
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Sélecteur de type
              const Text(
                'Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Dépense'),
                      selected: selectedType == 'expense',
                      selectedColor: Colors.red.shade100,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedType = 'expense';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Revenu'),
                      selected: selectedType == 'income',
                      selectedColor: Colors.green.shade100,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedType = 'income';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sélecteur d'icône
              const Text(
                'Icône',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableIcons.entries.map((entry) {
                  bool isSelected = selectedIcon == entry.key;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedIcon = entry.key;
                      });
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        size: 30,
                        color: isSelected ? Colors.blue : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Sélecteur de couleur
              const Text(
                'Couleur',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableColors.entries.map((entry) {
                  bool isSelected = selectedColor == entry.key;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedColor = entry.key;
                      });
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Aperçu
              const Text(
                'Aperçu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: availableColors[selectedColor]!.withOpacity(0.7),
                    child: Icon(
                      availableIcons[selectedIcon],
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    _nameController.text.isEmpty ? 'Nom de la catégorie' : _nameController.text,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(selectedType == 'expense' ? 'Dépense' : 'Revenu'),
                ),
              ),

              const SizedBox(height: 30),

              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Enregistrer',
                    style: TextStyle(fontSize: 18),
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