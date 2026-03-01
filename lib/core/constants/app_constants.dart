import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'LeGuJuste';
  static const String appVersion = '1.0.0';

  // QR Code prefix
  static const String qrCodePrefix = 'LGJ';

  // Timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;

  // OTP
  static const int otpLength = 6;
  static const int otpResendTimeout = 60; // seconds

  // Pagination
  static const int defaultPageSize = 20;

  // Currency
  static const String defaultCurrency = 'XOF';
  static const Map<String, String> currencySymbols = {
    'EUR': '\u20AC',
    'USD': '\$',
    'GBP': '\u00A3',
    'XOF': 'CFA',
    'XAF': 'CFA',
  };

  // Avatar emojis
  static const List<String> avatarEmojis = [
    '\u{1F60A}', // smiling face
    '\u{1F60E}', // sunglasses
    '\u{1F981}', // lion
    '\u{2B50}',  // star
    '\u{2764}\u{FE0F}',  // heart
    '\u{1F451}', // crown
    '\u{1F525}', // fire
    '\u{1F680}', // rocket
    '\u{1F308}', // rainbow
    '\u{2728}',  // sparkles
  ];

  // Balance threshold (for considering as settled)
  static const double balanceThreshold = 0.01;

  // Group name examples (rotating hints)
  static const List<String> groupNameExamples = [
    'Gazoil à Marcory',
    'Déjeuner chez Alice',
    'Vacances à Dakar',
    'Loyer coloc Cocody',
    'Anniversaire de Fatou',
    'Sorties du weekend',
    'Courses du marché',
    'Road trip Bassam',
  ];

  // Group icons (Material icons, stored as string keys)
  static const Map<String, IconData> groupIcons = {
    'restaurant': Icons.restaurant_outlined,
    'flight': Icons.flight_outlined,
    'home': Icons.home_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'local_gas_station': Icons.local_gas_station_outlined,
    'celebration': Icons.celebration_outlined,
    'sports_bar': Icons.sports_bar_outlined,
    'directions_car': Icons.directions_car_outlined,
    'school': Icons.school_outlined,
    'favorite': Icons.favorite_outlined,
    'beach_access': Icons.beach_access_outlined,
    'local_grocery_store': Icons.local_grocery_store_outlined,
    'movie': Icons.movie_outlined,
    'music_note': Icons.music_note_outlined,
    'fitness_center': Icons.fitness_center_outlined,
    'work': Icons.work_outlined,
    'child_care': Icons.child_care_outlined,
    'pets': Icons.pets_outlined,
    'medical_services': Icons.medical_services_outlined,
    'more_horiz': Icons.more_horiz,
  };
}
