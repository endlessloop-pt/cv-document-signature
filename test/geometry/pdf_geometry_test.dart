import 'dart:ui' show Rect, Size;

import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a4 = Size(595, 842);

  group('displayRectToPagePoints', () {
    test('identity when display size equals page point size', () {
      const rect = Rect.fromLTWH(100, 200, 240, 48);
      final result = displayRectToPagePoints(
        displayRect: rect,
        displaySize: a4,
        pagePointSize: a4,
      );

      expect(result.left, closeTo(100, 1e-6));
      expect(result.width, closeTo(240, 1e-6));
      expect(result.height, closeTo(48, 1e-6));
      // Y is flipped: 842 - 200 - 48.
      expect(result.bottom, closeTo(594, 1e-6));
      expect(result.top, closeTo(642, 1e-6));
    });

    test('scales proportionally when display is half the page size', () {
      const displaySize = Size(297.5, 421);
      const rect = Rect.fromLTWH(50, 100, 100, 20);

      final result = displayRectToPagePoints(
        displayRect: rect,
        displaySize: displaySize,
        pagePointSize: a4,
      );

      expect(result.left, closeTo(100, 1e-6));
      expect(result.width, closeTo(200, 1e-6));
      expect(result.height, closeTo(40, 1e-6));
      expect(result.bottom, closeTo(602, 1e-6));
    });

    test('a rect at the display origin maps to the top of the page', () {
      const rect = Rect.fromLTWH(0, 0, 100, 20);
      final result = displayRectToPagePoints(
        displayRect: rect,
        displaySize: a4,
        pagePointSize: a4,
      );

      expect(result.left, closeTo(0, 1e-6));
      expect(result.bottom, closeTo(822, 1e-6));
      expect(result.top, closeTo(842, 1e-6));
    });

    test('a rect at the display bottom-right maps to the page bottom', () {
      const rect = Rect.fromLTWH(495, 822, 100, 20);
      final result = displayRectToPagePoints(
        displayRect: rect,
        displaySize: a4,
        pagePointSize: a4,
      );

      expect(result.bottom, closeTo(0, 1e-6));
      expect(result.top, closeTo(20, 1e-6));
      expect(result.left, closeTo(495, 1e-6));
      expect(result.right, closeTo(595, 1e-6));
    });

    test('non-square scale (width-fit on a tall display)', () {
      const displayWidth = 400.0;
      final displayHeight = displayWidth * (a4.height / a4.width);
      final displaySize = Size(displayWidth, displayHeight);
      const rect = Rect.fromLTWH(40, 80, 160, 32);

      final result = displayRectToPagePoints(
        displayRect: rect,
        displaySize: displaySize,
        pagePointSize: a4,
      );

      final scale = a4.width / displayWidth;
      expect(result.left, closeTo(40 * scale, 1e-6));
      expect(result.width, closeTo(160 * scale, 1e-6));
      expect(result.height, closeTo(32 * scale, 1e-6));
      expect(result.bottom, closeTo(a4.height - (80 + 32) * scale, 1e-6));
    });

    test('landscape pages scale by width like any other', () {
      const landscape = Size(842, 595);
      const displaySize = Size(421, 297.5);
      const rect = Rect.fromLTWH(100, 50, 80, 20);

      final result = displayRectToPagePoints(
        displayRect: rect,
        displaySize: displaySize,
        pagePointSize: landscape,
      );

      expect(result.left, closeTo(200, 1e-6));
      expect(result.width, closeTo(160, 1e-6));
      expect(result.bottom, closeTo(595 - 100 - 40, 1e-6));
    });
  });

  group('cmdPositionFor', () {
    test('x is left, y is bottom, and the page is 1-based', () {
      const rect = PdfRectInPoints(
        left: 295,
        bottom: 80,
        width: 200,
        height: 40,
      );

      final position = cmdPositionFor(rect: rect, pageIndex: 0);

      expect(position.x, closeTo(295, 1e-6));
      expect(position.y, closeTo(80, 1e-6));
      expect(position.page, 1);
    });

    test('carries the bottom edge, not the top', () {
      const rect = PdfRectInPoints(
        left: 10,
        bottom: 700,
        width: 100,
        height: 40,
      );

      final position = cmdPositionFor(rect: rect, pageIndex: 2);

      expect(position.y, closeTo(700, 1e-6));
      expect(position.y, isNot(closeTo(rect.top, 1e-6)));
      expect(position.page, 3);
    });

    test('composes with displayRectToPagePoints end to end', () {
      // The rectangle sits near the bottom of an A4 page shown 1:1.
      const rect = Rect.fromLTWH(295, 722, 200, 40);
      final inPoints = displayRectToPagePoints(
        displayRect: rect,
        displaySize: a4,
        pagePointSize: a4,
      );
      final position = cmdPositionFor(rect: inPoints, pageIndex: 0);

      expect(position.x, closeTo(295, 1e-6));
      expect(position.y, closeTo(842 - 722 - 40, 1e-6));
      expect(position.page, 1);
    });
  });
}
