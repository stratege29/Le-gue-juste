import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedEmoji;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submitProfile() async {
    if (_formKey.currentState!.validate()) {
      await ref
          .read(authNotifierProvider.notifier)
          .createProfile(_nameController.text.trim());

      // Save selected emoji avatar after profile is created
      if (_selectedEmoji != null) {
        await ref
            .read(authNotifierProvider.notifier)
            .updateProfile(avatarUrl: 'emoji:$_selectedEmoji');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (!next.needsProfileSetup && !next.isLoading && previous?.isLoading == true) {
        context.go(RouteConstants.groups);
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Step indicator
                Row(
                  children: [
                    _StepDot(active: true, completed: true),
                    Expanded(child: Container(height: 2, color: AppColors.primary)),
                    _StepDot(active: true, completed: true),
                    Expanded(child: Container(height: 2, color: AppColors.primary)),
                    _StepDot(active: true, completed: false),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Telephone', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500)),
                    Text('Code', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.gray500)),
                    Text('Profil', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Icon(Icons.waving_hand, size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bienvenue!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Comment voulez-vous que vos amis vous appellent?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.gray600,
                      ),
                ),
                const SizedBox(height: 40),
                // Avatar emoji selector
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.gray200,
                        child: _selectedEmoji != null
                            ? Text(_selectedEmoji!, style: const TextStyle(fontSize: 54))
                            : Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.gray500,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Choisissez votre avatar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.gray600,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildEmojiPicker(),
                const SizedBox(height: 32),
                // Name input
                Text(
                  'Votre nom',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Jean Dupont',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer votre nom';
                    }
                    if (value.trim().length < 2) {
                      return 'Le nom doit contenir au moins 2 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: !authState.isLoading ? AppColors.primaryGradient : null,
                      color: authState.isLoading ? AppColors.gray300 : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: !authState.isLoading
                          ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : () {
                        HapticFeedback.mediumImpact();
                        _submitProfile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Commencer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: AppConstants.avatarEmojis.map((emoji) {
        final isSelected = _selectedEmoji == emoji;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedEmoji = isSelected ? null : emoji;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.gray100,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool completed;

  const _StepDot({required this.active, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active ? AppColors.primaryGradient : null,
        color: active ? null : AppColors.gray300,
      ),
      child: completed
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : active
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
    );
  }
}
