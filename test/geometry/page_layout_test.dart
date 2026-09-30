import 'dart:ui' show Rect, Size;

import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A4 at 400pt wide renders 400 x 566.05.
  const a4 = Size(595, 842);
  const contentWidth = 400.0;
  const a4DisplayHeight = contentWidth * (842 / 595);

  PdfPageLayout layoutOf(
    int pages, {
    double gap = 0,
    double topPadding = 0,
    List<Size>? sizes,
  }) =>
      PdfPageLayout(
        pagePointSizes: sizes ?? List<Size>.filled(pages, a4),
        contentWidth: contentWidth,
        pageGap: gap,
        topPadding: topPadding,
      );

  group('displayHeights', () {
    test('fits each page to the content width by its own aspect ratio', () {
      final layout = layoutOf(
        2,
        sizes: const <Size>[a4, Size(842, 595)], // portrait then landscape
      );

      expect(layout.displayHeights[0], closeTo(a4DisplayHeight, 1e-6));
      expect(layout.displayHeights[1], closeTo(contentWidth * (595 / 842), 1e-6));
    });

    test('is empty for a document with no pages', () {
      final layout = layoutOf(0);

      expect(layout.isEmpty, isTrue);
      expect(layout.pageCount, 0);
      expect(layout.contentHeight, 0);
    });
  });

  group('pageTop and contentHeight', () {
    test('stacks pages directly when there is no gap or padding', () {
      final layout = layoutOf(3);

      expect(layout.pageTop(0), closeTo(0, 1e-6));
      expect(layout.pageTop(1), closeTo(a4DisplayHeight, 1e-6));
      expect(layout.pageTop(2), closeTo(a4DisplayHeight * 2, 1e-6));
      expect(layout.contentHeight, closeTo(a4DisplayHeight * 3, 1e-6));
    });

    test('honours top padding and inter-page gaps', () {
      final layout = layoutOf(3, gap: 12, topPadding: 20);

      expect(layout.pageTop(0), closeTo(20, 1e-6));
      expect(layout.pageTop(1), closeTo(20 + a4DisplayHeight + 12, 1e-6));
      expect(layout.pageTop(2), closeTo(20 + (a4DisplayHeight + 12) * 2, 1e-6));
      // Two gaps for three pages, not three.
      expect(
        layout.contentHeight,
        closeTo(20 + a4DisplayHeight * 3 + 24, 1e-6),
      );
    });
  });

  group('pageAt', () {
    test('picks the page containing the point', () {
      final layout = layoutOf(3);

      expect(layout.pageAt(10), 0);
      expect(layout.pageAt(a4DisplayHeight + 10), 1);
      expect(layout.pageAt(a4DisplayHeight * 2 + 10), 2);
    });

    test('gives the seam to the page that starts there', () {
      final layout = layoutOf(2);

      // Each page owns [top, bottom), so the seam belongs to page 2. The point
      // of pinning this down is that it must not be decided by rounding.
      expect(layout.pageAt(a4DisplayHeight), 1);
      expect(layout.pageAt(a4DisplayHeight + 1), 1);
      expect(layout.pageAt(a4DisplayHeight - 1), 0);
    });

    test('a point inside a page always wins over a nearer centre', () {
      // Page 1 is tall, page 2 is short: a point low on page 1 is closer to
      // page 2's centre, but it is still on page 1.
      final layout = layoutOf(
        2,
        sizes: const <Size>[Size(595, 2000), Size(595, 200)],
      );
      final tallHeight = layout.displayHeights[0];

      expect(layout.pageAt(tallHeight - 1), 0);
    });

    test('resolves a point inside a gap to the nearer page', () {
      final layout = layoutOf(2, gap: 40);
      const gapTop = a4DisplayHeight;

      expect(layout.pageAt(gapTop + 1), 0);
      expect(layout.pageAt(gapTop + 39), 1);
    });

    test('clamps beyond either end of the document', () {
      final layout = layoutOf(3);

      expect(layout.pageAt(-5000), 0);
      expect(layout.pageAt(5000), 2);
    });

    test('returns 0 for an empty layout rather than throwing', () {
      expect(layoutOf(0).pageAt(123), 0);
    });
  });

  group('placementFor', () {
    const overlay = Rect.fromLTWH(50, 100, 180, 48);

    test('maps an unscrolled overlay onto the first page', () {
      final layout = layoutOf(3);

      final placement = layout.placementFor(
        scrollOffset: 0,
        overlayRect: overlay,
      )!;

      expect(placement.pageIndex, 0);
      expect(placement.rectInPageDisplay, overlay);
      expect(
        placement.pageDisplaySize,
        Size(contentWidth, layout.displayHeights[0]),
      );
    });

    test('subtracts the page top once scrolled onto a later page', () {
      final layout = layoutOf(3);
      // Scroll so the overlay sits 100pt into page 2.
      final scrollOffset = a4DisplayHeight + 100 - overlay.top;

      final placement = layout.placementFor(
        scrollOffset: scrollOffset,
        overlayRect: overlay,
      )!;

      expect(placement.pageIndex, 1);
      expect(placement.rectInPageDisplay.top, closeTo(100, 1e-6));
      expect(placement.rectInPageDisplay.left, closeTo(50, 1e-6));
      expect(placement.rectInPageDisplay.width, closeTo(180, 1e-6));
    });

    test('clamps a rectangle hanging off the bottom back onto the page', () {
      final layout = layoutOf(2);
      // Centre the rectangle 5pt above the end of page 1, so the rectangle
      // still belongs to page 1 while its lower half spills past the edge.
      final scrollOffset =
          a4DisplayHeight - 5 - (overlay.top + overlay.height / 2);

      final placement = layout.placementFor(
        scrollOffset: scrollOffset,
        overlayRect: overlay,
      )!;

      expect(placement.pageIndex, 0);
      expect(
        placement.rectInPageDisplay.bottom,
        lessThanOrEqualTo(layout.displayHeights[0] + 1e-6),
      );
    });

    test('never returns a negative top', () {
      final layout = layoutOf(2);

      final placement = layout.placementFor(
        scrollOffset: -500,
        overlayRect: overlay,
      )!;

      expect(placement.rectInPageDisplay.top, greaterThanOrEqualTo(0));
    });

    test('accounts for top padding when resolving the page', () {
      final layout = layoutOf(2, topPadding: 60);

      final placement = layout.placementFor(
        scrollOffset: 0,
        overlayRect: overlay,
      )!;

      expect(placement.pageIndex, 0);
      // The overlay is 100 from the content top, the page starts at 60.
      expect(placement.rectInPageDisplay.top, closeTo(40, 1e-6));
    });

    test('returns null when the document has no pages', () {
      expect(
        layoutOf(0).placementFor(scrollOffset: 0, overlayRect: overlay),
        isNull,
      );
    });

    test('feeds displayRectToPagePoints with a consistent pair', () {
      final layout = layoutOf(2);
      final scrollOffset = a4DisplayHeight + 100 - overlay.top;

      final placement = layout.placementFor(
        scrollOffset: scrollOffset,
        overlayRect: overlay,
      )!;
      final inPoints = displayRectToPagePoints(
        displayRect: placement.rectInPageDisplay,
        displaySize: placement.pageDisplaySize,
        pagePointSize: a4,
      );
      final position = cmdPositionFor(
        rect: inPoints,
        pageIndex: placement.pageIndex,
      );

      expect(position.page, 2);
      expect(position.x, greaterThan(0));
      expect(position.y, greaterThan(0));
      expect(position.y, lessThan(a4.height));
    });
  });
}
