// Mobile/desktop implementation: the printing plugin's share sheet works on
// these platforms.
import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> savePdf(Uint8List bytes, String filename) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}
