/// Whether [url] can safely be handed to `Image.network` / `NetworkImage`.
///
/// Avatar fields in Firestore hold more than plain URLs: sentinels such as
/// `icon:restaurant` or `emoji:🍔`, and legacy junk from older builds. Passing
/// those to the network image loaders throws
/// `Invalid argument(s): No host specified in URI …`, so every consumer must
/// gate on this check first.
bool isNetworkImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}
