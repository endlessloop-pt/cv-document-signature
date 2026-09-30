import 'dart:ui' show Rect, Size;

import 'package:meta/meta.dart';

/// A rectangle expressed in PDF user-space points, with PDF's own axis
/// convention: the origin is the **bottom-left** of the page and Y grows
/// upwards.
///
/// This is the opposite of every Flutter [Rect], where Y grows downwards from
/// the top-left. Keeping the two in separate types is the whole point — the
/// flip is the single most common source of "the signature landed on the wrong
/// end of the page" bugs.
@immutable
class PdfRectInPoints {
  const PdfRectInPoints({
    required this.left,
    required this.bottom,
    required this.width,
    required this.height,
  });

  final double left;
  final double bottom;
  final double width;
  final double height;

  double get right => left + width;
  double get top => bottom + height;

  @override
  bool operator ==(Object other) =>
      other is PdfRectInPoints &&
      other.left == left &&
      other.bottom == bottom &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, bottom, width, height);

  @override
  String toString() =>
      'PdfRectInPoints(left: $left, bottom: $bottom, width: $width, height: $height)';
}

/// Converts a rectangle drawn on screen into PDF user-space points.
///
/// [displayRect] and [displaySize] are in the same (top-left origin) coordinate
/// space — typically the page's rendered box inside the viewer. [pagePointSize]
/// is the page's size in points as reported by the PDF itself.
///
/// The scale is derived from **width alone**, because both consuming apps lay
/// pages out width-fitted and derive the display height from the page's aspect
/// ratio. If a caller ever letterboxes a page instead, this function's
/// assumption breaks and the Y result will be wrong — pass the page's actual
/// rendered box as [displaySize], not the viewport.
PdfRectInPoints displayRectToPagePoints({
  required Rect displayRect,
  required Size displaySize,
  required Size pagePointSize,
}) {
  final scale = pagePointSize.width / displaySize.width;
  final left = displayRect.left * scale;
  final width = displayRect.width * scale;
  final height = displayRect.height * scale;
  final topFromDisplayTop = displayRect.top * scale;
  final bottom = pagePointSize.height - topFromDisplayTop - height;
  return PdfRectInPoints(
    left: left,
    bottom: bottom,
    width: width,
    height: height,
  );
}

/// The position the CMD sign API expects: the rectangle's **bottom-left corner**
/// in PDF points, plus a **1-based** page number.
///
/// Width and height are deliberately absent. The CMD server renders the visible
/// signature at its own size and ignores any extent we send, so carrying them
/// here would only invite a caller to believe otherwise.
@immutable
class CmdSignaturePosition {
  const CmdSignaturePosition({
    required this.page,
    required this.x,
    required this.y,
  });

  /// 1-based, as the CMD API numbers pages.
  final int page;
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is CmdSignaturePosition &&
      other.page == page &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(page, x, y);

  @override
  String toString() => 'CmdSignaturePosition(page: $page, x: $x, y: $y)';
}

/// Maps a placed rectangle and a **0-based** page index onto the payload the
/// CMD sign API wants.
///
/// The two conversions this performs are the two the API silently punishes if
/// you get them wrong: `y` is the rectangle's *bottom* (not its top), and the
/// page is 1-based (not 0-based).
CmdSignaturePosition cmdPositionFor({
  required PdfRectInPoints rect,
  required int pageIndex,
}) {
  return CmdSignaturePosition(
    page: pageIndex + 1,
    x: rect.left,
    y: rect.bottom,
  );
}
