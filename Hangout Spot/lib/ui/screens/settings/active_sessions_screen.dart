import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/data/models/user_session.dart';
import 'package:hangout_spot/data/providers/session_provider.dart';

/// Screen to display and manage active device sessions with trust system
class ActiveSessionsScreen extends ConsumerStatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  ConsumerState<ActiveSessionsScreen> createState() =>
      _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen> {
  bool _isCurrentDeviceTrusted = false;

  @override
  void initState() {
    super.initState();
    _checkTrustStatus();
  }

  Future<void> _checkTrustStatus() async {
    final sessionManager = ref.read(sessionManagerProvider);
    final isTrusted = await sessionManager.isCurrentDeviceTrusted();
    if (mounted) {
      setState(() {
        _isCurrentDeviceTrusted = isTrusted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionManager = ref.watch(sessionManagerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Devices'),
        elevation: 0,
        backgroundColor: theme.colorScheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog(context);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<UserSession>>(
        stream: sessionManager.getActiveSessions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading sessions',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active sessions',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Devices will appear here when logged in',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          final sessions = snapshot.data!;
          final currentSessionId = sessionManager.currentSessionId;
          final pendingSessions = sessions
              .where((s) => s.trustLevel == 'pending')
              .toList();

          return Column(
            children: [
              // Pending devices notification banner
              if (pendingSessions.isNotEmpty && _isCurrentDeviceTrusted)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${pendingSessions.length} device${pendingSessions.length > 1 ? 's' : ''} waiting for approval',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Claim Trust button for pending devices
              if (!_isCurrentDeviceTrusted)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This device is pending approval',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You can use the app normally, but cannot manage other devices. If you own this account, claim trust with your password.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showClaimTrustDialog(context, sessionManager),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.verified_user, size: 18),
                          label: const Text('Claim Trust'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Sessions list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isCurrentDevice =
                        session.sessionId == currentSessionId;
                    final lastActivityAgo = _getTimeAgo(session.lastActivity);

                    return _buildSessionCard(
                      context,
                      theme,
                      session,
                      isCurrentDevice,
                      lastActivityAgo,
                      sessionManager,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    ThemeData theme,
    UserSession session,
    bool isCurrentDevice,
    String lastActivityAgo,
    dynamic sessionManager,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentDevice
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with device icon, name, and badges
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isCurrentDevice
                      ? Colors.green
                      : theme.colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    _getDeviceIcon(session.deviceType),
                    color: isCurrentDevice
                        ? Colors.white
                        : theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.deviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${session.deviceType} • v${session.appVersion}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trust badge
                _buildTrustBadge(session.trustLevel),
              ],
            ),

            const SizedBox(height: 12),

            // Device info
            if (session.androidVersion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.android, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      session.androidVersion!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

            // Last activity
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Last active: $lastActivityAgo',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            // Current device badge
            if (isCurrentDevice) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This Device',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            // Action buttons (only for trusted devices)
            if (!isCurrentDevice && _isCurrentDeviceTrusted) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Approve button for pending devices
                  if (session.trustLevel == 'pending')
                    TextButton.icon(
                      onPressed: () =>
                          _approveDevice(context, session, sessionManager),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Approve'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),

                  // Promote button for approved devices
                  if (session.trustLevel == 'approved')
                    TextButton.icon(
                      onPressed: () =>
                          _promoteDevice(context, session, sessionManager),
                      icon: const Icon(Icons.star, size: 18),
                      label: const Text('Promote'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),

                  const SizedBox(width: 8),

                  // Logout button (only for trusted devices)
                  TextButton.icon(
                    onPressed: () => _showLogoutConfirmation(
                      context,
                      session,
                      sessionManager,
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge(String trustLevel) {
    Color color;
    IconData icon;
    String label;

    switch (trustLevel) {
      case 'trusted':
        color = Colors.green;
        icon = Icons.verified;
        label = 'Trusted';
        break;
      case 'approved':
        color = Colors.blue;
        icon = Icons.check_circle;
        label = 'Approved';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveDevice(
    BuildContext context,
    UserSession session,
    dynamic sessionManager,
  ) async {
    try {
      await sessionManager.approveDevice(session.sessionId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${session.deviceName} approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _promoteDevice(
    BuildContext context,
    UserSession session,
    dynamic sessionManager,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote to Trusted'),
        content: Text(
          'Promote "${session.deviceName}" to trusted device?\n\n'
          'Trusted devices can approve new devices and remotely log out other sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await sessionManager.promoteToTrusted(session.sessionId);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${session.deviceName} promoted to trusted'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum trusted devices reached (3)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to promote device: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClaimTrustDialog(
    BuildContext context,
    dynamic sessionManager,
  ) async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Claim Trust'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your account password to claim trust for this device.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: Limited to 3 attempts per hour',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Claim Trust'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final success = await sessionManager.claimTrust(passwordController.text);

      if (context.mounted) {
        Navigator.pop(context); // Hide loading

        if (success) {
          setState(() {
            _isCurrentDeviceTrusted = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trust claimed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to claim trust. Check your password or try again later.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'tablet':
        return Icons.tablet_android;
      case 'phone':
        return Icons.phone_android;
      case 'emulator':
        return Icons.developer_mode;
      default:
        return Icons.phone_android;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showLogoutConfirmation(
    BuildContext context,
    UserSession session,
    dynamic sessionManager,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: Text(
          'Are you sure you want to log out "${session.deviceName}"?\n\n'
          'This will immediately end the session on that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              sessionManager.remoteLogout(session.sessionId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Logged out ${session.deviceName}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device Trust System'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection(
                '🟢 Trusted',
                'Full control over all devices. Can approve new devices and remotely log out sessions. Maximum 3 trusted devices.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '🔵 Approved',
                'Can use the app normally but cannot manage other devices. Can be promoted to trusted.',
              ),
              const SizedBox(height: 12),
              _buildInfoSection(
                '🟡 Pending',
                'Awaiting approval from a trusted device. Can use the app but cannot manage sessions.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Recovery Options:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Password Claim: Re-authenticate to claim trust\n'
                '• Multiple Trusted Devices: Up to 3 for redundancy\n'
                '• Email Recovery: For lost devices (coming soon)',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
