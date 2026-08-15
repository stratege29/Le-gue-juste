import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../data/services/receipt_scanner_service.dart';
import '../../domain/entities/receipt_item.dart';
import 'receipt_items_assignment_screen.dart';

/// Result returned to AddExpenseScreen after the scan+assignment flow.
class ReceiptScanResult {
  final double totalAmount;
  final Map<String, double> amountsPerUser;
  final String? description;

  const ReceiptScanResult({
    required this.totalAmount,
    required this.amountsPerUser,
    this.description,
  });
}

/// Scanner flow entry point: lets the user pick a receipt photo from camera
/// or gallery, runs OCR, then pushes the item-assignment screen.
class ReceiptScannerScreen extends ConsumerStatefulWidget {
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String? currentUserId;
  final String currency;

  const ReceiptScannerScreen({
    super.key,
    required this.memberIds,
    required this.memberNames,
    required this.currentUserId,
    required this.currency,
  });

  @override
  ConsumerState<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  final _picker = ImagePicker();
  bool _processing = false;
  String? _statusMessage;

  /// Guards the window between tapping a source tile and [_processing] turning
  /// true — without it, two quick taps open two pickers.
  bool _busy = false;

  /// Last successful scan, kept so backing out of the assignment screen does
  /// not force the user to photograph the receipt again.
  ScannedReceipt? _lastReceipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un reçu'),
      ),
      body: SafeArea(
        child: _processing ? _buildProcessing() : _buildPicker(),
      ),
    );
  }

  Widget _buildPicker() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Prenez un reçu en photo',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "On détecte les articles et leurs prix, puis vous choisissez qui prend quoi.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_lastReceipt != null) ...[
            _buildResumeCard(_lastReceipt!),
            const SizedBox(height: AppSpacing.lg),
          ],
          _SourceTile(
            icon: Icons.photo_camera_rounded,
            label: 'Prendre une photo',
            onTap: () => _pickAndScan(ImageSource.camera),
          ),
          const SizedBox(height: AppSpacing.md),
          _SourceTile(
            icon: Icons.photo_library_rounded,
            label: 'Choisir dans la galerie',
            onTap: () => _pickAndScan(ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppColors.info, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "Astuce: posez le reçu à plat, bien éclairé, et cadrez la totalité.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Offer to go back into the assignment screen with the scan we already have.
  Widget _buildResumeCard(ScannedReceipt receipt) {
    final theme = Theme.of(context);
    final count = receipt.items.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dernier scan',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$count article${count > 1 ? 's' : ''} détecté'
                  '${count > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openAssignment(receipt),
            child: const Text('Reprendre'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              _statusMessage ?? 'Analyse en cours…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndScan(ImageSource source) async {
    if (_busy || _processing) return;
    _busy = true;
    HapticFeedback.selectionClick();
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _processing = true;
        _statusMessage = 'Lecture du reçu…';
      });

      final file = File(picked.path);
      final service = ReceiptScannerService();
      ScannedReceipt receipt;
      try {
        receipt = await service.scanImage(file);
      } finally {
        await service.dispose();
        // image_picker hands us a copy in the app cache — deleting it frees
        // the space without touching the user's camera roll.
        await _deleteTempImage(file);
      }

      if (!mounted) return;

      if (receipt.items.isEmpty) {
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
        SnackbarManager.showError(context, _noItemsMessage(receipt));
        return;
      }

      _lastReceipt = receipt;
      await _openAssignment(receipt);
    } on PlatformException catch (e) {
      if (!mounted) return;
      _resetProcessing();
      _reportPlatformException(e);
    } catch (_) {
      if (!mounted) return;
      _resetProcessing();
      SnackbarManager.showError(
        context,
        "Impossible d'analyser cette image. Réessayez avec une autre photo.",
      );
    } finally {
      _busy = false;
    }
  }

  /// Pushes the assignment screen; pops this screen when the user validates,
  /// and otherwise returns to the picker with [_lastReceipt] still available.
  Future<void> _openAssignment(ScannedReceipt receipt) async {
    final result = await Navigator.of(context).push<ReceiptScanResult>(
      MaterialPageRoute(
        builder: (_) => ReceiptItemsAssignmentScreen(
          receipt: receipt,
          memberIds: widget.memberIds,
          memberNames: widget.memberNames,
          currentUserId: widget.currentUserId,
          currency: widget.currency,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _resetProcessing();
    }
  }

  void _resetProcessing() {
    setState(() {
      _processing = false;
      _statusMessage = null;
    });
  }

  /// Distinguishes "no text at all" (bad photo, or the Android OCR model still
  /// being fetched by Play Services on first use) from "text but no items".
  String _noItemsMessage(ScannedReceipt receipt) {
    if (receipt.rawText.trim().isEmpty) {
      final androidHint = Platform.isAndroid
          ? " Au premier scan, la reconnaissance de texte peut nécessiter une connexion le temps de son installation."
          : '';
      return "Aucun texte n'a été lu sur la photo. Vérifiez la netteté et "
          "l'éclairage.$androidHint";
    }
    return "Texte lu, mais aucun article reconnu. Cadrez la liste des articles "
        "avec leurs prix.";
  }

  void _reportPlatformException(PlatformException e) {
    final isCamera = e.code == 'camera_access_denied';
    final isPhotos = e.code == 'photo_access_denied';

    if (isCamera || isPhotos) {
      final what = isCamera ? "l'appareil photo" : 'vos photos';
      SnackbarManager.showWithAction(
        context,
        message: "Accès à $what refusé. Autorisez-le dans les réglages pour "
            "scanner un reçu.",
        actionLabel: 'Réglages',
        onAction: openAppSettings,
        backgroundColor: AppColors.error,
      );
      return;
    }

    SnackbarManager.showError(
      context,
      "Impossible d'ouvrir cette image. Réessayez.",
    );
  }

  Future<void> _deleteTempImage(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cache cleanup is best-effort; never fail a scan over it.
    }
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
