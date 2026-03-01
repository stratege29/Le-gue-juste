import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../providers/groups_provider.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCurrency = 'XOF';
  String _selectedIcon = 'restaurant';
  final Set<String> _selectedFriendIds = {};
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() {
        _currentHintIndex =
            (_currentHintIndex + 1) % AppConstants.groupNameExamples.length;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final groupId =
        await ref.read(groupsNotifierProvider.notifier).createGroup(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              currency: _selectedCurrency,
              imageUrl: 'icon:$_selectedIcon',
              extraMemberIds: _selectedFriendIds.toList(),
            );

    setState(() => _isLoading = false);

    if (groupId != null && mounted) {
      SnackbarManager.showSuccess(context, 'Groupe créé !');
      context.pop();
      context.push('/groups/$groupId');
    } else if (mounted) {
      SnackbarManager.showError(
          context, 'Erreur lors de la création du groupe');
    }
  }

  void _showIconPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choisir une icône',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: AppConstants.groupIcons.length,
                    itemBuilder: (context, index) {
                      final entry =
                          AppConstants.groupIcons.entries.elementAt(index);
                      final isSelected = entry.key == _selectedIcon;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedIcon = entry.key);
                          setSheetState(() {});
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.gray100,
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.gray600,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(userFriendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau groupe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A. Group Icon Picker
              Center(
                child: GestureDetector(
                  onTap: _showIconPicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: Icon(
                          AppConstants.groupIcons[_selectedIcon] ??
                              Icons.group,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // B. Group Name Field
              Text(
                'Nom du groupe',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      'Ex: ${AppConstants.groupNameExamples[_currentHintIndex]}',
                  prefixIcon: Icon(
                    AppConstants.groupIcons[_selectedIcon] ?? Icons.group,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  if (value.trim().length < 2) {
                    return 'Le nom doit contenir au moins 2 caractères';
                  }
                  if (value.trim().length > 50) {
                    return 'Le nom ne peut pas dépasser 50 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // C. Description Field
              Text(
                'Description (optionnel)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ajoutez une description...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.description_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // D. Currency Selector
              Text(
                'Devise',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCurrency,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'XOF', child: Text('CFA (FCFA)')),
                  DropdownMenuItem(value: 'EUR', child: Text('Euro (\u20AC)')),
                  DropdownMenuItem(value: 'USD', child: Text('Dollar (\$)')),
                  DropdownMenuItem(value: 'GBP', child: Text('Livre (\u00A3)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),
              const SizedBox(height: 28),

              // E. Add Friends Section
              Text(
                'Inviter des amis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              friendsAsync.when(
                data: (friends) {
                  if (friends.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 32, color: AppColors.gray400),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoutez des amis via le QR code pour les inviter',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.gray500),
                          ),
                        ],
                      ),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: friends.map((friend) {
                      final isSelected =
                          _selectedFriendIds.contains(friend.id);
                      return FilterChip(
                        selected: isSelected,
                        avatar: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            friend.displayName.isNotEmpty
                                ? friend.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        label: Text(friend.displayName),
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        checkmarkColor: AppColors.primary,
                        onSelected: (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (selected) {
                              _selectedFriendIds.add(friend.id);
                            } else {
                              _selectedFriendIds.remove(friend.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => Text(
                  'Impossible de charger vos amis',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons for QR scan and share
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push(RouteConstants.scanQr);
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scanner QR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Share.share(
                          'Rejoins-moi sur LeGuJuste pour partager nos dépenses !',
                          subject: 'Invitation LeGuJuste',
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Partager le lien'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // F. Create Button
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  label: 'Créer le groupe',
                  isLoading: _isLoading,
                  onPressed: _createGroup,
                  minHeight: 56,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
