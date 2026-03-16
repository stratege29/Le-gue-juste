import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WaveService {
  static const waveColor = Color(0xFF1B75BC);

  static Future<bool> isWaveInstalled() async {
    return canLaunchUrl(Uri.parse('wave://'));
  }

  static Future<bool> launchWavePayment({
    required String phoneNumber,
    required int amount,
  }) async {
    final uri = Uri.parse('wave://send?phone=$phoneNumber&amount=$amount');

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // Fallback: try the web URL
    final webUri = Uri.parse(
      'https://pay.wave.com/m/$phoneNumber/$amount',
    );
    if (await canLaunchUrl(webUri)) {
      return launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    return false;
  }
}
