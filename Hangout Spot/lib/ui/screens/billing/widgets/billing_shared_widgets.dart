import 'package:flutter/material.dart';
import 'billing_styles.dart';

/// Payment Chip Widget
class PaymentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : billingSurfaceVariant(context, darkOpacity: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : billingOutline(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : billingMutedText(context),
          ),
        ),
      ),
    );
  }
}

// Redemption Dialog
class RedemptionDialog extends StatefulWidget {
  final String customerName;
  final int rewardBalance;
  final int maxRedemption;
  final double currentTotal;
  final Function(int) onRedeem;
  final VoidCallback onSkip;

  const RedemptionDialog({
    super.key,
    required this.customerName,
    required this.rewardBalance,
    required this.maxRedemption,
    required this.currentTotal,
    required this.onRedeem,
    required this.onSkip,
  });

  @override
  State<RedemptionDialog> createState() => _RedemptionDialogState();
}

class _RedemptionDialogState extends State<RedemptionDialog> {
  late TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController();
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Redeem Reward Points'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customer: ${widget.customerName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Points: ${widget.rewardBalance}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max Redemption: ₹${widget.maxRedemption}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Total: ₹${widget.currentTotal.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Points to Redeem:'),
            const SizedBox(height: 8),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixText: 'points',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
        ElevatedButton(
          onPressed: () {
            final points = int.tryParse(_pointsController.text) ?? 0;
            if (points <= 0) {
              widget.onSkip();
              return;
            }
            if (points > widget.rewardBalance) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Insufficient points')),
              );
              return;
            }
            widget.onRedeem(points);
          },
          child: const Text('Redeem'),
        ),
      ],
    );
  }
}
