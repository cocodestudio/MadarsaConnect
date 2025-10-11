import 'package:flutter/material.dart';
import 'package:madarsaConnect/Home%20Screen/searchable_items.dart';

class SearchOverlayScreen extends StatefulWidget {
  const SearchOverlayScreen({super.key});

  @override
  State<SearchOverlayScreen> createState() => _SearchOverlayScreenState();
}

class _SearchOverlayScreenState extends State<SearchOverlayScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<SearchableItem> _recentSearches = [];
  final List<SearchableItem> _allFields = allSearchableItems;

  List<SearchableItem> _filteredFields = [];

  @override
  void initState() {
    super.initState();
    _filteredFields = _allFields;
    _controller.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    String input = _controller.text.toLowerCase();

    setState(() {
      if (input.isEmpty) {
        _filteredFields = _allFields;
      } else {
        _filteredFields = _allFields
            .where((item) =>
        item.title.toLowerCase().contains(input) ||
            item.subtitle.toLowerCase().contains(input))
            .toList();
      }
    });
  }

  void _onFieldTapped(SearchableItem item) {
    if (!_recentSearches.contains(item)) {
      setState(() {
        _recentSearches.remove(item);
        _recentSearches.insert(0, item);
        if (_recentSearches.length > 10) {
          _recentSearches.removeLast();
        }
      });
    }
    Navigator.pop(context);
    Navigator.pushNamed(context, item.route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Search for...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _controller.text.isEmpty
                    ? _buildRecentSearches()
                    : _buildSuggestions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_filteredFields.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredFields.length,
      itemBuilder: (context, index) {
        final item = _filteredFields[index];
        return ListTile(
          leading: Icon(item.icon),
          title: Text(item.title),
          subtitle: Text(item.subtitle),
          onTap: () => _onFieldTapped(item),
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return const Center(
        child: Text(
          'Start typing to search...',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Searches',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _recentSearches.clear();
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        const Divider(height: 0),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final item = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                onTap: () => _onFieldTapped(item),
              );
            },
          ),
        ),
      ],
    );
  }
}