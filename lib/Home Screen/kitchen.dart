import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../Data/dynamic_popup.dart';
import '../Data/loader.dart';
import '../l10n/app_localizations.dart';

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

class KitchenCalculatorScreen extends StatefulWidget {
  const KitchenCalculatorScreen({super.key});

  @override
  State<KitchenCalculatorScreen> createState() =>
      _KitchenCalculatorScreenState();
}

class _KitchenCalculatorScreenState extends State<KitchenCalculatorScreen> {
  final _studentCountController = TextEditingController();
  final _dishDisplayController = TextEditingController();
  final _mealTypeDisplayController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DocumentSnapshot? _selectedRecipeDoc;
  String? _selectedMealType;
  final List<String> _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCalculated = false;

  List<Map<String, dynamic>> _calculationResult = [];
  double _grandTotal = 0.0;
  String _calculatedDishName = '';
  int _calculatedStudentCount = 0;

  Future<void> _calculateMealCost() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _isCalculated = false;
    });

    try {
      final int studentCount = int.parse(_studentCountController.text);

      final recipeData = _selectedRecipeDoc!.data() as Map<String, dynamic>;
      final List<dynamic> recipeIngredients = recipeData['ingredients'];

      List<Map<String, dynamic>> tempResults = [];
      double tempGrandTotal = 0.0;

      if (recipeIngredients.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.recipeHasNoIngredients);
      }

      final ingredientIds =
          recipeIngredients
              .map((ing) => ing['ingredientId'] as String)
              .toList();
      final ingredientsSnapshot =
          await FirebaseFirestore.instance
              .collection('ingredients')
              .where(FieldPath.documentId, whereIn: ingredientIds)
              .get();

      final ingredientsPriceMap = {
        for (var doc in ingredientsSnapshot.docs) doc.id: doc.data()['price'],
      };

      for (var recipeIngredient in recipeIngredients) {
        final perStudentQty = recipeIngredient['quantity'];
        final ingredientId = recipeIngredient['ingredientId'];
        final price = ingredientsPriceMap[ingredientId];

        if (price != null) {
          final totalQuantity = perStudentQty * studentCount;
          final totalCost = totalQuantity * price;

          tempResults.add({
            'name': recipeIngredient['ingredientName'],
            'quantity': totalQuantity,
            'unit': recipeIngredient['unit'],
            'cost': totalCost,
          });

          tempGrandTotal += totalCost;
        }
      }

      setState(() {
        _calculationResult = tempResults;
        _grandTotal = tempGrandTotal;
        _calculatedDishName = recipeData['dishName'];
        _calculatedStudentCount = studentCount;
        _isCalculated = true;
      });
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.errorCalculatingCost}: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveMealRecord() async {
    if (!_isCalculated) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('mealRecords').add({
        'timestamp': FieldValue.serverTimestamp(),
        'dishName': _calculatedDishName,
        'mealType': _selectedMealType,
        'studentCount': _calculatedStudentCount,
        'totalCost': _grandTotal,
        'costPerStudent':
            _grandTotal > 0 && _calculatedStudentCount > 0
                ? _grandTotal / _calculatedStudentCount
                : 0,
        'calculationDetails': _calculationResult,
      });

      if (mounted) {
        CustomPopup.show(
          context,
          AppLocalizations.of(context)!.recordSavedSuccessfully,
        );
        setState(() {
          _isCalculated = false;
          _studentCountController.clear();
          _dishDisplayController.clear();
          _mealTypeDisplayController.clear();
          _selectedRecipeDoc = null;
          _selectedMealType = null;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          '${AppLocalizations.of(context)!.errorSavingRecord}: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showDishSelectionDialog() async {
    final DocumentSnapshot? result = await showDialog<DocumentSnapshot>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          // Font family removed, using fontWeight
          title: Text(
            AppLocalizations.of(context)!.selectDish,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('recipes')
                      .orderBy('dishName')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: GradientSpinner());
                }
                final recipes = snapshot.data!.docs;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: recipes.length,
                  itemBuilder: (BuildContext context, int index) {
                    final doc = recipes[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isSelected = _selectedRecipeDoc?.id == doc.id;
                    return ListTile(
                      title: Text(
                        data['dishName'],
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
        _selectedRecipeDoc = result;
        _dishDisplayController.text =
            (result.data() as Map<String, dynamic>)['dishName'];
      });
    }
  }

  Future<void> _showMealTypeSelectionDialog() async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          // Font family removed
          title: Text(
            AppLocalizations.of(context)!.selectMealType,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _mealTypes.length,
              itemBuilder: (BuildContext context, int index) {
                final type = _mealTypes[index];
                final bool isSelected = _selectedMealType == type;
                return ListTile(
                  title: Text(
                    type,
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
                    Navigator.pop(context, type);
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
        _selectedMealType = result;
        _mealTypeDisplayController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        // Font family removed
        title: Text(
          AppLocalizations.of(context)!.mealCostCalculator,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputSection(),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: GradientSpinner())
                  : ElevatedButton(
                    onPressed: _calculateMealCost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    // Font family removed
                    child: Text(
                      AppLocalizations.of(context)!.calculateCost,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.history_rounded),
                label: Text(AppLocalizations.of(context)!.viewPreviousRecords),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PreviousMealsScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B263B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (_isCalculated) _buildResultsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        TextFormField(
          controller: _studentCountController,
          keyboardType: TextInputType.number,
          decoration: premiumInputDecoration(
            AppLocalizations.of(context)!.numberOfStudents,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.enterNumberOfStudents;
            }
            if (int.tryParse(value) == null || int.parse(value) <= 0) {
              return AppLocalizations.of(context)!.enterValidNumber;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dishDisplayController,
          readOnly: true,
          decoration: premiumInputDecoration(
            AppLocalizations.of(context)!.selectDish,
          ).copyWith(
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ),
          onTap: _showDishSelectionDialog,
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? AppLocalizations.of(context)!.pleaseSelectDish
                      : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mealTypeDisplayController,
          readOnly: true,
          decoration: premiumInputDecoration(
            AppLocalizations.of(context)!.selectMealType,
          ).copyWith(
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ),
          onTap: _showMealTypeSelectionDialog,
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? AppLocalizations.of(context)!.pleaseSelectMealType
                      : null,
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Font family removed
        Text(
          AppLocalizations.of(context)!.estimationFor(_calculatedDishName),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._calculationResult.map(
          (item) => Card(
            elevation: 0,
            color: Colors.grey.withOpacity(0.05),
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              title: Text(
                item['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.quantityUnit(
                  item['quantity'].toStringAsFixed(2),
                  item['unit'],
                ),
              ),
              trailing: Text(
                currencyFormat.format(item['cost']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 30, thickness: 1),
        _buildGrandTotal(currencyFormat),
        const SizedBox(height: 30),
        _isSaving
            ? const Center(child: GradientSpinner())
            : Center(
              child: ElevatedButton.icon(
                onPressed: _saveMealRecord,
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: Text(AppLocalizations.of(context)!.saveThisRecord),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  foregroundColor: Colors.green.shade800,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildGrandTotal(NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppLocalizations.of(context)!.grandTotal,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // Font family removed
          Text(
            currencyFormat.format(_grandTotal),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class PreviousMealsScreen extends StatefulWidget {
  const PreviousMealsScreen({super.key});

  @override
  State<PreviousMealsScreen> createState() => _PreviousMealsScreenState();
}

class _PreviousMealsScreenState extends State<PreviousMealsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<DocumentSnapshot> _records = [];

  @override
  void initState() {
    super.initState();
    _fetchRecordsForDate(_selectedDate);
  }

  Future<void> _fetchRecordsForDate(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final startOfDay = Timestamp.fromDate(
        DateTime(date.year, date.month, date.day),
      );
      final endOfDay = Timestamp.fromDate(
        DateTime(date.year, date.month, date.day, 23, 59, 59),
      );

      final snapshot =
          await FirebaseFirestore.instance
              .collection('mealRecords')
              .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
              .where('timestamp', isLessThanOrEqualTo: endOfDay)
              .orderBy('timestamp', descending: true)
              .get();

      setState(() {
        _records = snapshot.docs;
      });
    } catch (e) {
      if (mounted) {
        CustomPopup.show(
          context,
          "${AppLocalizations.of(context)!.errorFetchingRecords}: $e",
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.redAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchRecordsForDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Font family removed
        title: Text(
          AppLocalizations.of(context)!.previousMealRecords,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat.yMMMMd().format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: GradientSpinner())
                    : _records.isEmpty
                    ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noRecordsFoundForDate,
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final doc = _records[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final details =
                            data['calculationDetails'] as List<dynamic>? ?? [];

                        return Card(
                          elevation: 0,
                          color: Colors.grey.withOpacity(0.05),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            title: Text(
                              data['dishName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              AppLocalizations.of(context)!.mealTypeStudents(
                                data['mealType'],
                                data['studentCount'].toString(),
                              ),
                            ),
                            // Font family removed
                            trailing: Text(
                              currencyFormat.format(data['totalCost']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            children: [
                              for (var item in details)
                                ListTile(
                                  dense: true,
                                  title: Text(item['name']),
                                  subtitle: Text(
                                    AppLocalizations.of(context)!.quantityUnit(
                                      item['quantity'].toStringAsFixed(2),
                                      item['unit'],
                                    ),
                                  ),
                                  trailing: Text(
                                    currencyFormat.format(item['cost']),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
