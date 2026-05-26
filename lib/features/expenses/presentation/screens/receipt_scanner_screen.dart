import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
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
          ).asCentered(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Prenez un reçu en photo',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "On détecte les articles et leurs prix, puis vous choisissez qui prend quoi.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.gray600,
                ),
          ),
          const SizedBox(height: AppSpacing.xxl),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.gray700,
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
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndScan(ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;
      if (!mounted) return;

      setState(() {
        _processing = true;
        _statusMessage = 'Lecture du reçu…';
      });

      final service = ReceiptScannerService();
      ScannedReceipt receipt;
      try {
        receipt = await service.scanImage(File(picked.path));
      } finally {
        await service.dispose();
      }

      if (!mounted) return;

      if (receipt.items.isEmpty) {
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
        SnackbarManager.showError(
          context,
          "Aucun article détecté. Réessayez avec une photo plus nette.",
        );
        return;
      }

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
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusMessage = null;
      });
      SnackbarManager.showError(context, "Erreur lors du scan: $e");
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.gray50,
            border: Border.all(color: AppColors.gray200),
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
                const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _CenteredWidget on Widget {
  Widget asCentered() => Center(child: this);
}
