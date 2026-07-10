import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveCsv(Uint8List bytes, String filename) async {
  final blob = html.Blob(<dynamic>[bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
