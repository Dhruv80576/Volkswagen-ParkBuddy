import 'package:flutter/material.dart';
import '../models/parking_model.dart';

/// Widget to display dynamic pricing information for a parking slot
class DynamicPriceDisplay extends StatelessWidget {
  final ParkingSlot slot;
  final bool showDetails;

  const DynamicPriceDisplay({
    Key? key,
    required this.slot,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!slot.hasDynamicPricing) {
      // No dynamic pricing, show base price only
      return Row(
        children: [
          Text(
            '₹${slot.pricePerHour.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '/hr',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      );
    }

    // Has dynamic pricing
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price display
        Row(
          children: [
            // Strikethrough base price if different
            if (slot.dynamicPrice != slot.pricePerHour) ...[
              Text(
                '₹${slot.pricePerHour.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Dynamic price
            Text(
              '₹${slot.effectivePrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _getPriceColor(),
              ),
            ),
            const Text(
              '/hr',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Pricing indicator
            _buildPricingIndicator(),
          ],
        ),
        
        if (showDetails) ...[
          const SizedBox(height: 4),
          
          // Pricing details
          Row(
            children: [
              _buildPricingChip(),
              const SizedBox(width: 8),
              if (slot.demandLevel != null)
                _buildDemandChip(),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPricingIndicator() {
    IconData icon;
    Color color;
    
    if (slot.isDiscounted) {
      icon = Icons.trending_down;
      color = Colors.green;
    } else if (slot.isHighSurge) {
      icon = Icons.trending_up;
      color = Colors.red;
    } else if (slot.isPeakPricing) {
      icon = Icons.trending_up;
      color = Colors.orange;
    } else {
      return const SizedBox.shrink();
    }
    
    return Icon(icon, size: 18, color: color);
  }

  Widget _buildPricingChip() {
    String label;
    Color color;
    IconData icon;
    
    if (slot.isDiscounted) {
      label = '${(100 - slot.priceMultiplier! * 100).toInt()}% OFF';
      color = Colors.green;
      icon = Icons.local_offer;
    } else if (slot.isHighSurge) {
      label = '${((slot.priceMultiplier! - 1) * 100).toInt()}% Surge';
      color = Colors.red;
      icon = Icons.local_fire_department;
    } else if (slot.isPeakPricing) {
      label = 'Peak Hours';
      color = Colors.orange;
      icon = Icons.access_time;
    } else {
      label = 'Dynamic';
      color = Colors.blue;
      icon = Icons.auto_graph;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandChip() {
    final demandLevel = slot.demandLevel ?? 'medium';
    
    Color color;
    String label;
    IconData icon;
    
    switch (demandLevel) {
      case 'high':
        color = Colors.red;
        label = 'High Demand';
        icon = Icons.warning_amber_rounded;
        break;
      case 'low':
        color = Colors.green;
        label = 'Low Demand';
        icon = Icons.check_circle_outline;
        break;
      default:
        color = Colors.orange;
        label = 'Medium Demand';
        icon = Icons.info_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriceColor() {
    if (slot.isDiscounted) {
      return Colors.green;
    } else if (slot.isHighSurge) {
      return Colors.red;
    } else if (slot.isPeakPricing) {
      return Colors.orange;
    }
    return Colors.black;
  }
}

/// Compact version for list items
class CompactPriceDisplay extends StatelessWidget {
  final ParkingSlot slot;

  const CompactPriceDisplay({
    Key? key,
    required this.slot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (slot.hasDynamicPricing && slot.dynamicPrice != slot.pricePerHour)
          Text(
            '₹${slot.pricePerHour.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${slot.effectivePrice.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getPriceColor(),
              ),
            ),
            const Text(
              '/hr',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (slot.hasDynamicPricing) ...[
              const SizedBox(width: 4),
              _buildPriceIndicator(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPriceIndicator() {
    if (slot.isDiscounted) {
      return const Icon(Icons.trending_down, size: 16, color: Colors.green);
    } else if (slot.isHighSurge) {
      return const Icon(Icons.local_fire_department, size: 16, color: Colors.red);
    } else if (slot.isPeakPricing) {
      return const Icon(Icons.trending_up, size: 16, color: Colors.orange);
    }
    return const SizedBox.shrink();
  }

  Color _getPriceColor() {
    if (slot.isDiscounted) return Colors.green;
    if (slot.isHighSurge) return Colors.red;
    if (slot.isPeakPricing) return Colors.orange;
    return Colors.black;
  }
}
