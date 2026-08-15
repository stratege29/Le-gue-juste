import 'dart:math' as math;
import 'dart:ui';

/// A single OCR line together with where it sits on the page.
class OcrLine {
  final String text;
  final Rect box;

  const OcrLine({required this.text, required this.box});
}

/// Rebuilds the visual rows of a receipt from positioned OCR lines.
///
/// ML Kit groups text into blocks, and a receipt whose labels and prices sit in
/// two well-separated columns often yields one block per column. Reading
/// `RecognizedText.text` then returns every label followed by every price, so no
/// label can be paired with its amount and the parser finds nothing. Grouping
/// lines by vertical overlap restores the rows the way a human reads them.
class ReceiptTextLayout {
  ReceiptTextLayout._();

  /// Fraction of the shorter line height that two lines must share vertically
  /// to be considered part of the same row.
  static const double _minOverlapRatio = 0.5;

  /// Turns positioned lines into newline-separated rows, each row's fragments
  /// ordered left to right.
  static String toRows(List<OcrLine> lines) {
    final usable = lines.where((l) => l.text.trim().isNotEmpty).toList()
      ..sort((a, b) => a.box.center.dy.compareTo(b.box.center.dy));

    final rows = <List<OcrLine>>[];
    for (final line in usable) {
      final current = rows.isEmpty ? null : rows.last;
      if (current != null && _sharesRow(_union(current), line.box)) {
        current.add(line);
      } else {
        rows.add([line]);
      }
    }

    return rows.map((row) {
      final ordered = [...row]..sort((a, b) => a.box.left.compareTo(b.box.left));
      // Two spaces: the parser requires whitespace before an amount, and a wide
      // gap is what separates a label from its price on a real receipt.
      return ordered.map((l) => l.text.trim()).join('  ');
    }).join('\n');
  }

  static Rect _union(List<OcrLine> row) =>
      row.map((l) => l.box).reduce((a, b) => a.expandToInclude(b));

  static bool _sharesRow(Rect a, Rect b) {
    final overlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    if (overlap <= 0) return false;
    final shorter = math.min(a.height, b.height);
    if (shorter <= 0) return false;
    return overlap / shorter >= _minOverlapRatio;
  }
}
