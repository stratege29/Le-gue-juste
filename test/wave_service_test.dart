import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/core/services/wave_service.dart';

void main() {
  group('WaveService constants', () {
    test('waveColor is the correct Wave blue', () {
      expect(WaveService.waveColor, const Color(0xFF1B75BC));
    });
  });

  group('WaveService.launchWavePayment URL construction', () {
    // We cannot test actual URL launching in unit tests (requires platform),
    // but we can verify the service exists and has the right API.

    test('accepts required phoneNumber and amount parameters', () {
      // Verify the method signature compiles and exists
      expect(WaveService.launchWavePayment, isNotNull);
    });

    test('isWaveInstalled method exists', () {
      expect(WaveService.isWaveInstalled, isNotNull);
    });
  });
}
