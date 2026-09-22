import 'dart:typed_data';
import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart' as web_pdf;

void triggerPdfDownloadWeb(Uint8List bytes, String filename) {
  web_pdf.downloadPdfWeb(bytes, filename);
}
