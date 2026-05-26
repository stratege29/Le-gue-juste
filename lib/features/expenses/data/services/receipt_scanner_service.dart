import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/receipt_item.dart';
import 'receipt_parser.dart';

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
    return ReceiptParser.parse(result.text);
  }

  Future<void> dispose() => _recognizer.close();
}
