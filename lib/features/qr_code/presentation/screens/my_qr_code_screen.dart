import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class MyQrCodeScreen extends ConsumerWidget {
  const MyQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user != null) {
                Clipboard.setData(ClipboardData(text: user.qrCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copie dans le presse-papier'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user != null) {
                Share.share(
                  'Ajoutez-moi sur LeGuJuste avec ce code: ${user.qrCode}\n\nOu scannez mon QR code dans l\'app!',
                  subject: 'Mon code LeGuJuste',
                );
              }
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User info
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.gray200,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'Utilisateur',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 32),
                // QR Code
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: PrettyQrView.data(
                    data: _generateQrData(user?.qrCode ?? ''),
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Scannez ce code pour m\'ajouter',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.qrCode ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gray500,
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erreur: $error'),
        ),
      ),
    );
  }

  String _generateQrData(String qrCode) {
    // Generate JSON data for QR code
    return '{"app":"leguejuste","type":"userProfile","qrCode":"$qrCode","version":1}';
  }
}
