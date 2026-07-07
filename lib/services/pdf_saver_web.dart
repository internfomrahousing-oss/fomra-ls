// Web implementation: trigger a real browser download via a Blob + anchor.
// This avoids the printing plugin's method channel (net.nfet.printing), which
// isn't available for sharePdf on Flutter web.
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> savePdf(Uint8List bytes, String filename) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
