import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madarsaConnect/Data/loader.dart';
import '../Data/dynamic_popup.dart';

InputDecoration premiumInputDecoration(String labelText) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: TextStyle(color: Colors.grey[600]),
    filled: true,
    fillColor: Colors.grey.withOpacity(0.05),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black, width: 1.5),
    ),
  );
}

class KitchenAdminPanelScreen extends StatefulWidget {
  const KitchenAdminPanelScreen({super.key});

  @override
  State<KitchenAdminPanelScreen> createState() =>
      _KitchenAdminPanelScreenState();
}

class _KitchenAdminPanelScreenState extends State<KitchenAdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kitchen Management',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'Gilroy-Bold',
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.redAccent,
          labelColor: const Color(0xFF1B263B),
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: 'INGREDIENTS'), Tab(text: 'RECIPES')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [IngredientsManagementTab(), RecipesManagementTab()],
      ),
    );
  }
}

class IngredientsManagementTab extends StatelessWidget {
  const IngredientsManagementTab({super.key});

  void _showIngredientBottomSheet(
    BuildContext context, {
    DocumentSnapshot? ingredientDoc,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IngredientFormSheet(ingredientDoc: ingredientDoc),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    DocumentSnapshot ingredientDoc,
  ) {
    final data = ingredientDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Delete Ingredient',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gilroy-Bold'),
          ),
          content: Text(
            'Are you sure you want to delete "${data['name']}"?',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: () async {
                try {
                  await ingredientDoc.reference.delete();
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    CustomPopup.show(
                      context,
                      'Failed to delete ingredient: $e',
                    );
                  }
                }
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceEvenly,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('ingredients')
                .orderBy('name')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GradientSpinner());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No ingredients added yet."));
          }
          final ingredients = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];
              final data = ingredient.data() as Map<String, dynamic>;
              return Card(
                elevation: 0,
                color: Colors.grey.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    data['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Unit: ${data['unit']}'),
                  trailing: Text(
                    '₹${data['price']}/${data['unit']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1B263B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap:
                      () => _showIngredientBottomSheet(
                        context,
                        ingredientDoc: ingredient,
                      ),
                  onLongPress:
                      () => _showDeleteConfirmationDialog(context, ingredient),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 0,
        heroTag: 'addIngredientFab',
        onPressed: () => _showIngredientBottomSheet(context),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Ingredient',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _IngredientFormSheet extends StatefulWidget {
  final DocumentSnapshot? ingredientDoc;
  const _IngredientFormSheet({this.ingredientDoc});

  @override
  State<_IngredientFormSheet> createState() => _IngredientFormSheetState();
}

class _IngredientFormSheetState extends State<_IngredientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitDisplayController = TextEditingController();
  String? _selectedUnit;
  final List<String> _units = ['kg', 'gram', 'liter', 'ml', 'piece', 'dozen'];

  bool _isLoading = false;
  bool get _isEditing => widget.ingredientDoc != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.ingredientDoc!.data() as Map<String, dynamic>;
      _nameController.text = data['name'];
      _selectedUnit = data['unit'];
      _unitDisplayController.text = _selectedUnit ?? '';
      _priceController.text = data['price'].toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitDisplayController.dispose();
    super.dispose();
  }

  Future<void> _saveIngredient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'unit': _selectedUnit,
        'price': double.parse(_priceController.text.trim()),
      };
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('ingredients')
            .doc(widget.ingredientDoc!.id)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('ingredients').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, 'Failed to save ingredient: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showUnitSelectionDialog() async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Select a Unit',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gilroy-Bold'),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _units.length,
              itemBuilder: (BuildContext context, int index) {
                final unit = _units[index];
                final bool isSelected = _selectedUnit == unit;
                return ListTile(
                  title: Text(
                    unit,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing:
                      isSelected
                          ? const Icon(
                            Icons.check_circle,
                            color: Colors.redAccent,
                          )
                          : null,
                  onTap: () {
                    Navigator.pop(context, unit);
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedUnit = result;
        _unitDisplayController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit Ingredient' : 'Add New Ingredient',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: premiumInputDecoration(
                    'Ingredient Name (e.g., Rice)',
                  ),
                  validator:
                      (v) => v!.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unitDisplayController,
                  textCapitalization: TextCapitalization.words,
                  readOnly: true,
                  decoration: premiumInputDecoration('Select Unit').copyWith(
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showUnitSelectionDialog,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please select a unit'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  textCapitalization: TextCapitalization.words,
                  decoration: premiumInputDecoration('Price per Unit (in ₹)'),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) => v!.trim().isEmpty ? 'Price is required' : null,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: GradientSpinner())
                    : ElevatedButton(
                      onPressed: _saveIngredient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isEditing ? 'Update Ingredient' : 'Save Ingredient',
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecipesManagementTab extends StatelessWidget {
  const RecipesManagementTab({super.key});

  void _showRecipeBottomSheet(
    BuildContext context, {
    DocumentSnapshot? recipeDoc,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeFormSheet(recipeDoc: recipeDoc),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    DocumentSnapshot recipeDoc,
  ) {
    final data = recipeDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Delete Recipe',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gilroy-Bold'),
          ),
          content: Text(
            'Are you sure you want to delete "${data['dishName']}"?',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: () async {
                try {
                  await recipeDoc.reference.delete();
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    CustomPopup.show(context, 'Failed to delete recipe: $e');
                  }
                }
              },
            ),
          ],
          actionsAlignment: MainAxisAlignment.spaceEvenly,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('recipes')
                .orderBy('dishName')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: GradientSpinner());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No recipes added yet."));
          }
          final recipes = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final data = recipe.data() as Map<String, dynamic>;
              final ingredientsList =
                  data['ingredients'] as List<dynamic>? ?? [];
              return Card(
                elevation: 0,
                color: Colors.grey.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    data['dishName'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${ingredientsList.length} ingredients'),
                  trailing: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF1B263B),
                  ),
                  onTap:
                      () => _showRecipeBottomSheet(context, recipeDoc: recipe),
                  onLongPress:
                      () => _showDeleteConfirmationDialog(context, recipe),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 0,
        heroTag: 'addRecipeFab',
        onPressed: () => _showRecipeBottomSheet(context),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Recipe', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _RecipeFormSheet extends StatefulWidget {
  final DocumentSnapshot? recipeDoc;
  const _RecipeFormSheet({super.key, this.recipeDoc});

  @override
  State<_RecipeFormSheet> createState() => _RecipeFormSheetState();
}

