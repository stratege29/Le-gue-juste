import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/wave_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/settlement_entity.dart';

class PaymentMethodBottomSheet extends StatelessWidget {
  const PaymentMethodBottomSheet({super.key});

  static Future<PaymentMethod?> show(BuildContext context) async {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<PaymentMethod>(
      context: context,
      builder: (_) => const PaymentMethodBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mode de paiement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _MethodTile(
            icon: Icons.handshake_outlined,
            iconColor: AppColors.primary,
            title: 'Confirmation manuelle',
            subtitle: 'Espèces, virement, ou autre',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context, PaymentMethod.manual);
            },
          ),
          FutureBuilder<bool>(
            future: WaveService.isWaveInstalled(),
            builder: (context, snapshot) {
              final available = snapshot.data ?? false;
              return _MethodTile(
                icon: Icons.waves,
                iconColor: WaveService.waveColor,
                title: 'Payer via Wave',
                subtitle: available
                    ? 'Ouvrir l\'app Wave avec le montant'
                    : 'Wave non installé sur cet appareil',
                enabled: available,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, PaymentMethod.wave);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
