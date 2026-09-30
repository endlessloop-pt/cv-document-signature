// Compiles and runs example/geometry_pipeline.dart, so the example — and the
// README snippets that mirror it — cannot drift away from the real API.

import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/geometry_pipeline.dart';

void main() {
  test('the example pipeline produces the payload it claims to', () {
    final report = describeGeometryPipeline();

    // The rectangle was scrolled onto the second page and sits 40pt down it.
    expect(report, contains('page index (0-based) : 1'));
    expect(report, contains('CMD page (1-based)   : 2'));

    // Y is measured from the bottom of the page, so it must be neither the
    // display offset (40-ish) nor the page height.
    final placement = layout.placementFor(
      scrollOffset: scrollOffset,
      overlayRect: draggedRect,
    )!;
    final inPoints = displayRectToPagePoints(
      displayRect: placement.rectInPageDisplay,
      displaySize: placement.pageDisplaySize,
      pagePointSize: layout.pagePointSizes[1],
    );
    final position = cmdPositionFor(rect: inPoints, pageIndex: 1);

    expect(position.y, closeTo(inPoints.bottom, 1e-9));
    expect(position.y, greaterThan(700));
    expect(position.x, closeTo(inPoints.left, 1e-9));
    expect(report, contains('CMD y (from bottom)  : ${position.y}'));
  });
}
