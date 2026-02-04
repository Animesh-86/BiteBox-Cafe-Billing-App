import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/providers/theme_provider.dart';

import '../widgets/settings_shared.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Appearance"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        // color: Colors.black, // Removed hardcoded color
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: SingleChildScrollView(
          child: SettingsSection(
            title: "Theme Settings",
            icon: Icons.palette_rounded,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "App Theme",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(12),
                    isSelected: [
                      themeMode == ThemeMode.light,
                      themeMode == ThemeMode.dark,
                      themeMode == ThemeMode.system,
                    ],
                    onPressed: (index) {
                      final modes = [
                        ThemeMode.light,
                        ThemeMode.dark,
                        ThemeMode.system,
                      ];
                      ref.read(themeProvider.notifier).setTheme(modes[index]);
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.light_mode_rounded),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.dark_mode_rounded),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.smartphone_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
