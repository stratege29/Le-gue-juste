class FirebaseConstants {
  FirebaseConstants._();

  // Collections
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
  static const String friendshipsCollection = 'friendships';
  static const String invitationsCollection = 'invitations';

  // Subcollections
  static const String membersSubcollection = 'members';
  static const String expensesSubcollection = 'expenses';
  static const String settlementsSubcollection = 'settlements';

  // User fields
  static const String phoneNumber = 'phoneNumber';
  static const String displayName = 'displayName';
  static const String avatarUrl = 'avatarUrl';
  static const String qrCode = 'qrCode';
  static const String fcmToken = 'fcmToken';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  // Group fields
  static const String groupName = 'name';
  static const String groupDescription = 'description';
  static const String groupImageUrl = 'imageUrl';
  static const String groupCreatedBy = 'createdBy';
  static const String groupMemberIds = 'memberIds';
  static const String groupCurrency = 'currency';
  static const String groupSimplifyDebts = 'simplifyDebts';

  // Expense fields
  static const String expenseDescription = 'description';
  static const String expenseAmount = 'amount';
  static const String expenseCurrency = 'currency';
  static const String expensePaidBy = 'paidBy';
  static const String expenseCreatedBy = 'createdBy';
  static const String expenseDate = 'date';
  static const String expenseCategory = 'category';
  static const String expenseSplitType = 'splitType';
  static const String expenseSplits = 'splits';
  static const String expenseIsDeleted = 'isDeleted';
}
