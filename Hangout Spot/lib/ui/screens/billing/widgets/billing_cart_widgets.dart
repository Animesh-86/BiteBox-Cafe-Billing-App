import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_actions.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_shared_widgets.dart';
import 'package:hangout_spot/ui/screens/billing/widgets/billing_styles.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final CartNotifier notifier;

  const CartItemTile({super.key, required this.item, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => notifier.updateQuantity(item.id, item.quantity + 1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: billingSurface(context, darkOpacity: 0.06),
          borderRadius: BorderRadius.circular(8),
          boxShadow: billingShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.item.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: billingText(context),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                billingPricePill(context, "₹${item.total.toStringAsFixed(0)}"),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${item.item.price}",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: billingMutedText(context),
                      ),
                    ),
                    if (item.item.discountPercent > 0 ||
                        item.discountAmount > 0)
                      Text(
                        'Discount: ₹${item.discountAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade300,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: billingSurfaceVariant(context, darkOpacity: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            notifier.updateQuantity(item.id, item.quantity - 1),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.remove,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "${item.quantity}",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: billingText(context),
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            notifier.updateQuantity(item.id, item.quantity + 1),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CartFooter extends ConsumerWidget {
  const CartFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final nonPromoDiscount = (cart.totalDiscount - cart.promoDiscount).clamp(
      0.0,
      cart.totalDiscount,
    );

    return Column(
      children: [
        // Discount Input
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: billingSurfaceVariant(context, darkOpacity: 0.14),
            borderRadius: BorderRadius.circular(8),
            boxShadow: billingShadow(context),
          ),
          child: Row(
            children: [
              Icon(Icons.discount, size: 18, color: billingMutedText(context)),
              const SizedBox(width: 8),
              Text(
                'Discount %',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: billingMutedText(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: billingText(context)),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: billingMutedText(context).withOpacity(0.6),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: billingOutline(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: billingOutline(context)),
                    ),
                  ),
                  onChanged: (value) {
                    final percent = double.tryParse(value) ?? 0.0;
                    final discountAmount = cart.subtotal * (percent / 100);
                    notifier.setManualDiscount(discountAmount);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Payment Method
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: billingSurfaceVariant(context, darkOpacity: 0.14),
            borderRadius: BorderRadius.circular(8),
            boxShadow: billingShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 18,
                    color: billingMutedText(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Method',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: billingMutedText(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  PaymentChip(
                    label: 'Cash',
                    isSelected: cart.paymentMode == 'Cash',
                    onTap: () => notifier.setPaymentMode('Cash'),
                  ),
                  PaymentChip(
                    label: 'UPI',
                    isSelected: cart.paymentMode == 'UPI',
                    onTap: () => notifier.setPaymentMode('UPI'),
                  ),
                  PaymentChip(
                    label: 'Split',
                    isSelected: cart.paymentMode == 'Split',
                    onTap: () => notifier.setPaymentMode('Split'),
                  ),
                ],
              ),
              if (cart.paymentMode == 'Split') const SizedBox(height: 10),
              if (cart.paymentMode == 'Split')
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: billingText(context),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Cash',
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: billingMutedText(context),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onChanged: (value) {
                          final cash = double.tryParse(value) ?? 0.0;
                          final upi = cart.grandTotal - cash;
                          notifier.setPaymentSplit(cash, upi > 0 ? upi : 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: cart.paidUPI > 0
                              ? cart.paidUPI.toStringAsFixed(2)
                              : '',
                        ),
                        keyboardType: TextInputType.number,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: billingText(context),
                        ),
                        decoration: InputDecoration(
                          labelText: 'UPI',
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: billingMutedText(context),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onChanged: (value) {
                          final upi = double.tryParse(value) ?? 0.0;
                          final cash = cart.grandTotal - upi;
                          notifier.setPaymentSplit(cash > 0 ? cash : 0, upi);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Price Breakdown
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: billingSurfaceVariant(context, darkOpacity: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: billingMutedText(context),
                    ),
                  ),
                  Text(
                    "₹${cart.subtotal.toStringAsFixed(2)}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: billingMutedText(context),
                    ),
                  ),
                ],
              ),
              if (cart.promoDiscount > 0) const SizedBox(height: 6),
              if (cart.promoDiscount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Promo',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: billingMutedText(context),
                      ),
                    ),
                    Text(
                      "-₹${cart.promoDiscount.toStringAsFixed(2)}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.pinkAccent),
                    ),
                  ],
                ),
              if (nonPromoDiscount > 0) const SizedBox(height: 6),
              if (nonPromoDiscount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: billingMutedText(context),
                      ),
                    ),
                    Text(
                      "-₹${nonPromoDiscount.toStringAsFixed(2)}",
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              if (cart.taxAmount > 0) const SizedBox(height: 6),
              if (cart.taxAmount > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tax',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: billingMutedText(context),
                      ),
                    ),
                    Text(
                      "+₹${cart.taxAmount.toStringAsFixed(2)}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: billingMutedText(context),
                      ),
                    ),
                  ],
                ),
              Divider(
                height: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: billingText(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "₹${cart.grandTotal.toStringAsFixed(2)}",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              // Show reward points if customer selected
              if (cart.customer != null) ...[
                const SizedBox(height: 12),
                ref
                    .watch(customerRewardBalanceProvider(cart.customer!.id))
                    .when(
                      data: (balance) {
                        if (balance <= 0) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reward Points',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.orange),
                                  ),
                                  Text(
                                    '${balance.toInt()} points available',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: billingText(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${(balance * 1.0).toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  if (balance >= MIN_REDEMPTION_POINTS)
                                    TextButton(
                                      onPressed: () =>
                                          showRedemptionDialog(context, ref),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Redeem',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: cart.items.isNotEmpty
                    ? () => holdOrder(context, ref)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: billingOutline(context)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Hold',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: cart.items.isNotEmpty
                    ? () => checkout(context, ref)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  'Print Bill',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
