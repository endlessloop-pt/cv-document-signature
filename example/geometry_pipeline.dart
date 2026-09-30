// Runs the placement pipeline end to end, with no PDF engine and no widgets:
// a rectangle the user dragged, through to the payload the CMD sign API wants.
//
// `dart example/geometry_pipeline.dart` will not work — the package uses
// `dart:ui` types, so this runs on the Flutter test VM instead:
//
//     flutter test test/example_test.dart
//
// which is also what keeps this file, and the snippets in README.md that mirror
// it, from drifting away from the real API.

import 'dart:io' show stdout;
import 'dart:ui' show Rect, Size;

import 'package:cv_document_signature/cv_document_signature.dart';

/// A two-page A4 document shown in a 400pt-wide viewer.
final PdfPageLayout layout = PdfPageLayout(
  pagePointSizes: const <Size>[Size(595, 842), Size(595, 842)],
  contentWidth: 400,
);

/// Where the user dropped the signature zone, in viewport coordinates.
const Rect draggedRect = Rect.fromLTWH(60, 120, 180, 48);

/// Scrolled far enough that the zone sits over the second page.
final double scrollOffset = layout.pageTop(1) + 40 - draggedRect.top;

String describeGeometryPipeline() {
  final buffer = StringBuffer();

  // 1. Which page is the rectangle on, and where on that page?
  final placement = layout.placementFor(
    scrollOffset: scrollOffset,
    overlayRect: draggedRect,
  );
  if (placement == null) return 'The document has no pages.';

  buffer.writeln('page index (0-based) : ${placement.pageIndex}');
  buffer.writeln('rect on page         : ${placement.rectInPageDisplay}');
  buffer.writeln('page display size    : ${placement.pageDisplaySize}');

  // 2. Display units to PDF points. The Y axis flips here.
  //
  // A real caller reads the page size from a PdfRenderSession; this example has
  // no PDF, so it uses the size it built the layout from.
  final inPoints = displayRectToPagePoints(
    displayRect: placement.rectInPageDisplay,
    displaySize: placement.pageDisplaySize,
    pagePointSize: layout.pagePointSizes[placement.pageIndex],
  );

  buffer.writeln('rect in points       : $inPoints');

  // 3. The payload: bottom-left corner, 1-based page, no extent.
  final position = cmdPositionFor(
    rect: inPoints,
    pageIndex: placement.pageIndex,
  );

  buffer.writeln('CMD page (1-based)   : ${position.page}');
  buffer.writeln('CMD x                : ${position.x}');
  buffer.writeln('CMD y (from bottom)  : ${position.y}');

  return buffer.toString();
}

void main() => stdout.write(describeGeometryPipeline());
