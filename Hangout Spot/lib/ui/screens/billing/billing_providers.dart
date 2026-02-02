import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final sidebarFlexProvider = StateProvider<double>((ref) => 20.0);
final itemSearchQueryProvider = StateProvider<String>((ref) => '');
