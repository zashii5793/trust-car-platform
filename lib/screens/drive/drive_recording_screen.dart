import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/drive_recording_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';

/// GPS drive recording screen.
///
/// Shows live stats (elapsed time, distance, speed) and a stop button.
/// Navigating back while recording keeps the recording alive.
class DriveRecordingScreen extends StatefulWidget {
  final String? vehicleId;
  final String? vehicleName;

  const DriveRecordingScreen({
    super.key,
    this.vehicleId,
    this.vehicleName,
  });

  @override
  State<DriveRecordingScreen> createState() => _DriveRecordingScreenState();
}

class _DriveRecordingScreenState extends State<DriveRecordingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  Future<void> _startRecording() async {
    final userId = context.read<AuthProvider>().firebaseUser?.uid;
    if (userId == null) return;

    final provider = context.read<DriveRecordingProvider>();
    if (provider.isRecording) return; // already recording

    final ok = await provider.startRecording(
      userId: userId,
      vehicleId: widget.vehicleId,
    );

    if (!ok && mounted) {
      final errMsg = provider.errorMessage ?? '記録を開始できませんでした';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errMsg), backgroundColor: AppColors.error),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _stopRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('記録を終了しますか？'),
        content: const Text('現在のドライブデータを保存して終了します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('続ける'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('終了'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final provider = context.read<DriveRecordingProvider>();
    await provider.stopRecording();

    if (mounted) {
      Navigator.of(context).pop(); // back to DriveLogScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent accidental back navigation during recording
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopRecording();
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text(
            widget.vehicleName != null
                ? '${widget.vehicleName} — 記録中'
                : 'ドライブ記録中',
          ),
          automaticallyImplyLeading: false,
        ),
        body: Consumer<DriveRecordingProvider>(
          builder: (context, provider, _) {
            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: provider.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          )
                        : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: constraints.maxHeight),
                          child: Padding(
                            padding: AppSpacing.paddingScreen,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Elapsed time ──────────────────────────────
                                _StatCard(
                                  label: '経過時間',
                                  value: provider.formattedElapsed,
                                  icon: Icons.timer_outlined,
                                  large: true,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // ── Distance and speed row ────────────────────
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: '走行距離',
                                        value: _formatDistance(provider.distanceKm),
                                        icon: Icons.straighten_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: _StatCard(
                                        label: '現在速度',
                                        value:
                                            '${provider.currentSpeedKmh.toStringAsFixed(0)} km/h',
                                        icon: Icons.speed_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // ── Max speed ─────────────────────────────────
                                _StatCard(
                                  label: '最高速度',
                                  value:
                                      '${provider.maxSpeedKmh.toStringAsFixed(0)} km/h',
                                  icon: Icons.rocket_launch_outlined,
                                ),

                                const SizedBox(height: AppSpacing.xl),

                                // ── GPS indicator ─────────────────────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.gps_fixed,
                                      color: Colors.greenAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'GPS 取得中',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Stop button ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: provider.isLoading ? null : _stopRecording,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text(
                          '記録を終了',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDistance(double km) {
    if (km >= 1.0) {
      return '${km.toStringAsFixed(2)} km';
    }
    return '${(km * 1000).toStringAsFixed(0)} m';
  }
}

// ---------------------------------------------------------------------------
// Stat card widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool large;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: large ? AppSpacing.lg : AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 48 : 28,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
