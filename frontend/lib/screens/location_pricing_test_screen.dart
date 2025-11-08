import 'dart:async';
import 'package:flutter/material.dart';
import '../examples/location_pricing_example.dart';

/// Simple test screen to demo dynamic pricing for location 10.7681657, 78.8183062
class LocationPricingTestScreen extends StatefulWidget {
  const LocationPricingTestScreen({Key? key}) : super(key: key);

  @override
  State<LocationPricingTestScreen> createState() => _LocationPricingTestScreenState();
}

class _LocationPricingTestScreenState extends State<LocationPricingTestScreen> {
  String _output = 'Tap a button to test dynamic pricing...';
  bool _loading = false;

  void _runTest(Future<void> Function() testFunction, String testName) async {
    setState(() {
      _loading = true;
      _output = 'Running $testName...\n';
    });

    try {
      await testFunction();
      
      setState(() {
        _loading = false;
        if (_output == 'Running $testName...\n') {
          _output += '\n✅ Test completed! Check console for output.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _output += '\n❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location Pricing Test'),
            Text(
              '10.7681657, 78.8183062',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Location Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'Test Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Latitude', '10.7681657'),
                  _buildInfoRow('Longitude', '78.8183062'),
                  _buildInfoRow('City', 'Trichy (Tiruchirappalli)'),
                  _buildInfoRow('Area', 'Srirangam'),
                ],
              ),
            ),
          ),

          // Test Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _runTest(
                            quickTest,
                            'Quick Test',
                          ),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Quick Test'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _runTest(
                            () => LocationPricingExample()
                                .exampleBasicLocationPricing(),
                            'Basic Pricing',
                          ),
                  icon: const Icon(Icons.money),
                  label: const Text('Basic Pricing'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _runTest(
                            () => LocationPricingExample()
                                .exampleHighDemandPricing(),
                            'High Demand (Surge)',
                          ),
                  icon: const Icon(Icons.trending_up),
                  label: const Text('High Demand (Surge)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _runTest(
                            () => LocationPricingExample()
                                .exampleLowDemandPricing(),
                            'Low Demand (Discount)',
                          ),
                  icon: const Icon(Icons.trending_down),
                  label: const Text('Low Demand (Discount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _runTest(
                            () => LocationPricingExample().exampleCompareTypes(),
                            'Compare Types',
                          ),
                  icon: const Icon(Icons.compare),
                  label: const Text('Compare Parking Types'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _runTest(
                            () => LocationPricingExample().runAllExamples(),
                            'All Examples',
                          ),
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Run All Examples'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Output Display
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Testing dynamic pricing...'),
                          ],
                        ),
                      )
                    : Text(
                        _output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
