import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/utils/test_data_seeder.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsSheet(context, ref),
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Profile header - clickable to edit
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showEditProfileSheet(context, ref);
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.gray200,
                          backgroundImage:
                              user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                          child: user?.avatarUrl == null
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.gray500,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user?.displayName ?? 'Utilisateur',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit, size: 18, color: AppColors.gray500),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.phoneNumber ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.gray600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Appuyez pour modifier',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Menu items
              _buildMenuItem(
                context,
                icon: Icons.qr_code,
                title: 'Mon QR Code',
                subtitle: 'Partagez votre code pour etre ajoute',
                onTap: () => context.push(RouteConstants.myQrCode),
              ),
              _buildMenuItem(
                context,
                icon: Icons.qr_code_scanner,
                title: 'Scanner un QR',
                subtitle: 'Ajoutez un ami ou rejoignez un groupe',
                onTap: () => context.push(RouteConstants.scanQr),
              ),
              _buildMenuItem(
                context,
                icon: Icons.people_outline,
                title: 'Mes amis',
                subtitle: 'Gerez vos contacts',
                onTap: () => context.push(RouteConstants.friends),
              ),
              _buildMenuItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Voir les notifications',
                onTap: () => context.push(RouteConstants.notifications),
              ),
              const SizedBox(height: 24),
              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Deconnexion'),
                        content: const Text(
                            'Etes-vous sur de vouloir vous deconnecter?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ref.read(authNotifierProvider.notifier).signOut();
                            },
                            child: const Text(
                              'Deconnecter',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Deconnexion',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erreur: $error'),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: '$title. $subtitle',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: IconBadge(icon: icon, color: AppColors.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: AppColors.gray600, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final user = ref.read(currentUserProvider).valueOrNull;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeModeProvider);
          final isDark = themeMode == ThemeMode.dark;

          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Parametres',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: IconBadge(
                    icon: Icons.person_outline,
                    color: AppColors.primary,
                  ),
                  title: const Text('Modifier mon profil'),
                  subtitle: Text(user?.displayName ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    _showEditProfileSheet(context, ref);
                  },
                ),
                Semantics(
                  label: 'Mode sombre ${isDark ? "active" : "desactive"}',
                  child: SwitchListTile(
                    secondary: IconBadge(
                      icon: isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? AppColors.primaryLight : AppColors.warning,
                    ),
                    title: const Text('Mode sombre'),
                    subtitle: Text(isDark ? 'Active' : 'Desactive'),
                    value: isDark,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).setThemeMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
                  ),
                ),
                ListTile(
                  leading: IconBadge(
                    icon: Icons.info_outline,
                    color: AppColors.gray600,
                  ),
                  title: const Text('A propos'),
                  subtitle: const Text('Version 1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    showAboutDialog(
                      context: context,
                      applicationName: 'LeGuJuste',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 LeGuJuste',
                    );
                  },
                ),
                if (kDebugMode) ...[
                  const Divider(),
                  ListTile(
                    leading: IconBadge(
                      icon: Icons.science_outlined,
                      color: AppColors.warning,
                    ),
                    title: const Text('Creer donnees de test'),
                    subtitle: const Text('Ajoute 2 amis fictifs + depenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      Navigator.pop(ctx);

                      final seeder = TestDataSeeder(
                        ref.read(firestoreProvider),
                        ref.read(firebaseAuthProvider),
                      );

                      SnackbarManager.showInfo(context, 'Nettoyage et creation...');

                      // Clean up old test data first
                      await seeder.cleanupTestData();

                      // Create new test data
                      final groupId = await seeder.seedTestData();

                      if (context.mounted) {
                        if (groupId != null) {
                          SnackbarManager.showSuccess(
                            context,
                            'Groupe "Vacances Test" cree avec Alice et Bob!',
                          );
                        } else {
                          SnackbarManager.showError(context, 'Erreur lors de la creation');
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider).valueOrNull;
    final controller = TextEditingController(text: user?.displayName ?? '');
    File? selectedImage;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Modifier mon profil',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                // Avatar selection
                GestureDetector(
                  onTap: isLoading ? null : () async {
                    HapticFeedback.lightImpact();
                    final source = await _showImageSourceDialog(context);
                    if (source != null) {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: source,
                        maxWidth: 512,
                        maxHeight: 512,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        setState(() {
                          selectedImage = File(pickedFile.path);
                        });
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.gray200,
                        backgroundImage: selectedImage != null
                            ? FileImage(selectedImage!)
                            : (user?.avatarUrl != null
                                ? NetworkImage(user!.avatarUrl!) as ImageProvider
                                : null),
                        child: (selectedImage == null && user?.avatarUrl == null)
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: AppColors.gray500,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appuyez pour changer la photo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gray500,
                      ),
                ),
                const SizedBox(height: 24),
                // Name field
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nom d\'affichage',
                    hintText: 'Entrez votre nom',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  autofocus: false,
                ),
                const SizedBox(height: 24),
                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      HapticFeedback.mediumImpact();
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        SnackbarManager.showError(context, 'Veuillez entrer un nom');
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Upload image if selected
                        if (selectedImage != null) {
                          await ref.read(authNotifierProvider.notifier).uploadAvatar(selectedImage!);
                        }

                        // Update name
                        await ref.read(authNotifierProvider.notifier).updateProfile(
                          displayName: name,
                        );

                        // Force refresh user data and wait for it
                        final _ = await ref.refresh(currentUserProvider.future);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          SnackbarManager.showSuccess(context, 'Profil mis a jour!');
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() => isLoading = false);
                          SnackbarManager.showError(context, 'Erreur: $e');
                        }
                      }
                    },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sauvegarder'),
                  ),
                ),
                const SizedBox(height: 8),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choisir une photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.secondary),
              ),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
