import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class DataProcessingPanel extends StatefulWidget {
  final bool isProcessing;

  const DataProcessingPanel({
    super.key,
    required this.isProcessing,
  });

  @override
  State<DataProcessingPanel> createState() => _DataProcessingPanelState();
}

class _DataProcessingPanelState extends State<DataProcessingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _updateTimer;
  
  final List<ProcessingItem> _items = [];
  int _totalScanned = 0;
  int _parkingSlotsFound = 0;
  double _avgPrice = 0.0;
  double _processingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    if (widget.isProcessing) {
      _startProcessing();
    }
  }

  @override
  void didUpdateWidget(DataProcessingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessing && !oldWidget.isProcessing) {
      _startProcessing();
    } else if (!widget.isProcessing && oldWidget.isProcessing) {
      _stopProcessing();
    }
  }

  void _startProcessing() {
    _items.clear();
    _totalScanned = 0;
    _parkingSlotsFound = 0;
    _avgPrice = 0.0;
    _processingProgress = 0.0;

    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        // Update progress
        _processingProgress = (_processingProgress + 0.02).clamp(0.0, 1.0);
        
        // Simulate scanning
        _totalScanned += math.Random().nextInt(5) + 1;
        
        // Randomly find parking slots
        if (math.Random().nextDouble() > 0.7) {
          _parkingSlotsFound++;
          _avgPrice = 40 + math.Random().nextDouble() * 60;
        }

        // Add processing items
        if (_items.length < 6 && math.Random().nextDouble() > 0.5) {
          _items.insert(0, ProcessingItem(
            text: _getRandomProcessingText(),
            timestamp: DateTime.now(),
          ));
        }

        // Remove old items
        if (_items.length > 6) {
          _items.removeLast();
        }
      });

      if (_processingProgress >= 1.0) {
        timer.cancel();
      }
    });
  }

  void _stopProcessing() {
    _updateTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _items.clear();
        });
      }
    });
  }

  String _getRandomProcessingText() {
    final texts = [
      'Scanning sector ${math.Random().nextInt(100)}...',
      'Analyzing parking availability...',
      'Checking real-time occupancy...',
      'Calculating optimal routes...',
      'Processing pricing data...',
      'Validating accessibility...',
      'Comparing alternatives...',
      'Fetching live updates...',
      'Computing distance matrix...',
      'Evaluating traffic conditions...',
    ];
    return texts[math.Random().nextInt(texts.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isProcessing && _items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: widget.isProcessing ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PROCESSING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_processingProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.blue[300],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _processingProgress,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              Row(
                children: [
                  _buildStat('Scanned', '$_totalScanned', Icons.radar),
                  const SizedBox(width: 16),
                  _buildStat('Found', '$_parkingSlotsFound', Icons.local_parking),
                  const SizedBox(width: 16),
                  _buildStat('Avg ₹', '${_avgPrice.toInt()}', Icons.currency_rupee),
                ],
              ),
              const SizedBox(height: 16),

              // Processing log
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 1,
                  ),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final age = DateTime.now().difference(item.timestamp).inMilliseconds;
                    final opacity = (1.0 - (age / 3000)).clamp(0.3, 1.0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(opacity),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.text,
                              style: TextStyle(
                                color: Colors.green[300]!.withOpacity(opacity),
                                fontSize: 10,
                                fontFamily: 'Courier',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: Colors.blue[300]),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProcessingItem {
  final String text;
  final DateTime timestamp;

  ProcessingItem({
    required this.text,
    required this.timestamp,
  });
}
