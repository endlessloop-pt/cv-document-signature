import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:meta/meta.dart';

/// One page rasterised to image bytes, carried together with both of its sizes.
///
/// Both are needed and they are not interchangeable: [pointSize] is the PDF's
/// own coordinate space (what the signature position must be expressed in) and
/// [pixelSize] is the raster we produced (what image-space work must use).
@immutable
class RenderedPdfPage {
  const RenderedPdfPage({
    required this.bytes,
    required this.pixelSize,
    required this.pointSize,
  });

  /// Encoded image bytes. The format is the renderer's choice.
  final Uint8List bytes;

  /// Size of [bytes] in pixels.
  final Size pixelSize;

  /// Size of the page in PDF user-space points.
  final Size pointSize;
}

/// An open document. Close it when finished — implementations hold native
/// resources.
abstract class PdfRenderSession {
  int get pageCount;

  /// The page's size in PDF points. [pageIndex] is 0-based.
  Future<Size> pagePointSize(int pageIndex);

  /// Rasterises the page at [dpi]. [pageIndex] is 0-based.
  Future<RenderedPdfPage> render(int pageIndex, {required int dpi});

  Future<void> close();
}

/// Opens PDFs for reading page metadata and rasterising pages.
///
/// This package deliberately ships only the interface. The two consuming apps
/// use different PDF engines — gov.cv rasterises with `pdfx` and views with
/// `pdfrx`, id.gov uses `pdfrx` — and each supplies its own implementation.
/// Declaring an engine here would force one app to ship the other's PDFium
/// build for nothing.
///
/// Implementations must treat [PdfRenderSession.pagePointSize] as cheap: the
/// CMD signing path opens a document solely to read one page's size.
abstract class PdfRenderer {
  Future<PdfRenderSession> open(Uint8List bytes);
}
