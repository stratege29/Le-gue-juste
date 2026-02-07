import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';

class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  String _completePhoneNumber = '';
  bool _isValid = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.codeSent && next.phoneNumber != null) {
        context.push(
          RouteConstants.otpVerification,
          extra: next.phoneNumber,
        );
      }
      if (next.errorMessage != null) {
        SnackbarManager.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              // Logo/Icon
              const Center(
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              Center(
                child: Text(
                  'LeGuJuste',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Partagez vos depenses simplement',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.gray600,
                      ),
                ),
              ),
              const SizedBox(height: 48),
              // Phone input
              Text(
                'Entrez votre numero',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                decoration: InputDecoration(
                  hintText: 'Numero de telephone',
                  filled: true,
                  fillColor: AppColors.gray100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                initialCountryCode: 'FR',
                languageCode: 'fr',
                onChanged: (phone) {
                  setState(() {
                    _completePhoneNumber = phone.completeNumber;
                    try {
                      _isValid = phone.isValidNumber();
                    } catch (e) {
                      _isValid = false;
                    }
                  });
                },
                onCountryChanged: (country) {
                  // Handle country change if needed
                },
              ),
              const SizedBox(height: 24),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  label: 'Continuer',
                  isLoading: authState.isLoading,
                  onPressed: _isValid
                      ? () {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(authNotifierProvider.notifier)
                              .sendOtp(_completePhoneNumber);
                        }
                      : null,
                  minHeight: 56,
                ),
              ),
              const SizedBox(height: 24),
              // Terms
              Center(
                child: Text(
                  'En continuant, vous acceptez nos conditions d\'utilisation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gray500,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