class _RecipeFormSheetState extends State<_RecipeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dishNameController = TextEditingController();
  List<Map<String, dynamic>> _recipeIngredients = [];
  bool _isLoading = false;
  bool get _isEditing => widget.recipeDoc != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.recipeDoc!.data() as Map<String, dynamic>;
      _dishNameController.text = data['dishName'];
      _recipeIngredients = List<Map<String, dynamic>>.from(
        data['ingredients'] ?? [],
      );
    }
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    super.dispose();
  }

  Future<void> _showAddIngredientSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddIngredientToRecipeSheet(),
    );
    if (result != null) {
      setState(() {
        _recipeIngredients.add(result);
      });
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recipeIngredients.isEmpty) {
      CustomPopup.show(context, 'Please add at least one ingredient.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final data = {
        'dishName': _dishNameController.text.trim(),
        'ingredients': _recipeIngredients,
      };
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(widget.recipeDoc!.id)
            .update(data);
      } else {
        await FirebaseFirestore.instance.collection('recipes').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        CustomPopup.show(context, 'Failed to save recipe: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit Recipe' : 'Add New Recipe',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _dishNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: premiumInputDecoration(
                    'Dish Name (e.g., Daal Chawal)',
                  ),
                  validator:
                      (v) => v!.trim().isEmpty ? 'Dish name is required' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ingredients (per student)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                if (_recipeIngredients.isEmpty)
                  const Text(
                    'No ingredients added yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ..._recipeIngredients.map(
                  (ing) => Card(
                    color: Colors.grey.withOpacity(0.05),
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(ing['ingredientName']),
                      subtitle: Text('${ing['quantity']} ${ing['unit']}'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed:
                            () =>
                                setState(() => _recipeIngredients.remove(ing)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showAddIngredientSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Ingredient'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B263B),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: GradientSpinner())
                    : ElevatedButton(
                      onPressed: _saveRecipe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(_isEditing ? 'Update Recipe' : 'Save Recipe'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddIngredientToRecipeSheet extends StatefulWidget {
  const _AddIngredientToRecipeSheet();
  @override
  State<_AddIngredientToRecipeSheet> createState() =>
      _AddIngredientToRecipeSheetState();
}

class _AddIngredientToRecipeSheetState
    extends State<_AddIngredientToRecipeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _ingredientDisplayController = TextEditingController();
  DocumentSnapshot? _selectedIngredient;

  @override
  void dispose() {
    _quantityController.dispose();
    _ingredientDisplayController.dispose();
    super.dispose();
  }

  Future<void> _showIngredientSelectionDialog() async {
    final DocumentSnapshot? result = await showDialog<DocumentSnapshot>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: const Text(
            'Select an Ingredient',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Gilroy-Bold'),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('ingredients')
                      .orderBy('name')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: GradientSpinner());
                }
                final ingredients = snapshot.data!.docs;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: ingredients.length,
                  itemBuilder: (BuildContext context, int index) {
                    final doc = ingredients[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isSelected = _selectedIngredient?.id == doc.id;
                    return ListTile(
                      title: Text(
                        data['name'],
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.redAccent,
                              )
                              : null,
                      onTap: () {
                        Navigator.pop(context, doc);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedIngredient = result;
        _ingredientDisplayController.text =
            (result.data() as Map<String, dynamic>)['name'];
      });
    }
  }

  void _addIngredient() {
    if (!_formKey.currentState!.validate()) return;

    final data = _selectedIngredient!.data() as Map<String, dynamic>;
    final result = {
      'ingredientId': _selectedIngredient!.id,
      'ingredientName': data['name'],
      'unit': data['unit'],
      'quantity': double.parse(_quantityController.text.trim()),
    };
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Ingredient to Recipe',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _ingredientDisplayController,
                  textCapitalization: TextCapitalization.words,
                  readOnly: true,
                  decoration: premiumInputDecoration(
                    'Select Ingredient',
                  ).copyWith(
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showIngredientSelectionDialog,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Please select an ingredient'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: premiumInputDecoration(
                    'Quantity (e.g., 0.100 for 100g)',
                  ),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) => v!.trim().isEmpty ? 'Quantity is required' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _addIngredient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: const Text('Add to Recipe'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
