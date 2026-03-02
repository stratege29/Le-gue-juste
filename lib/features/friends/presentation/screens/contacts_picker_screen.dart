import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/utils/snackbar_manager.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/friends_provider.dart';

class ContactsPickerScreen extends ConsumerStatefulWidget {
  const ContactsPickerScreen({super.key});

  @override
  ConsumerState<ContactsPickerScreen> createState() => _ContactsPickerScreenState();
}

class _ContactsPickerScreenState extends ConsumerState<ContactsPickerScreen> {
  bool _permissionDenied = false;
  bool _loading = true;
  String _searchQuery = '';

  List<_ContactInfo> _contacts = [];
  final Set<String> _addingPhones = {};
  final Set<String> _requestSentPhones = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final granted = await FlutterContacts.requestPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;

    // Collect all phone numbers and normalize them
    final contactInfos = <_ContactInfo>[];
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = PhoneUtils.normalize(phone.number);
        if (normalized != null) {
          contactInfos.add(_ContactInfo(
            displayName: contact.displayName,
            rawNumber: phone.number,
            normalizedNumber: normalized,
          ));
        }
      }
    }

    // Deduplicate by normalized number (keep first occurrence)
    final seen = <String>{};
    final unique = <_ContactInfo>[];
    for (final info in contactInfos) {
      if (seen.add(info.normalizedNumber)) {
        unique.add(info);
      }
    }

    // Batch lookup in Firestore
    await _lookupUsers(unique);

    if (!mounted) return;
    setState(() {
      _contacts = unique;
      _loading = false;
    });
  }

  Future<void> _lookupUsers(List<_ContactInfo> contacts) async {
    if (contacts.isEmpty) return;

    final firestore = ref.read(firestoreProvider);
    final currentUser = ref.read(authStateProvider).valueOrNull;
    final allNumbers = contacts.map((c) => c.normalizedNumber).toList();

    // Firestore whereIn supports max 10 items per query
    final chunks = _chunk(allNumbers, 10);
    final userMap = <String, String>{}; // normalizedNumber -> userId

    for (final chunk in chunks) {
      final query = await firestore
          .collection(FirebaseConstants.usersCollection)
          .where(FirebaseConstants.phoneNumber, whereIn: chunk)
          .get();

      for (final doc in query.docs) {
        final phone = doc.data()[FirebaseConstants.phoneNumber] as String?;
        if (phone != null) {
          userMap[phone] = doc.id;
        }
      }
    }

    // Check which are already friends
    Set<String> friendIds = {};
    if (currentUser != null) {
      final friendsSnap = await firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(currentUser.uid)
          .collection('friends')
          .get();
      friendIds = friendsSnap.docs.map((d) => d.id).toSet();
    }

    for (final contact in contacts) {
      final userId = userMap[contact.normalizedNumber];
      if (userId != null) {
        contact.userId = userId;
        contact.isSelf = userId == currentUser?.uid;
        contact.isAlreadyFriend = friendIds.contains(userId);
      }
    }
  }

  List<_ContactInfo> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final query = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
          c.rawNumber.contains(query);
    }).toList();
  }

  Future<void> _sendRequest(_ContactInfo contact) async {
    if (contact.userId == null) return;
    setState(() => _addingPhones.add(contact.normalizedNumber));

    HapticFeedback.mediumImpact();
    final success = await ref
        .read(friendsNotifierProvider.notifier)
        .sendFriendRequest(contact.normalizedNumber);

    if (!mounted) return;

    if (success) {
      setState(() => _requestSentPhones.add(contact.normalizedNumber));
      SnackbarManager.showSuccess(context, 'Demande envoyée à ${contact.displayName}');
    } else {
      final errorState = ref.read(friendsNotifierProvider);
      final errorMsg = errorState.hasError
          ? errorState.error.toString()
          : 'Erreur lors de l\'envoi';
      SnackbarManager.showError(context, errorMsg);
    }

    setState(() => _addingPhones.remove(contact.normalizedNumber));
  }

  void _inviteContact(_ContactInfo contact) {
    HapticFeedback.lightImpact();
    Share.share(
      'Rejoins-moi sur LeGuJuste, l\'app pour partager les d\u00e9penses entre amis ! T\u00e9l\u00e9charge-la ici : https://play.google.com/store/apps/details?id=com.arnaudkossea.leguejuste',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes contacts'),
      ),
      body: _permissionDenied
          ? EmptyStateWidget(
              icon: Icons.contacts_outlined,
              title: 'Acc\u00e8s contacts requis',
              description:
                  'Autorisez l\'acc\u00e8s \u00e0 vos contacts pour retrouver vos amis sur LeGuJuste',
              actionLabel: 'R\u00e9essayer',
              onAction: () {
                setState(() {
                  _permissionDenied = false;
                  _loading = true;
                });
                _loadContacts();
              },
            )
          : _loading
              ? const SkeletonScreen(showSummaryCard: false)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher un contact...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.gray50,
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: _filteredContacts.isEmpty
                          ? const EmptyStateWidget(
                              icon: Icons.person_off_outlined,
                              title: 'Aucun contact trouv\u00e9',
                              description: 'Aucun contact ne correspond \u00e0 votre recherche',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                return _buildContactTile(_filteredContacts[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildContactTile(_ContactInfo contact) {
    final isAdding = _addingPhones.contains(contact.normalizedNumber);
    final initial = contact.displayName.isNotEmpty
        ? contact.displayName[0].toUpperCase()
        : '?';

    Widget trailing;
    if (contact.isSelf) {
      trailing = Chip(
        label: const Text('Moi'),
        backgroundColor: AppColors.gray100,
      );
    } else if (contact.isAlreadyFriend) {
      trailing = Chip(
        label: const Text('Déjà ami'),
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
      );
    } else if (_requestSentPhones.contains(contact.normalizedNumber)) {
      trailing = Chip(
        label: const Text('Demande envoyée'),
        backgroundColor: Colors.green.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: Colors.green, fontSize: 12),
      );
    } else if (contact.userId != null) {
      trailing = isAdding
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              onPressed: () => _sendRequest(contact),
              child: const Text('Demander'),
            );
    } else {
      trailing = OutlinedButton(
        onPressed: () => _inviteContact(contact),
        child: const Text('Inviter'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: contact.userId != null
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.gray200,
          child: Text(
            initial,
            style: TextStyle(
              color: contact.userId != null ? AppColors.primary : AppColors.gray600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          contact.rawNumber,
          style: TextStyle(color: AppColors.gray500, fontSize: 12),
        ),
        trailing: trailing,
      ),
    );
  }
}

class _ContactInfo {
  final String displayName;
  final String rawNumber;
  final String normalizedNumber;
  String? userId;
  bool isSelf = false;
  bool isAlreadyFriend = false;

  _ContactInfo({
    required this.displayName,
    required this.rawNumber,
    required this.normalizedNumber,
  });
}

List<List<T>> _chunk<T>(List<T> list, int size) {
  return List.generate(
    (list.length / size).ceil(),
    (i) => list.sublist(i * size, (i + 1) * size > list.length ? list.length : (i + 1) * size),
  );
}
