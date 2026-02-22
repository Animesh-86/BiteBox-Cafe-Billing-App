import 'dart:io';

void main() {
  final dir = Directory(
    'c:\\CipherVault\\Code\\Projects\\BiteBox-Cafe-Billing-App\\Hangout Spot\\lib\\ui\\screens\\analytics',
  );
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  final themeMap = {
    'AnalyticsTheme.headingLarge':
        'Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AnalyticsTheme.primaryText)',
    'AnalyticsTheme.headingMedium':
        'Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AnalyticsTheme.primaryText)',
    'AnalyticsTheme.headingSmall':
        'Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: AnalyticsTheme.primaryText)',
    'AnalyticsTheme.subtitle':
        'Theme.of(context).textTheme.bodyMedium?.copyWith(color: AnalyticsTheme.secondaryText)',
    'AnalyticsTheme.numberLarge':
        'Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: AnalyticsTheme.primaryGold)',
    'AnalyticsTheme.numberMedium':
        'Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AnalyticsTheme.primaryGold)',
  };

  for (final file in files) {
    if (file.path.contains('analytics_theme.dart')) continue;
    String content = file.readAsStringSync();
    bool changed = false;

    // Remove `const` before `Text` if it uses AnalyticsTheme typography inside
    content = content.replaceAllMapped(
      RegExp(
        r'const\s+(Text\([^;\{\}]*?AnalyticsTheme\.(headingLarge|headingMedium|headingSmall|subtitle|numberLarge|numberMedium)[^;\{\}]*?\))',
      ),
      (match) => match.group(1)!,
    );

    for (final entry in themeMap.entries) {
      if (content.contains(entry.key)) {
        content = content.replaceAll(entry.key, entry.value);
        changed = true;
      }
    }

    if (changed || content != file.readAsStringSync()) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
