import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Data/loader.dart';

class PreviousSessionsScreen extends StatefulWidget {
  final String headUid;
  const PreviousSessionsScreen({super.key, required this.headUid});

  @override
  State<PreviousSessionsScreen> createState() => _PreviousSessionsScreenState();
}

class _PreviousSessionsScreenState extends State<PreviousSessionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchPreviousSessions();
  }

  Future<void> _fetchPreviousSessions() async {
    setState(() => _isLoading = true);
    try {
      final now = Timestamp.now();
      final snapshot =
          await FirebaseFirestore.instance
              .collection('sessions')
              .where('headUid', isEqualTo: widget.headUid)
              .where('endDate', isLessThan: now)
              .orderBy('endDate', descending: true)
              .get();

      _sessions =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'course': data['course'] ?? 'N/A',
              'duration': data['duration'] ?? 'N/A',
              'term': data['term'] ?? 'N/A',
              'startDate': (data['startDate'] as Timestamp).toDate(),
              'endDate': (data['endDate'] as Timestamp).toDate(),
            };
          }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to fetch sessions: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Previous Sessions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontFamily: 'Gilroy-Bold',
          color: Colors.black,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: GradientSpinner())
              : _sessions.isEmpty
              ? const Center(
                child: Text(
                  'No previous sessions found.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return _buildSessionCard(session);
                },
              ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session['course']} - ${session['duration']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Gilroy-Bold',
              ),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.tag, 'Term:', session['term']),
            const SizedBox(height: 4),
            _buildDetailRow(
              Icons.date_range,
              'Period:',
              '${DateFormat('d MMM yyyy').format(session['startDate'])} - ${DateFormat('d MMM yyyy').format(session['endDate'])}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.redAccent, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }
}
