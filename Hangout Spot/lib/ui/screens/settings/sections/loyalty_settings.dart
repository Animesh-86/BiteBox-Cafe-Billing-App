import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/logic/rewards/reward_provider.dart';
import '../../../../utils/constants/app_keys.dart';
import '../widgets/settings_shared.dart';

class LoyaltySettingsScreen extends ConsumerStatefulWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  ConsumerState<LoyaltySettingsScreen> createState() =>
      _LoyaltySettingsScreenState();
}

class _LoyaltySettingsScreenState extends ConsumerState<LoyaltySettingsScreen> {
  // Local controllers
  final TextEditingController _earningRateController = TextEditingController();
  final TextEditingController _redemptionRateController =
      TextEditingController();

  @override
  void dispose() {
    _earningRateController.dispose();
    _redemptionRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(rewardSettingsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Loyalty Program"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Dark background
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
          child: SingleChildScrollView(
            child: SettingsSection(
              title: "Reward Settings",
              icon: Icons.stars_rounded,
              children: [
                settingsAsync.when(
                  data: (settings) {
                    final isEnabled =
                        settings[REWARD_FEATURE_TOGGLE_KEY] == 'true';
                    final earningRate =
                        double.tryParse(settings[REWARD_RATE_KEY] ?? '0.08') ??
                        0.08;
                    final redemptionRate =
                        double.tryParse(
                          settings[REDEMPTION_RATE_KEY] ?? '1.0',
                        ) ??
                        1.0;

                    if (_earningRateController.text.isEmpty && mounted) {
                      _earningRateController.text = (earningRate * 100)
                          .toStringAsFixed(1);
                    }
                    if (_redemptionRateController.text.isEmpty && mounted) {
                      _redemptionRateController.text = redemptionRate
                          .toStringAsFixed(2);
                    }

                    return Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Reward System'),
                          subtitle: const Text('Earn points per purchase'),
                          value: isEnabled,
                          onChanged: (value) async {
                            await ref
                                .read(rewardNotifierProvider.notifier)
                                .setRewardSystemEnabled(value);
                            ref.invalidate(rewardSettingsProvider);
                            ref.invalidate(isRewardSystemEnabledProvider);
                          },
                        ),
                        if (isEnabled) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Current: ${(earningRate * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Redeem: ₹${redemptionRate.toStringAsFixed(2)}/pt',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SettingsTextField(
                                      controller: _earningRateController,
                                      label: "Earning %",
                                      icon: Icons.percent,
                                      inputType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SettingsTextField(
                                      controller: _redemptionRateController,
                                      label: "₹ Value/Pt",
                                      icon: Icons.currency_rupee,
                                      inputType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: SettingsActionBtn(
                                  label: "Save Rates",
                                  onPressed: () async {
                                    final earningPercent =
                                        double.tryParse(
                                          _earningRateController.text,
                                        ) ??
                                        (earningRate * 100);
                                    final redemption =
                                        double.tryParse(
                                          _redemptionRateController.text,
                                        ) ??
                                        redemptionRate;

                                    await ref
                                        .read(rewardNotifierProvider.notifier)
                                        .setRewardEarningRate(
                                          earningPercent / 100,
                                        );
                                    await ref
                                        .read(rewardNotifierProvider.notifier)
                                        .setRedemptionRate(redemption);

                                    ref.invalidate(rewardSettingsProvider);
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Reward rates updated'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
