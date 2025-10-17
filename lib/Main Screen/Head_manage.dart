import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:madarsaConnect/Data/loader.dart';
import 'package:madarsaConnect/Data/uppercase.dart';
import 'package:madarsaConnect/Data/dynamic_popup.dart';

class ManageHeadsScreen extends StatefulWidget {
  const ManageHeadsScreen({super.key});

  @override
  State<ManageHeadsScreen> createState() => _ManageHeadsScreenState();
}

class _ManageHeadsScreenState extends State<ManageHeadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text(
          'Manage Heads',
          style: TextStyle(fontFamily: 'Gilroy-Bold'),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: const Color(0xFFF4F7FC),
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Heads').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No Heads found.'));
          }

          final allDocs = snapshot.data!.docs;
          final totalHeads = allDocs.length;

          var filteredDocs =
              allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final fullName =
                    (data['fullName'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                final madarsaName =
                    (data['madarsaName'] as String? ?? '').toLowerCase();
                return fullName.contains(_searchQuery) ||
                    email.contains(_searchQuery) ||
                    madarsaName.contains(_searchQuery);
              }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or madarsa...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              _buildCounterCard(totalHeads),
              Expanded(
                child:
                    filteredDocs.isEmpty
                        ? const Center(child: Text('No matching Heads found.'))
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            return _HeadListTile(headDoc: filteredDocs[index]);
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCounterCard(int count) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: const Color(0xFF1B263B).withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(
              Icons.people_alt_outlined,
              color: Color(0xFF1B263B),
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Total Registered Heads',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1B263B),
              ),
            ),
            const Spacer(),
            Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                fontFamily: 'Gilroy-Bold',
                color: Color(0xFF1B263B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeadListTile extends StatelessWidget {
  final QueryDocumentSnapshot headDoc;
  const _HeadListTile({required this.headDoc});

  @override
  Widget build(BuildContext context) {
    final data = headDoc.data() as Map<String, dynamic>;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        title: Text(
          data['fullName'] ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['madarsaName'] ?? 'Madarsa Name N/A'),
            Text(
              data['email'] ?? 'Email N/A',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              'ID: ${data['hucId'] ?? 'N/A'}'.toUpperCase(),
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HeadDetailsScreen(headId: headDoc.id),
            ),
          );
        },
      ),
    );
  }
}

class HeadDetailsScreen extends StatefulWidget {
  final String headId;
  const HeadDetailsScreen({super.key, required this.headId});

  @override
  State<HeadDetailsScreen> createState() => _HeadDetailsScreenState();
}

class _HeadDetailsScreenState extends State<HeadDetailsScreen> {
  final _fullNameController = TextEditingController();
  final _madarsaNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _townCityController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateController = TextEditingController();
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _initialHeadName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadHeadData();
  }

  Future<void> _loadHeadData() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('Heads')
              .doc(widget.headId)
              .get();
      if (mounted && doc.exists) {
        final data = doc.data()!;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        _fullNameController.text = data['fullName'] ?? '';
        _madarsaNameController.text = data['madarsaName'] ?? '';
        _phoneController.text = data['phoneNumber'] ?? '';
        _addressLine1Controller.text = address['line1'] ?? '';
        _townCityController.text = address['townCity'] ?? '';
        _districtController.text = address['district'] ?? '';
        _stateController.text = address['state'] ?? '';
        _panController.text = data['panCard'] ?? '';
        _aadhaarController.text = data['aadhaarNumber'] ?? '';

        setState(() {
          _initialHeadName = data['fullName'] ?? 'Details';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) CustomPopup.show(context, "Failed to load details: $e");
    }
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final updatedData = {
        'fullName': _fullNameController.text.trim(),
        'madarsaName': _madarsaNameController.text.trim(),
        'panCard': _panController.text.trim(),
        'aadhaarNumber': _aadhaarController.text.trim(),
        'address': {
          'line1': _addressLine1Controller.text.trim(),
          'townCity': _townCityController.text.trim(),
          'district': _districtController.text.trim(),
          'state': _stateController.text.trim(),
        },
      };

      await FirebaseFirestore.instance
          .collection('Heads')
          .doc(widget.headId)
          .update(updatedData);

      if (mounted) {
        CustomPopup.show(context, "Details updated successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) CustomPopup.show(context, "Failed to update: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _initialHeadName,
          style: const TextStyle(fontFamily: 'Gilroy-Bold'),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSectionHeader("Basic Details"),
                  _buildTextField(
                    controller: _fullNameController,
                    label: "Full Name",
                    icon: Icons.person_outline,
                  ),
                  _buildTextField(
                    controller: _madarsaNameController,
                    label: "Madarsa Name",
                    icon: Icons.school_outlined,
                  ),
                  _buildTextField(
                    controller: _phoneController,
                    label: "Phone Number",
                    icon: Icons.phone_outlined,
                    readOnly: true,
                  ),
                  _buildSectionHeader("Address Details"),
                  _buildTextField(
                    controller: _addressLine1Controller,
                    label: "Flat, Building/Apartment",
                    icon: Icons.location_on_outlined,
                  ),
                  _buildTextField(
                    controller: _townCityController,
                    label: "Town/City",
                    icon: Icons.location_city_outlined,
                  ),
                  _buildTextField(
                    controller: _districtController,
                    label: "District",
                    icon: Icons.map_outlined,
                  ),
                  _buildTextField(
                    controller: _stateController,
                    label: "State",
                    icon: Icons.flag_outlined,
                  ),
                  _buildSectionHeader("Identification Details"),
                  _buildTextField(
                    controller: _aadhaarController,
                    label: "Aadhaar Number",
                    icon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                  ),
                  _buildTextField(
                    controller: _panController,
                    label: "PAN Card",
                    icon: Icons.credit_card,
                    textCapitalization: TextCapitalization.characters,
                    formatter: [UpperCaseTextFormatter()],
                    maxLength: 10,
                  ),
                  const SizedBox(height: 30),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isSaving ? null : _saveChanges,
                    child: Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                              : const Text(
                                "Save Changes",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'Gilroy-Bold',
          color: Colors.black.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: formatter,
        textCapitalization: textCapitalization,
        style: TextStyle(
          color: readOnly ? Colors.grey.shade700 : Colors.black,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          counterText: "",
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          filled: true,
          prefixIcon: Icon(icon, color: Colors.black.withAlpha(204)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF1B263B), width: 1.5),
          ),
        ),
      ),
    );
  }
}