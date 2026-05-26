import '../../domain/entities/receipt_item.dart';

/// Heuristic parser for French/XOF receipt OCR output.
///
/// Receipts vary wildly in format, so the parser is intentionally conservative:
/// it surfaces likely items and the user always edits/confirms them in the UI.
class ReceiptParser {
  ReceiptParser._();

  // Matches a price at the end of a line.
  // Examples it captures: "1,50", "12.50", "1 500", "12 500,50", "750"
  // Allows optional trailing currency token (EUR, €, FCFA, XOF, F, CFA).
  static final RegExp _trailingPrice = RegExp(
    r'(\d{1,3}(?:[  .]\d{3})*(?:[,.]\d{1,2})?|\d+(?:[,.]\d{1,2})?)\s*'
    r'(?:€|EUR|FCFA|XOF|CFA|F)?\s*$',
    caseSensitive: false,
  );

  // Optional leading quantity: "2 x", "3X", "2 *"
  static final RegExp _leadingQty = RegExp(
    r'^\s*(\d{1,2})\s*[x\*]\s*',
    caseSensitive: false,
  );

  // Lines we want to skip entirely (metadata, not items).
  static final List<RegExp> _skipPatterns = [
    RegExp(r'\b(tva|t\.v\.a|hors\s*taxe|ht\b|ttc\b)', caseSensitive: false),
    RegExp(r'\b(siret|siren|rcs|naf|ape)\b', caseSensitive: false),
    RegExp(r'\b(tel|t[ée]l[ée]phone|email|e-mail|fax)\b', caseSensitive: false),
    RegExp(r'\b(carte|cb|esp[èe]ces|paiement|mastercard|visa)\b',
        caseSensitive: false),
    RegExp(r'\b(monnaie|rendu|esp\.|cheque|ch[èe]que)\b', caseSensitive: false),
    RegExp(r'\b(client|caisse|ticket|n°|numero)\b', caseSensitive: false),
    RegExp(r'\b(merci|bienvenue|au revoir|a bient[ôo]t)\b',
        caseSensitive: false),
    RegExp(r'\b(date|heure|le\s+\d{1,2}/\d{1,2})\b', caseSensitive: false),
    RegExp(r'^\s*\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\s*$'),
    RegExp(r'^\s*\d{1,2}:\d{2}\s*$'),
    RegExp(r'^\s*-+\s*$'),
    RegExp(r'^\s*=+\s*$'),
  ];

  // Lines that indicate the total (used to detect detectedTotal, and to skip
  // the line from items list).
  static final List<RegExp> _totalPatterns = [
    RegExp(r'\btotal\s*(ttc|net|du|a\s*payer|à\s*payer)?\b',
        caseSensitive: false),
    RegExp(r'\bmontant\s*(total|du|à\s*payer|a\s*payer)?\b',
        caseSensitive: false),
    RegExp(r'\bsomme\s*(due|totale)?\b', caseSensitive: false),
    RegExp(r'\bnet\s*a\s*payer\b', caseSensitive: false),
  ];

  static final RegExp _subtotalPattern =
      RegExp(r'\bsous[\s-]*total\b', caseSensitive: false);

  /// Parse raw OCR text from a receipt into a [ScannedReceipt].
  static ScannedReceipt parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final items = <ReceiptItem>[];
    double? detectedTotal;

    for (final raw in lines) {
      final line = _normalize(raw);

      // 1. Try total line first — extract value, do not add as item.
      if (_isTotalLine(line) && !_subtotalPattern.hasMatch(line)) {
        final price = _extractTrailingPrice(line);
        if (price != null) {
          // Keep the largest plausible total (some receipts have multiple
          // "total" mentions: total HT, total TTC, total a payer).
          if (detectedTotal == null || price > detectedTotal) {
            detectedTotal = price;
          }
        }
        continue;
      }

      // 2. Skip metadata.
      if (_shouldSkip(line)) continue;

      // 3. Try to extract an item.
      final item = _tryExtractItem(line);
      if (item != null) items.add(item);
    }

    return ScannedReceipt(
      items: items,
      detectedTotal: detectedTotal,
      rawText: rawText,
    );
  }

  static String _normalize(String s) {
    // Replace non-breaking spaces, collapse whitespace.
    return s.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isTotalLine(String line) =>
      _totalPatterns.any((p) => p.hasMatch(line));

  static bool _shouldSkip(String line) {
    if (_skipPatterns.any((p) => p.hasMatch(line))) return true;
    // Skip lines that are mostly digits/punctuation (separators, page numbers).
    final letters = line.replaceAll(RegExp(r'[^a-zA-Zà-üÀ-Ü]'), '').length;
    if (letters < 2) return true;
    return false;
  }

  static ReceiptItem? _tryExtractItem(String line) {
    final match = _trailingPrice.firstMatch(line);
    if (match == null) return null;

    final priceStr = match.group(1)!;
    final price = _parsePrice(priceStr);
    if (price == null || price <= 0) return null;

    // Plausibility: prices below 0.05 are usually OCR noise on a barcode digit.
    // (XOF has no fractional prices, but minimum is typically ≥ 10 FCFA.)
    if (price < 0.05) return null;

    // Name = everything before the matched price.
    var name = line.substring(0, match.start).trim();

    // Strip leading quantity.
    int qty = 1;
    final qtyMatch = _leadingQty.firstMatch(name);
    if (qtyMatch != null) {
      qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
      name = name.substring(qtyMatch.end).trim();
    }

    // Strip trailing junk: standalone digits (item code), x1 patterns.
    name = name
        .replaceAll(RegExp(r'\s+\d{1,3}\s*[x×*]\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+\d+(?:[,.]\d+)?\s*$'), '')
        .trim();

    if (name.length < 2) return null;

    // Capitalize nicely: first letter of each word, lowercase rest.
    name = _titleCase(name);

    return ReceiptItem(name: name, price: price, quantity: qty);
  }

  static double? _parsePrice(String s) {
    // Normalize: remove thousands separators (space, NBSP, '.' when not last),
    // and convert decimal comma to dot.
    var cleaned = s.replaceAll(' ', ' ').trim();

    // Detect decimal separator: if the last "," or "." is followed by 1-2
    // digits and there's at least one digit before, treat as decimal.
    final decMatch = RegExp(r'([,.])\d{1,2}$').firstMatch(cleaned);
    String? decSep;
    if (decMatch != null) decSep = decMatch.group(1);

    // Remove all separators that aren't the decimal one.
    if (decSep != null) {
      cleaned = cleaned
          .replaceAll(decSep == ',' ? '.' : ',', '')
          .replaceAll(' ', '')
          .replaceFirst(decSep, '.');
    } else {
      cleaned = cleaned.replaceAll(RegExp(r'[ ,.]'), '');
    }

    return double.tryParse(cleaned);
  }

  static double? _extractTrailingPrice(String line) {
    final m = _trailingPrice.firstMatch(line);
    if (m == null) return null;
    return _parsePrice(m.group(1)!);
  }

  static String _titleCase(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
