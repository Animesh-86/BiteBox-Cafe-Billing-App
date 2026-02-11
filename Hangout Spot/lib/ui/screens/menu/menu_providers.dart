import 'package:flutter_riverpod/flutter_riverpod.dart';

// Local state for Admin Menu Selection
final adminSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final menuItemSearchProvider = StateProvider<String>((ref) => '');
