import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:madarsaConnect/Data/loader.dart';

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

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
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
          'Madarsa Management',
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
          tabs: const [Tab(text: 'EXPENSES'), Tab(text: 'INVENTORY')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [ExpensesManagementTab(), InventoryManagementTab()],
      ),
    );
  }
}

// --- Expenses Management Tab ---
class ExpensesManagementTab extends StatefulWidget {
  const ExpensesManagementTab({super.key});

  @override
  State<ExpensesManagementTab> createState() => _ExpensesManagementTabState();
}

class _ExpensesManagementTabState extends State<ExpensesManagementTab> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  final List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  void _showExpenseBottomSheet({DocumentSnapshot? expenseDoc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseFormSheet(expenseDoc: expenseDoc),
    );
  }

  void _showExpenseOptionsDialog(DocumentSnapshot expenseDoc) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Expense Options',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gilroy-Bold'),
            ),
            content: const Text(
              'What would you like to do with this expense record?',
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(
              bottom: 20,
              left: 20,
              right: 20,
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Edit Expense'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showExpenseBottomSheet(expenseDoc: expenseDoc);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Expense'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteConfirmation(expenseDoc);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation(DocumentSnapshot expenseDoc) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Expense?'),
            content: const Text(
              'Are you sure you want to delete this expense record? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  expenseDoc.reference.delete();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showYearPicker() async {
    final int currentYear = DateTime.now().year;
    final List<int> years = List.generate(10, (index) => currentYear - index);

    final int? pickedYear = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Select Year', textAlign: TextAlign.center),
            content: SizedBox(
              width: double.minPositive,
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      years[index].toString(),
                      textAlign: TextAlign.center,
                    ),
                    onTap: () => Navigator.pop(context, years[index]),
                  );
                },
              ),
            ),
          ),
    );

    if (pickedYear != null && pickedYear != _selectedYear) {
      setState(() {
        _selectedYear = pickedYear;
        // Reset month to current if year is changed to current, and month is in future
        if (_selectedYear == DateTime.now().year &&
            _selectedMonth > DateTime.now().month) {
          _selectedMonth = DateTime.now().month;
        }
      });
    }
  }

  Future<void> _showMonthPicker() async {
    final int currentYear = DateTime.now().year;
    final int currentMonth = DateTime.now().month;
    final int monthCount = (_selectedYear == currentYear) ? currentMonth : 12;

    final int? pickedMonth = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Select Month', textAlign: TextAlign.center),
            content: SizedBox(
              width: double.minPositive,
              height: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: monthCount,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      _monthNames[index],
                      textAlign: TextAlign.center,
                    ),
                    onTap: () => Navigator.pop(context, index + 1),
                  );
                },
              ),
            ),
          ),
    );

    if (pickedMonth != null && pickedMonth != _selectedMonth) {
      setState(() {
        _selectedMonth = pickedMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final DateTime startDate = DateTime(_selectedYear, _selectedMonth, 1);
    final DateTime endDate = DateTime(_selectedYear, _selectedMonth + 1, 1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showMonthPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _monthNames[_selectedMonth - 1],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showYearPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedYear.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('expenses')
                      .where(
                        'date',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
                      )
                      .where('date', isLessThan: Timestamp.fromDate(endDate))
                      .orderBy('date', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Something went wrong."));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No expenses found for this period."),
                  );
                }
                final expenses = snapshot.data!.docs;
                double totalAmount = expenses.fold(
                  0,
                  (sum, item) => sum + (item['amount'] as num),
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Card(
                        elevation: 0,
                        color: Colors.red.withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Expenses',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currencyFormat.format(totalAmount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          final data = expense.data() as Map<String, dynamic>;
                          final date = (data['date'] as Timestamp).toDate();

                          return Card(
                            elevation: 0,
                            color: Colors.grey.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF1B263B),
                              ),
                              title: Text(
                                data['description'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "${data['category']} • ${DateFormat.yMMMd().format(date)}",
                              ),
                              trailing: Text(
                                currencyFormat.format(data['amount']),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => _showExpenseOptionsDialog(expense),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 0,
        heroTag: 'addExpenseFab',
        onPressed: () => _showExpenseBottomSheet(),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _ExpenseFormSheet extends StatefulWidget {
  final DocumentSnapshot? expenseDoc;
  const _ExpenseFormSheet({this.expenseDoc});

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryDisplayController = TextEditingController();
  String? _selectedCategory;
  final List<String> _categories = [
    'Bills',
    'Kitchen',
    'Salaries',
    'Maintenance',
    'Stationery',
    'Other',
  ];
  bool _isLoading = false;
  bool get _isEditing => widget.expenseDoc != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.expenseDoc!.data() as Map<String, dynamic>;
      _amountController.text = data['amount'].toString();
      _descriptionController.text = data['description'];
      _selectedCategory = data['category'];
      _categoryDisplayController.text = _selectedCategory ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryDisplayController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'amount': double.parse(_amountController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'date': Timestamp.now(),
      };

      if (_isEditing) {
        await widget.expenseDoc!.reference.update(data);
      } else {
        await FirebaseFirestore.instance.collection('expenses').add(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCategorySelectionDialog() async {
    final String? result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: const Text(
              'Select a Category',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Gilroy-Bold'),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 20.0),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final bool isSelected = _selectedCategory == category;
                  return ListTile(
                    title: Text(
                      category,
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
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
          ),
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result;
        _categoryDisplayController.text = result;
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
                  _isEditing ? 'Edit Expense' : 'Add New Expense',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  decoration: premiumInputDecoration('Amount (in ₹)'),
                  keyboardType: TextInputType.number,
                  validator:
                      (v) => v!.trim().isEmpty ? 'Amount is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: premiumInputDecoration(
                    'Description (e.g., Electricity Bill)',
                  ),
                  validator:
                      (v) =>
                          v!.trim().isEmpty ? 'Description is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryDisplayController,
                  readOnly: true,
                  decoration: premiumInputDecoration(
                    'Select Category',
                  ).copyWith(
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showCategorySelectionDialog,
                  validator:
                      (v) => v!.trim().isEmpty ? 'Category is required' : null,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: GradientSpinner())
                    : ElevatedButton(
                      onPressed: _saveExpense,
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
                        _isEditing ? 'Update Expense' : 'Save Expense',
                        style: const TextStyle(fontFamily: 'Gilroy-Bold'),
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

// --- Inventory Management Tab ---
class InventoryManagementTab extends StatelessWidget {
  const InventoryManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('inventoryItems')
                .orderBy('itemName')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No items in inventory yet."));
          }
          final items = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final data = item.data() as Map<String, dynamic>;
              return Card(
                elevation: 0,
                color: Colors.grey.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['itemName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "In Stock: ${data['currentStock']} ${data['unit']}",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _StockActionButton(
                            label: 'Use (-)',
                            icon: Icons.remove,
                            color: Colors.orange,
                            onPressed:
                                () => _showStockUpdateDialog(
                                  context,
                                  item,
                                  "Stock Out",
                                ),
                          ),
                          const SizedBox(width: 10),
                          _StockActionButton(
                            label: 'Add (+)',
                            icon: Icons.add,
                            color: Colors.green,
                            onPressed:
                                () => _showStockUpdateDialog(
                                  context,
                                  item,
                                  "Stock In",
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 0,
        heroTag: 'addNewItemFab',
        onPressed: () => _showNewItemBottomSheet(context),
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add New Item',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showNewItemBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewItemFormSheet(),
    );
  }

  void _showStockUpdateDialog(
    BuildContext context,
    DocumentSnapshot item,
    String type,
  ) {
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              type == 'Stock In' ? 'Add Stock' : 'Use Stock',
              style: const TextStyle(fontFamily: 'Gilroy-Bold'),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: premiumInputDecoration('Quantity'),
                validator: (v) => v!.isEmpty ? 'Enter a quantity' : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final double quantity = double.parse(
                      quantityController.text,
                    );
                    final currentStock =
                        (item['currentStock'] as num).toDouble();

                    if (type == 'Stock Out' && quantity > currentStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text(
                            "Error: Quantity to use is more than available stock.",
                          ),
                        ),
                      );
                      return;
                    }

                    final newStock =
                        type == 'Stock In'
                            ? currentStock + quantity
                            : currentStock - quantity;

                    await FirebaseFirestore.instance.runTransaction((
                      transaction,
                    ) async {
                      transaction.update(item.reference, {
                        'currentStock': newStock,
                      });
                      transaction.set(
                        FirebaseFirestore.instance
                            .collection('stockHistory')
                            .doc(),
                        {
                          'itemId': item.id,
                          'itemName': item['itemName'],
                          'quantityChanged':
                              type == 'Stock In' ? quantity : -quantity,
                          'type': type,
                          'date': Timestamp.now(),
                        },
                      );
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontFamily: 'Gilroy-Bold'),
                ),
              ),
            ],
          ),
    );
  }
}

class _NewItemFormSheet extends StatefulWidget {
  const _NewItemFormSheet();
  @override
  State<_NewItemFormSheet> createState() => _NewItemFormSheetState();
}

class _NewItemFormSheetState extends State<_NewItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialStockController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitDisplayController = TextEditingController();
  String? _selectedUnit;
  final List<String> _units = ['kg', 'gram', 'liter', 'ml', 'piece', 'dozen'];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _initialStockController.dispose();
    _categoryController.dispose();
    _unitDisplayController.dispose();
    super.dispose();
  }

  Future<void> _saveNewItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('inventoryItems').add({
        'itemName': _nameController.text.trim(),
        'category': _categoryController.text.trim(),
        'unit': _selectedUnit,
        'currentStock': double.parse(_initialStockController.text.trim()),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save item: $e')));
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
                  onTap: () => Navigator.pop(context, unit),
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
                const Text(
                  'Add New Item to Inventory',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontFamily: 'Gilroy-Bold',
                    color: Color(0xFF1B263B),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: premiumInputDecoration(
                    'Item Name (e.g., Whiteboard Marker)',
                  ),
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: premiumInputDecoration(
                    'Category (e.g., Stationery)',
                  ),
                  validator: (v) => v!.isEmpty ? 'Category is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _unitDisplayController,
                  readOnly: true,
                  decoration: premiumInputDecoration('Select Unit').copyWith(
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: _showUnitSelectionDialog,
                  validator: (v) => v!.isEmpty ? 'Unit is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _initialStockController,
                  decoration: premiumInputDecoration('Initial Stock Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Stock is required' : null,
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                      onPressed: _saveNewItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save New Item',
                        style: TextStyle(fontFamily: 'Gilroy-Bold'),
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

class _StockActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _StockActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}