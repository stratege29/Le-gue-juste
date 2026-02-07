import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
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
  String _selectedCurrency = 'EUR';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final groupId = await ref.read(groupsNotifierProvider.notifier).createGroup(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      currency: _selectedCurrency,
    );

    setState(() => _isLoading = false);

    if (groupId != null && mounted) {
      SnackbarManager.showSuccess(context, 'Groupe cree!');
      context.pop();
      // Navigate to the new group
      context.push('/groups/$groupId');
    } else if (mounted) {
      SnackbarManager.showError(context, 'Erreur lors de la creation du groupe');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Group image placeholder
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.gray200,
                      child: Icon(
                        Icons.group,
                        size: 50,
                        color: AppColors.gray500,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
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
              ),
              const SizedBox(height: 32),
              // Group name
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
                decoration: const InputDecoration(
                  hintText: 'Ex: Vacances Espagne',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un nom';
                  }
                  if (value.trim().length < 2) {
                    return 'Le nom doit contenir au moins 2 caracteres';
                  }
                  if (value.trim().length > 50) {
                    return 'Le nom ne peut pas depasser 50 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Description
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
              // Currency
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
                  prefixIcon: Icon(Icons.euro),
                ),
                items: const [
                  DropdownMenuItem(value: 'EUR', child: Text('Euro (\u20AC)')),
                  DropdownMenuItem(value: 'USD', child: Text('Dollar (\$)')),
                  DropdownMenuItem(value: 'GBP', child: Text('Livre (\u00A3)')),
                  DropdownMenuItem(value: 'XOF', child: Text('CFA (FCFA)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCurrency = value);
                  }
                },
              ),
              const SizedBox(height: 32),
              // Create button
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  label: 'Creer le groupe',
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
