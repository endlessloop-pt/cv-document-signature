import 'dart:ui' show Rect, Size;

import 'package:meta/meta.dart';

/// Where a placement rectangle landed once it has been resolved against the
/// page it overlaps.
///
/// The three fields are exactly the arguments
/// `displayRectToPagePoints` needs, which is the only reason this type exists.
@immutable
class PagePlacement {
  const PagePlacement({
    required this.pageIndex,
    required this.rectInPageDisplay,
    required this.pageDisplaySize,
  });

  /// 0-based index of the page the rectangle sits on.
  final int pageIndex;

  /// The rectangle in that page's own display coordinates (top-left origin,
  /// same units as [pageDisplaySize]).
  final Rect rectInPageDisplay;

  /// The page's rendered size, i.e. the `displaySize` for the point conversion.
  final Size pageDisplaySize;

  @override
  bool operator ==(Object other) =>
      other is PagePlacement &&
      other.pageIndex == pageIndex &&
      other.rectInPageDisplay == rectInPageDisplay &&
      other.pageDisplaySize == pageDisplaySize;

  @override
  int get hashCode =>
      Object.hash(pageIndex, rectInPageDisplay, pageDisplaySize);

  @override
  String toString() => 'PagePlacement(pageIndex: $pageIndex, '
      'rectInPageDisplay: $rectInPageDisplay, '
      'pageDisplaySize: $pageDisplaySize)';
}

/// The vertical layout of a continuously scrolling, width-fitted page list, and
/// the arithmetic for mapping a scroll offset back onto a page.
///
/// This exists as a plain value object rather than as state inside a scrolling
/// widget so that the maths can be tested without a widget tree, and so that
/// two apps with different viewers can agree on it.
///
/// "Content" coordinates below mean distance from the top of the scrollable
/// content (what a `ScrollController.offset` of 0 shows), not from the top of
/// the viewport.
@immutable
class PdfPageLayout {
  PdfPageLayout({
    required this.pagePointSizes,
    required this.contentWidth,
    this.pageGap = 0,
    this.topPadding = 0,
  })  : assert(contentWidth > 0, 'contentWidth must be positive'),
        displayHeights = List<double>.unmodifiable(
          pagePointSizes.map(
            (p) => contentWidth * (p.height / p.width),
          ),
        );

  /// Each page's size in PDF points, in document order.
  final List<Size> pagePointSizes;

  /// The width every page is fitted to.
  final double contentWidth;

  /// Vertical space between consecutive pages, in display units.
  final double pageGap;

  /// Space above the first page, in display units.
  final double topPadding;

  /// Each page's rendered height, derived from [contentWidth] and the page's
  /// own aspect ratio.
  final List<double> displayHeights;

  int get pageCount => displayHeights.length;

  bool get isEmpty => displayHeights.isEmpty;

  /// Content-space Y of the top edge of page [index].
  double pageTop(int index) {
    var top = topPadding;
    for (var i = 0; i < index; i++) {
      top += displayHeights[i] + pageGap;
    }
    return top;
  }

  /// The page's rendered box.
  Size pageDisplaySize(int index) => Size(contentWidth, displayHeights[index]);

  /// Total scrollable height, including [topPadding] and the gaps between
  /// pages but not any bottom padding the caller may add.
  double get contentHeight {
    if (isEmpty) return topPadding;
    var total = topPadding;
    for (var i = 0; i < displayHeights.length; i++) {
      total += displayHeights[i];
      if (i < displayHeights.length - 1) total += pageGap;
    }
    return total;
  }

  /// The page [contentY] falls on.
  ///
  /// A point inside a page resolves to that page. Each page owns the half-open
  /// range `[top, bottom)`, so a point exactly on the seam between two pages
  /// belongs to the page that *starts* there.
  ///
  /// A point that is inside no page — in the gap between two, in the top
  /// padding, or beyond either end of the document — resolves to the page with
  /// the nearest centre, because the caller still needs exactly one answer.
  ///
  /// Deciding containment before distance matters: with pure nearest-centre,
  /// a point on a seam is equidistant from both pages and the winner is decided
  /// by floating-point rounding in the height sums, which is not something to
  /// let a signature's page number depend on.
  ///
  /// Returns 0 for an empty layout.
  int pageAt(double contentY) {
    if (isEmpty) return 0;
    var runningTop = topPadding;
    var nearest = 0;
    var minDistance = double.infinity;
    for (var i = 0; i < displayHeights.length; i++) {
      final top = runningTop;
      final bottom = top + displayHeights[i];
      if (contentY >= top && contentY < bottom) return i;
      final distance = (((top + bottom) / 2) - contentY).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearest = i;
      }
      runningTop = bottom + pageGap;
    }
    return nearest;
  }

  /// Resolves an overlay rectangle drawn in **viewport** coordinates against
  /// the page it sits on.
  ///
  /// [scrollOffset] is the scroll position the overlay was drawn at. The
  /// rectangle's vertical position is clamped into the page, so a rectangle
  /// dragged past the end of a page is placed at that page's edge rather than
  /// producing an out-of-page coordinate the PDF would reject.
  ///
  /// Returns null when the layout has no pages.
  PagePlacement? placementFor({
    required double scrollOffset,
    required Rect overlayRect,
  }) {
    if (isEmpty) return null;

    final rectCentreContent =
        scrollOffset + overlayRect.top + overlayRect.height / 2;
    final pageIndex = pageAt(rectCentreContent);
    final top = pageTop(pageIndex);
    final height = displayHeights[pageIndex];

    final maxY = (height - overlayRect.height).clamp(0.0, double.infinity);
    final rectInPage = Rect.fromLTWH(
      overlayRect.left,
      (scrollOffset + overlayRect.top - top).clamp(0.0, maxY),
      overlayRect.width,
      overlayRect.height,
    );

    return PagePlacement(
      pageIndex: pageIndex,
      rectInPageDisplay: rectInPage,
      pageDisplaySize: Size(contentWidth, height),
    );
  }
}
