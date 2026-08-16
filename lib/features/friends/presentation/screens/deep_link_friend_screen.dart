import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';

class DeepLinkFriendScreen extends ConsumerStatefulWidget {
  final String qrCode;

  const DeepLinkFriendScreen({super.key, required this.qrCode});

  @override
  ConsumerState<DeepLinkFriendScreen> createState() =>
      _DeepLinkFriendScreenState();
}

class _DeepLinkFriendScreenState extends ConsumerState<DeepLinkFriendScreen> {
  bool _isLoading = true;
  bool _success = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _addFriend();
  }

  Future<void> _addFriend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(friendsNotifierProvider.notifier)
          .addFriendByQrCode(widget.qrCode);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = result;
          if (!result) {
            _errorMessage = 'Impossible d\'envoyer la demande d\'ami. '
                'Le code est peut-être invalide ou vous êtes déjà amis.';
          }
        });

        if (result) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            context.go(RouteConstants.friends);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = false;
          _errorMessage = 'Une erreur est survenue : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitation'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(RouteConstants.groups),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _isLoading
              ? _buildLoading()
              : _success
                  ? _buildSuccess()
                  : _buildError(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Envoi de la demande...',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Code : ${widget.qrCode}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.gray500,
                fontFamily: 'monospace',
              ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Demande d\'ami envoyée !',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Redirection vers vos amis...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.gray500,
              ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Échec de l\'ajout',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Une erreur inconnue est survenue.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.gray600,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _addFriend,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go(RouteConstants.groups),
          child: const Text('Retour à l\'accueil'),
        ),
      ],
    );
  }
}
