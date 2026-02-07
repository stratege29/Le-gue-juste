import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  final String? groupId;

  const QrScannerScreen({super.key, this.groupId});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.groupId != null ? 'Scanner pour inviter' : 'Scanner un QR code',
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          Semantics(
            label: 'Activer ou desactiver le flash',
            button: true,
            child: IconButton(
              icon: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, state, child) {
                  return Icon(
                    state.torchState == TorchState.on
                        ? Icons.flash_on
                        : Icons.flash_off,
                  );
                },
              ),
              tooltip: 'Flash',
              onPressed: () {
                HapticFeedback.lightImpact();
                _controller.toggleTorch();
              },
            ),
          ),
          Semantics(
            label: 'Changer de camera',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.cameraswitch),
              tooltip: 'Changer de camera',
              onPressed: () {
                HapticFeedback.lightImpact();
                _controller.switchCamera();
              },
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay
          _buildScanOverlay(context),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Placez le QR code dans le cadre',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return Stack(
      children: [
        // Dark overlay with cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scan area border
        Center(
          child: Container(
            width: scanAreaSize,
            height: scanAreaSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary,
                width: 3,
              ),
            ),
          ),
        ),
        // Corner decorations
        Center(
          child: SizedBox(
            width: scanAreaSize,
            height: scanAreaSize,
            child: CustomPaint(
              painter: CornersPainter(
                color: AppColors.primary,
                cornerLength: 30,
                strokeWidth: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;

      setState(() => _isProcessing = true);

      try {
        final data = barcode.rawValue!;

        // Parse QR code JSON
        final Map<String, dynamic> qrData;
        try {
          qrData = jsonDecode(data) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('QR code invalide');
        }

        // Verify it's a LeGuJuste QR code
        if (qrData['app'] != 'leguejuste') {
          throw Exception('Ce QR code n\'est pas un code LeGuJuste');
        }

        final qrCode = qrData['qrCode'] as String?;
        if (qrCode == null || qrCode.isEmpty) {
          throw Exception('QR code invalide');
        }

        // Find user by qrCode
        final firestore = ref.read(firestoreProvider);
        final userQuery = await firestore
            .collection(FirebaseConstants.usersCollection)
            .where(FirebaseConstants.qrCode, isEqualTo: qrCode)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          throw Exception('Utilisateur non trouve');
        }

        final userData = userQuery.docs.first;
        final userId = userData.id;
        final userName = userData.data()['displayName'] as String? ?? 'Utilisateur';

        // If we have a groupId, add user to group
        if (widget.groupId != null) {
          // Check if user is already a member
          final group = await firestore
              .collection(FirebaseConstants.groupsCollection)
              .doc(widget.groupId)
              .get();

          final memberIds = List<String>.from(group.data()?['memberIds'] ?? []);
          if (memberIds.contains(userId)) {
            throw Exception('$userName est deja membre du groupe');
          }

          // Add member to group
          await ref.read(groupsNotifierProvider.notifier).addMember(
            groupId: widget.groupId!,
            userId: userId,
          );

          if (mounted) {
            SnackbarManager.showSuccess(context, '$userName a ete ajoute au groupe!');
            context.pop();
          }
        } else {
          // Add as friend
          final success = await ref.read(friendsNotifierProvider.notifier).addFriendByQrCode(qrCode);

          if (mounted) {
            if (success) {
              SnackbarManager.showSuccess(context, '$userName a ete ajoute a vos amis!');
            } else {
              SnackbarManager.showWarning(context, '$userName est deja dans vos amis');
            }
            context.pop();
          }
        }
      } catch (e) {
        if (mounted) {
          SnackbarManager.showError(context, 'Erreur: $e');
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CornersPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  CornersPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = 20.0;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength + radius)
        ..lineTo(0, radius)
        ..arcToPoint(
          Offset(radius, 0),
          radius: Radius.circular(radius),
        )
        ..lineTo(cornerLength + radius, 0),
      paint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength - radius, 0)
        ..lineTo(size.width - radius, 0)
        ..arcToPoint(
          Offset(size.width, radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width, cornerLength + radius),
      paint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - cornerLength - radius)
        ..lineTo(size.width, size.height - radius)
        ..arcToPoint(
          Offset(size.width - radius, size.height),
          radius: Radius.circular(radius),
        )
        ..lineTo(size.width - cornerLength - radius, size.height),
      paint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(cornerLength + radius, size.height)
        ..lineTo(radius, size.height)
        ..arcToPoint(
          Offset(0, size.height - radius),
          radius: Radius.circular(radius),
        )
        ..lineTo(0, size.height - cornerLength - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
