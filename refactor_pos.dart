import 'dart:io';

void main() {
  final files = [
    'c:\\CipherVault\\Code\\Projects\\BiteBox-Cafe-Billing-App\\Hangout Spot\\lib\\ui\\screens\\billing\\widgets\\billing_cart_widgets.dart',
    'c:\\CipherVault\\Code\\Projects\\BiteBox-Cafe-Billing-App\\Hangout Spot\\lib\\ui\\screens\\billing\\widgets\\billing_cart_panel.dart',
    'c:\\CipherVault\\Code\\Projects\\BiteBox-Cafe-Billing-App\\Hangout Spot\\lib\\ui\\screens\\billing\\widgets\\billing_cart_mobile.dart',
  ];

  final replacements = {
    // billing_cart_widgets.dart & cart panels
    'style: TextStyle(\n                      fontWeight: FontWeight.bold,\n                      fontSize: 13,\n                      color: billingText(context),\n                    )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                      fontWeight: FontWeight.bold,\n                      color: billingText(context),\n                    )',
    'style: TextStyle(\n                        fontSize: 11,\n                        color: billingMutedText(context),\n                      )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                        color: billingMutedText(context),\n                      )',
    'style: TextStyle(\n                          fontSize: 10,\n                          color: Colors.orange.shade300,\n                          fontWeight: FontWeight.w500,\n                        )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                          color: Colors.orange.shade300,\n                          fontWeight: FontWeight.w500,\n                        )',
    'style: TextStyle(\n                            fontWeight: FontWeight.bold,\n                            fontSize: 13,\n                            color: billingText(context),\n                          )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                            fontWeight: FontWeight.bold,\n                            color: billingText(context),\n                          )',
    'style: TextStyle(\n                  fontSize: 12,\n                  color: billingMutedText(context),\n                )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                  color: billingMutedText(context),\n                )',
    'style: TextStyle(fontSize: 13, color: billingText(context))':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(color: billingText(context))',
    'style: TextStyle(\n                      fontSize: 12,\n                      color: billingMutedText(context),\n                    )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                      color: billingMutedText(context),\n                    )',
    'style: TextStyle(\n                          fontSize: 12,\n                          color: billingText(context),\n                        )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                          color: billingText(context),\n                        )',
    'style: TextStyle(\n                            fontSize: 11,\n                            color: billingMutedText(context),\n                          )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                            color: billingMutedText(context),\n                          )',
    'style: TextStyle(\n                        fontSize: 12,\n                        color: billingMutedText(context),\n                      )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                        color: billingMutedText(context),\n                      )',
    'style: const TextStyle(fontSize: 12, color: Colors.green)':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green)',
    'style: TextStyle(\n                      fontSize: 14,\n                      color: billingText(context),\n                      fontWeight: FontWeight.bold,\n                    )':
        'style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n                      color: billingText(context),\n                      fontWeight: FontWeight.bold,\n                    )',
    'style: TextStyle(\n                      fontWeight: FontWeight.bold,\n                      fontSize: 18,\n                      color: Theme.of(context).colorScheme.primary,\n                    )':
        'style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                      fontWeight: FontWeight.bold,\n                      color: Theme.of(context).colorScheme.primary,\n                    )',
    'style: TextStyle(\n                                      fontSize: 11,\n                                      color: Colors.orange,\n                                    )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                                      color: Colors.orange,\n                                    )',
    'style: TextStyle(\n                                      fontSize: 12,\n                                      color: billingText(context),\n                                      fontWeight: FontWeight.bold,\n                                    )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                                      color: billingText(context),\n                                      fontWeight: FontWeight.bold,\n                                    )',
    'style: const TextStyle(\n                                      fontSize: 12,\n                                      color: Colors.orange,\n                                      fontWeight: FontWeight.bold,\n                                    )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                                      color: Colors.orange,\n                                      fontWeight: FontWeight.bold,\n                                    )',
    'style: TextStyle(\n                                          fontSize: 11,\n                                          color: Colors.orange,\n                                          fontWeight: FontWeight.bold,\n                                        )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                                          color: Colors.orange,\n                                          fontWeight: FontWeight.bold,\n                                        )',
    'style: const TextStyle(fontSize: 13)':
        'style: Theme.of(context).textTheme.bodySmall',
    'style: TextStyle(\n                    fontSize: 13,\n                    fontWeight: FontWeight.bold,\n                    color: Theme.of(context).colorScheme.onPrimary,\n                  )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                    fontWeight: FontWeight.bold,\n                    color: Theme.of(context).colorScheme.onPrimary,\n                  )',

    // billing_cart_panel.dart specific
    'style: TextStyle(\n                          fontSize: 16,\n                          fontWeight: FontWeight.bold,\n                          color: Theme.of(context).colorScheme.onPrimary,\n                        )':
        'style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                          fontWeight: FontWeight.bold,\n                          color: Theme.of(context).colorScheme.onPrimary,\n                        )',
    'style: TextStyle(\n                                fontSize: 11,\n                                color: Theme.of(context).colorScheme.onPrimary,\n                              )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                                color: Theme.of(context).colorScheme.onPrimary,\n                              )',
    'style: TextStyle(\n                                  fontSize: 11,\n                                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),\n                                )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),\n                                )',
    'style: TextStyle(\n                            fontSize: 11,\n                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),\n                          )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),\n                          )',

    // billing_cart_mobile.dart specific
    'style: TextStyle(\n                    fontSize: 12,\n                    color: billingMutedText(context),\n                  )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                    color: billingMutedText(context),\n                  )',
    'style: TextStyle(\n                    fontSize: 16,\n                    fontWeight: FontWeight.bold,\n                    color: billingText(context),\n                  )':
        'style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                    fontWeight: FontWeight.bold,\n                    color: billingText(context),\n                  )',
    'style: TextStyle(\n                            fontSize: 18,\n                            fontWeight: FontWeight.bold,\n                            color: billingText(context),\n                          )':
        'style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                            fontWeight: FontWeight.bold,\n                            color: billingText(context),\n                          )',
    'style: TextStyle(\n                              fontSize: 18,\n                              fontWeight: FontWeight.bold,\n                              color: Theme.of(context).colorScheme.primary,\n                            )':
        'style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                              fontWeight: FontWeight.bold,\n                              color: Theme.of(context).colorScheme.primary,\n                            )',
    'style: const TextStyle(\n                                fontSize: 11,\n                                color: Colors.orange,\n                              )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                                color: Colors.orange,\n                              )',
    'style: TextStyle(\n                                  fontSize: 12,\n                                  color: billingText(context),\n                                  fontWeight: FontWeight.bold,\n                                )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                                  color: billingText(context),\n                                  fontWeight: FontWeight.bold,\n                                )',
    'style: const TextStyle(\n                                  fontSize: 12,\n                                  color: Colors.orange,\n                                  fontWeight: FontWeight.bold,\n                                )':
        'style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                                  color: Colors.orange,\n                                  fontWeight: FontWeight.bold,\n                                )',
    'style: const TextStyle(\n                                      fontSize: 11,\n                                      color: Colors.orange,\n                                      fontWeight: FontWeight.bold,\n                                    )':
        'style: Theme.of(context).textTheme.labelSmall?.copyWith(\n                                      color: Colors.orange,\n                                      fontWeight: FontWeight.bold,\n                                    )',
  };

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) continue;

    String content = file.readAsStringSync();

    // Fallback regex replacement for robust partial matches:
    content = content.replaceAllMapped(
      RegExp(r'const\s+(TextStyle\([^)]*fontSize:\s*\d+[^)]*\))'),
      (match) => match.group(1)!,
    );

    content = content.replaceAllMapped(
      RegExp(
        r'style:\s*TextStyle\(([\s\S]*?)fontSize:\s*(9|10|11|12|13|14|16|18)(,)?([\s\S]*?)\)',
      ),
      (match) {
        final before = match.group(1) ?? '';
        final sizeStr = match.group(2) ?? '12';
        final size = int.parse(sizeStr);
        final after = match.group(4) ?? '';

        String textThemeLabel = 'bodySmall';
        if (size <= 11)
          textThemeLabel = 'labelSmall';
        else if (size <= 13)
          textThemeLabel = 'bodySmall';
        else if (size == 14)
          textThemeLabel = 'bodyMedium';
        else if (size == 16)
          textThemeLabel = 'titleMedium';
        else if (size >= 18)
          textThemeLabel = 'titleLarge';

        final inside = [
          before.trim(),
          after.trim(),
        ].where((s) => s.isNotEmpty && s != ',').join(' ');

        // Clean inside
        String cleanInside = inside
            .replaceAll(RegExp(r'^,\s*|\s*,$'), '')
            .trim();
        if (cleanInside.startsWith(','))
          cleanInside = cleanInside.substring(1).trim();
        if (cleanInside.endsWith(','))
          cleanInside = cleanInside.substring(0, cleanInside.length - 1).trim();

        if (cleanInside.isEmpty) {
          return 'style: Theme.of(context).textTheme.$textThemeLabel';
        }
        return 'style: Theme.of(context).textTheme.$textThemeLabel?.copyWith($cleanInside)';
      },
    );

    // minor cleanup
    content = content.replaceAll('?.copyWith(, ', '?.copyWith(');
    content = content.replaceAll(', ,', ',');

    file.writeAsStringSync(content);
  }
}
