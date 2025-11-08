import 'package:flutter/material.dart';

class SearchFiltersSheet extends StatefulWidget {
  final double maxDistance;
  final double maxPrice;
  final bool requiresEV;
  final bool requiresHandicap;
  final List<String> preferredTypes;
  final Function(double, double, bool, bool, List<String>) onApply;

  const SearchFiltersSheet({
    super.key,
    required this.maxDistance,
    required this.maxPrice,
    required this.requiresEV,
    required this.requiresHandicap,
    required this.preferredTypes,
    required this.onApply,
  });

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  late double _maxDistance;
  late double _maxPrice;
  late bool _requiresEV;
  late bool _requiresHandicap;
  late List<String> _preferredTypes;

  final List<String> _availableTypes = [
    'mall',
    'street',
    'residential',
    'commercial',
    'airport',
  ];

  @override
  void initState() {
    super.initState();
    _maxDistance = widget.maxDistance;
    _maxPrice = widget.maxPrice;
    _requiresEV = widget.requiresEV;
    _requiresHandicap = widget.requiresHandicap;
    _preferredTypes = List.from(widget.preferredTypes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Filters',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Max Distance
                  Text(
                    'Maximum Distance',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _maxDistance,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          activeColor: const Color(0xFF000000),
                          label: '${_maxDistance.toStringAsFixed(1)} km',
                          onChanged: (value) {
                            setState(() {
                              _maxDistance = value;
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_maxDistance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Max Price
                  Text(
                    'Maximum Price per Hour',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _maxPrice,
                          min: 10.0,
                          max: 200.0,
                          divisions: 38,
                          activeColor: const Color(0xFF000000),
                          label: '₹${_maxPrice.toStringAsFixed(0)}',
                          onChanged: (value) {
                            setState(() {
                              _maxPrice = value;
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${_maxPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Special Requirements
                  Text(
                    'Special Requirements',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildSwitchTile(
                    icon: Icons.ev_station,
                    title: 'EV Charging',
                    subtitle: 'Requires electric vehicle charging',
                    value: _requiresEV,
                    onChanged: (value) {
                      setState(() {
                        _requiresEV = value;
                      });
                    },
                  ),

                  const SizedBox(height: 8),

                  _buildSwitchTile(
                    icon: Icons.accessible,
                    title: 'Handicap Access',
                    subtitle: 'Requires handicap accessibility',
                    value: _requiresHandicap,
                    onChanged: (value) {
                      setState(() {
                        _requiresHandicap = value;
                      });
                    },
                  ),

                  const SizedBox(height: 32),

                  // Preferred Types
                  Text(
                    'Preferred Parking Types',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTypes.map((type) {
                      final isSelected = _preferredTypes.contains(type);
                      return FilterChip(
                        label: Text(_capitalizeFirst(type)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _preferredTypes.add(type);
                            } else {
                              _preferredTypes.remove(type);
                            }
                          });
                        },
                        selectedColor: Colors.black,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.grey[200],
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          _maxDistance,
                          _maxPrice,
                          _requiresEV,
                          _requiresHandicap,
                          _preferredTypes,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF000000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF000000),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _maxDistance = 5.0;
      _maxPrice = 100.0;
      _requiresEV = false;
      _requiresHandicap = false;
      _preferredTypes.clear();
    });
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
