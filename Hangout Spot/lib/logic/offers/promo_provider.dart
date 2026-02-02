import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/local/db/app_database.dart';
import 'package:hangout_spot/data/providers/database_provider.dart';
import 'package:hangout_spot/logic/billing/cart_provider.dart';

const String PROMO_ENABLED_KEY = 'promo_enabled';
const String PROMO_TITLE_KEY = 'promo_title';
const String PROMO_START_KEY = 'promo_start';
const String PROMO_END_KEY = 'promo_end';
const String PROMO_DISCOUNT_PERCENT_KEY = 'promo_discount_percent';
const String PROMO_BUNDLE_ITEM_IDS_KEY = 'promo_bundle_item_ids';

class PromoSettings {
  final bool enabled;
  final String title;
  final DateTime? start;
  final DateTime? end;
  final double discountPercent;
  final List<String> bundleItemIds;

  const PromoSettings({
    required this.enabled,
    required this.title,
    required this.start,
    required this.end,
    required this.discountPercent,
    required this.bundleItemIds,
  });

  bool get isActive {
    if (!enabled) return false;
    final now = DateTime.now();
    if (start != null && now.isBefore(start!)) return false;
    if (end != null && now.isAfter(end!)) return false;
    return true;
  }

  factory PromoSettings.fromRows(Iterable<Setting> rows) {
    final map = {for (final s in rows) s.key: s.value};
    final enabled = (map[PROMO_ENABLED_KEY] ?? 'false') == 'true';
    final title = map[PROMO_TITLE_KEY] ?? 'Special Offer';
    final start = _parseDate(map[PROMO_START_KEY]);
    final end = _parseDate(map[PROMO_END_KEY]);
    final discountPercent =
        double.tryParse(map[PROMO_DISCOUNT_PERCENT_KEY] ?? '0') ?? 0.0;
    final bundleItemIds = (map[PROMO_BUNDLE_ITEM_IDS_KEY] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return PromoSettings(
      enabled: enabled,
      title: title,
      start: start,
      end: end,
      discountPercent: discountPercent,
      bundleItemIds: bundleItemIds,
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }
}

final promoSettingsProvider = StreamProvider<PromoSettings>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.settings)
    ..where(
      (tbl) => tbl.key.isIn([
        PROMO_ENABLED_KEY,
        PROMO_TITLE_KEY,
        PROMO_START_KEY,
        PROMO_END_KEY,
        PROMO_DISCOUNT_PERCENT_KEY,
        PROMO_BUNDLE_ITEM_IDS_KEY,
      ]),
    );

  return query.watch().map(PromoSettings.fromRows);
});

final promoDiscountProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  final promoAsync = ref.watch(promoSettingsProvider);

  return promoAsync.maybeWhen(
    data: (promo) => _calculatePromoDiscount(cart, promo),
    orElse: () => 0.0,
  );
});

double _calculatePromoDiscount(CartState cart, PromoSettings promo) {
  if (!promo.isActive) return 0.0;
  if (promo.bundleItemIds.isEmpty) return 0.0;
  if (promo.discountPercent <= 0) return 0.0;

  final cartItemIds = cart.items.map((i) => i.item.id).toSet();
  final hasAll = promo.bundleItemIds.every(cartItemIds.contains);
  if (!hasAll) return 0.0;

  final bundleTotal = cart.items
      .where((i) => promo.bundleItemIds.contains(i.item.id))
      .fold<double>(0.0, (sum, i) => sum + (i.item.price * i.quantity));

  if (bundleTotal <= 0) return 0.0;
  return (bundleTotal * (promo.discountPercent / 100)).clamp(0.0, bundleTotal);
}
