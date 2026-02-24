import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/repositories/customer_repository.dart';
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

class CartCustomerSection extends ConsumerStatefulWidget {
  final bool compact;
  const CartCustomerSection({super.key, this.compact = false});

  @override
  ConsumerState<CartCustomerSection> createState() =>
      _CartCustomerSectionState();
}

class _CartCustomerSectionState extends ConsumerState<CartCustomerSection> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  ProviderSubscription<CartState>? _cartListener;

  String _query = '';
  bool _showSuggestions = false;

  bool get _isEditing => _nameFocus.hasFocus || _phoneFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_handleFocusChange);
    _phoneFocus.addListener(_handleFocusChange);

    final cart = ref.read(cartProvider);
    _nameController.text = cart.customer?.name ?? '';
    _phoneController.text = cart.customer?.phone ?? '';

    _cartListener = ref.listenManual<CartState>(cartProvider, (prev, next) {
      if (_isEditing) return;
      final customer = next.customer;
      _nameController.text = customer?.name ?? '';
      _phoneController.text = customer?.phone ?? '';
    });
  }

  @override
  void dispose() {
    _cartListener?.close();
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_isEditing && mounted) {
      setState(() => _showSuggestions = false);
    }
  }

  Future<void> _saveOrSelectCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final notifier = ref.read(cartProvider.notifier);

    if (name.isEmpty && phone.isEmpty) {
      notifier.clearCustomerSelection();
      if (mounted) setState(() => _showSuggestions = false);
      return;
    }

    final repo = ref.read(customerRepositoryProvider);
    Customer? existing;

    if (phone.isNotEmpty) {
      existing = await repo.getCustomerByPhone(phone);
    }
    existing ??= name.isNotEmpty ? await repo.getCustomerByName(name) : null;

    if (existing != null) {
      var updated = existing;
      if (name.isNotEmpty && existing.name != name) {
        updated = existing.copyWith(name: name);
        await repo.updateCustomer(updated);
      }
      if (phone.isNotEmpty && existing.phone != phone) {
        updated = updated.copyWith(phone: drift.Value(phone));
        await repo.updateCustomer(updated);
      }
      notifier.setCustomer(updated);
    } else {
      final displayName = name.isNotEmpty ? name : phone;
      try {
        await repo.addCustomer(
          CustomersCompanion(
            id: drift.Value(const Uuid().v4()),
            name: drift.Value(displayName),
            phone: drift.Value(phone.isEmpty ? null : phone),
            discountPercent: const drift.Value(0.0),
          ),
        );
      } catch (_) {
        // Ignore duplicate insert errors and attempt to fetch the existing one.
      }

      final created = phone.isNotEmpty
          ? await repo.getCustomerByPhone(phone)
          : await repo.getCustomerByName(displayName);
      if (created != null) {
        notifier.setCustomer(created);
      }
    }

    if (mounted) setState(() => _showSuggestions = false);
  }

  void _selectCustomer(Customer customer) {
    _nameController.text = customer.name;
    _phoneController.text = customer.phone ?? '';
    ref.read(cartProvider.notifier).setCustomer(customer);
    setState(() => _showSuggestions = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final repo = ref.read(customerRepositoryProvider);
    final query = _query.trim();

    final suggestionsStream = query.isEmpty
        ? Stream.value(<Customer>[])
        : repo.watchCustomers(query);

    final fieldSpacing = widget.compact ? 6.0 : 12.0;
    InputDecoration _compactDecoration(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );

    return Container(
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
                Icons.person_outline,
                size: 18,
                color: billingMutedText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customer',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: billingMutedText(context),
                  ),
                ),
              ),
              if (cart.customer != null)
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clearCustomerSelection();
                    _nameController.clear();
                    _phoneController.clear();
                    setState(() => _showSuggestions = false);
                  },
                  child: const Text('Clear'),
                ),
              TextButton.icon(
                onPressed: () => showCustomerSelect(context, ref),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Browse'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.compact)
            Column(
              children: [
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  decoration: _compactDecoration('Name'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textInputAction: TextInputAction.next,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _showSuggestions = value.trim().isNotEmpty;
                    });
                  },
                ),
                SizedBox(height: fieldSpacing),
                TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  decoration: _compactDecoration('Phone'),
                  style: Theme.of(context).textTheme.bodySmall,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                      _showSuggestions = value.trim().isNotEmpty;
                    });
                  },
                  onSubmitted: (_) => _saveOrSelectCustomer(),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                        _showSuggestions = value.trim().isNotEmpty;
                      });
                    },
                  ),
                ),
                SizedBox(width: fieldSpacing),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                        _showSuggestions = value.trim().isNotEmpty;
                      });
                    },
                    onSubmitted: (_) => _saveOrSelectCustomer(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _saveOrSelectCustomer,
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Use Customer'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              if (cart.customer != null)
                Flexible(
                  child: Row(
                    children: [
                      Text(
                        '${cart.customer!.name} (${cart.customer!.totalVisits} visits)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: billingMutedText(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 6),
                      FutureBuilder<bool>(
                        future: ref.watch(isRewardSystemEnabledProvider.future),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ref
                                .watch(
                                  customerRewardBalanceProvider(
                                    cart.customer!.id,
                                  ),
                                )
                                .when(
                                  data: (balance) => Text(
                                    '${balance.toInt()} pts',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  loading: () => Text(
                                    '... pts',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  error: (_, __) => Text(
                                    '0 pts',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
          StreamBuilder<List<Customer>>(
            stream: suggestionsStream,
            builder: (context, snapshot) {
              final customers = snapshot.data ?? [];
              if (!_showSuggestions || customers.isEmpty) {
                return const SizedBox.shrink();
              }

              final limited = customers.take(6).toList();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: billingSurface(context, darkOpacity: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: billingOutline(context)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final customer = limited[index];
                    return ListTile(
                      dense: true,
                      title: Text(customer.name),
                      subtitle: Text(customer.phone ?? 'No phone'),
                      trailing: Text('${customer.totalVisits} visits'),
                      onTap: () => _selectCustomer(customer),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: limited.length,
                ),
              );
            },
          ),
        ],
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
        // Payment Method
        Container(
          padding: const EdgeInsets.all(8),
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
              const SizedBox(height: 6),
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
              if (cart.paymentMode == 'Split') const SizedBox(height: 8),
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
                            vertical: 6,
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
                            vertical: 6,
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
        // Discount vs Total grid (tightened to avoid overflow)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: billingShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.discount,
                          size: 18,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Discount %',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      keyboardType: TextInputType.number,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: billingText(context),
                      ),
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
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                      onChanged: (value) {
                        final percent = double.tryParse(value) ?? 0.0;
                        final discountAmount = cart.subtotal * (percent / 100);
                        notifier.setManualDiscount(discountAmount);
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Applied: -₹${nonPromoDiscount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.green.shade800,
                      ),
                    ),
                    if (cart.promoDiscount > 0)
                      Text(
                        'Promo: -₹${cart.promoDiscount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: billingShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: billingMutedText(context)),
                        ),
                        Text(
                          "₹${cart.subtotal.toStringAsFixed(2)}",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: billingMutedText(context)),
                        ),
                      ],
                    ),
                    if (cart.taxAmount > 0) const SizedBox(height: 4),
                    if (cart.taxAmount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tax',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: billingMutedText(context)),
                          ),
                          Text(
                            "+₹${cart.taxAmount.toStringAsFixed(2)}",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: billingMutedText(context)),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: billingText(context),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          "₹${cart.grandTotal.toStringAsFixed(2)}",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                        ),
                      ],
                    ),
                    if (cart.customer != null) ...[
                      const SizedBox(height: 8),
                      ref
                          .watch(
                            customerRewardBalanceProvider(cart.customer!.id),
                          )
                          .when(
                            data: (balance) {
                              if (balance <= 0) return const SizedBox.shrink();
                              return Text(
                                'Rewards: ${balance.toInt()} pts',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: Colors.blue.shade800),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: cart.items.isNotEmpty
                    ? () => holdOrder(context, ref)
                    : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: billingOutline(context)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
