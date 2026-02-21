import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/settings_shared.dart';

class OperatingHoursSettingsScreen extends StatefulWidget {
  const OperatingHoursSettingsScreen({super.key});

  @override
  State<OperatingHoursSettingsScreen> createState() =>
      _OperatingHoursSettingsScreenState();
}

class _OperatingHoursSettingsScreenState
    extends State<OperatingHoursSettingsScreen> {
  int _openingHour = 14;
  int _closingHour = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _openingHour = prefs.getInt('opening_hour') ?? 14;
      _closingHour = prefs.getInt('closing_hour') ?? 5;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_openingHour == _closingHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening and closing hours cannot be the same.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('opening_hour', _openingHour);
    await prefs.setInt('closing_hour', _closingHour);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operating hours saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatTime(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour == 12) return '12:00 PM';
    if (hour > 12) return '${hour - 12}:00 PM';
    return '$hour:00 AM';
  }

  Future<void> _selectTime(BuildContext context, bool isOpening) async {
    final TimeOfDay initialTime = TimeOfDay(
      hour: isOpening ? _openingHour : _closingHour,
      minute: 0,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
      // Restrict to solid hours for UI simplicity since shift tracking operates linearly on hours
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );

    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingHour = picked.hour;
        } else {
          _closingHour = picked.hour;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cream = isDark
        ? theme.colorScheme.background
        : const Color(0xFFFEF9F5);
    final coffeeDark = isDark
        ? theme.colorScheme.onSurface
        : const Color(0xFF98664D);
    final isMidnightCrossing = _closingHour <= _openingHour;

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: Text(
          'Operating Hours',
          style: TextStyle(color: coffeeDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: coffeeDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Configure Shift Timings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: coffeeDark.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Analytics and Invoice sequences are bound to your active shift window. '
                  'Orders outside this window will be aggregated logically into the relevant session.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: coffeeDark.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),

                SettingsSection(
                  title: "Shift Boundaries",
                  icon: Icons.access_time_rounded,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Store Opens At'),
                      subtitle: Text(
                        _formatTime(_openingHour),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Icon(
                        Icons.edit,
                        color: theme.colorScheme.primary,
                      ),
                      onTap: () => _selectTime(context, true),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Store Closes At'),
                      subtitle: Text(
                        isMidnightCrossing
                            ? '${_formatTime(_closingHour)} (Next Day)'
                            : _formatTime(_closingHour),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Icon(
                        Icons.edit,
                        color: theme.colorScheme.primary,
                      ),
                      onTap: () => _selectTime(context, false),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                if (_openingHour == _closingHour)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Opening and closing times cannot be identical.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                SettingsActionBtn(
                  label: "Save Changes",
                  onPressed: _saveSettings,
                ),
              ],
            ),
    );
  }
}
