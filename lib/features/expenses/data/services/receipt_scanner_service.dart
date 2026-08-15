import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/receipt_item.dart';
import 'receipt_parser.dart';
import 'receipt_text_layout.dart';

/// Runs on-device OCR via Google ML Kit on a receipt image and turns the
/// result into a [ScannedReceipt].
class ReceiptScannerService {
  final TextRecognizer _recognizer;

  ReceiptScannerService({TextRecognizer? recognizer})
      : _recognizer =
            recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  Future<ScannedReceipt> scanImage(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(input);
    return ReceiptParser.parse(_toRows(result));
  }

  /// Rebuilds rows from the recognized lines' positions rather than using
  /// [RecognizedText.text], whose block ordering separates a receipt's label
  /// column from its price column.
  static String _toRows(RecognizedText result) {
    final lines = <OcrLine>[
      for (final block in result.blocks)
        for (final line in block.lines)
          OcrLine(text: line.text, box: line.boundingBox),
    ];
    if (lines.isEmpty) return result.text;
    return ReceiptTextLayout.toRows(lines);
  }

  Future<void> dispose() => _recognizer.close();
}
