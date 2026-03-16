import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stores a pending deep link QR code to be processed after auth
final pendingDeepLinkQrCodeProvider = StateProvider<String?>((ref) => null);

/// Deep link service that listens for incoming links
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final Ref _ref;

  DeepLinkService(this._ref);

  Future<void> init() async {
    // Check initial link (app was closed)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: no initial link');
    }

    // Listen for incoming links (app was in background)
    _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint('DeepLinkService error: $e'),
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('DeepLinkService: received URI: $uri');
    // Handle leguejuste://friend/{qrCode}
    if (uri.scheme == 'leguejuste' && uri.host == 'friend') {
      final qrCode = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (qrCode.isNotEmpty) {
        debugPrint('DeepLinkService: pending QR code: $qrCode');
        _ref.read(pendingDeepLinkQrCodeProvider.notifier).state = qrCode;
      }
    }
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});
