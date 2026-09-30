import 'dart:ui' show Offset, Size;

import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bounds = Size(400, 800);

  group('sizing', () {
    test('takes the given fraction of the width at the given aspect ratio', () {
      final placement = SignatureRectPlacement(bounds: bounds);

      expect(placement.size.width, closeTo(400 * 0.45, 1e-6));
      expect(
        placement.size.height,
        closeTo(400 * 0.45 / SignatureRectPlacement.defaultAspectRatio, 1e-6),
      );
    });

    test('never exceeds the bounds, however extreme the ratio', () {
      final placement = SignatureRectPlacement(
        bounds: const Size(400, 20),
        widthFraction: 2.0,
        aspectRatio: 0.1,
      );

      expect(placement.size.width, lessThanOrEqualTo(400));
      expect(placement.size.height, lessThanOrEqualTo(20));
    });

    test('never collapses to zero', () {
      final placement = SignatureRectPlacement(
        bounds: const Size(400, 800),
        widthFraction: 0.0,
      );

      expect(placement.size.width, greaterThanOrEqualTo(1));
      expect(placement.size.height, greaterThanOrEqualTo(1));
    });
  });

  group('initial position', () {
    test('centres by default', () {
      final placement = SignatureRectPlacement(bounds: bounds);

      expect(
        placement.topLeft.dx,
        closeTo((400 - placement.size.width) / 2, 1e-6),
      );
      expect(
        placement.topLeft.dy,
        closeTo((800 - placement.size.height) / 2, 1e-6),
      );
    });

    test('honours an explicit starting point', () {
      final placement = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: const Offset(10, 20),
      );

      expect(placement.topLeft, const Offset(10, 20));
    });

    test('clamps a starting point that is outside the bounds', () {
      final placement = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: const Offset(9999, 9999),
      );

      expect(
        placement.topLeft.dx,
        closeTo(400 - placement.size.width, 1e-6),
      );
      expect(
        placement.topLeft.dy,
        closeTo(800 - placement.size.height, 1e-6),
      );
    });
  });

  group('movedBy', () {
    test('translates the rectangle', () {
      final moved = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: Offset.zero,
      ).movedBy(const Offset(30, 40));

      expect(moved.topLeft, const Offset(30, 40));
      expect(moved.rect.left, 30);
      expect(moved.rect.top, 40);
    });

    test('stops at the edges instead of leaving the bounds', () {
      final start = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: Offset.zero,
      );

      final pastTopLeft = start.movedBy(const Offset(-100, -100));
      expect(pastTopLeft.topLeft, Offset.zero);

      final pastBottomRight = start.movedBy(const Offset(9999, 9999));
      expect(
        pastBottomRight.topLeft.dx,
        closeTo(400 - start.size.width, 1e-6),
      );
      expect(
        pastBottomRight.topLeft.dy,
        closeTo(800 - start.size.height, 1e-6),
      );
    });

    test('a drag into an edge forgets the overshoot', () {
      // Otherwise the rectangle would leap when the bounds later grow.
      final atEdge = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: Offset.zero,
      ).movedBy(const Offset(-500, 0));

      expect(atEdge.intendedTopLeft, atEdge.topLeft);
    });
  });

  group('resized', () {
    test('keeps the rectangle inside the new, smaller bounds', () {
      final start = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: const Offset(300, 700),
      );

      final shrunk = start.resized(bounds: const Size(200, 300));

      expect(shrunk.topLeft.dx, lessThanOrEqualTo(200 - shrunk.size.width));
      expect(shrunk.topLeft.dy, lessThanOrEqualTo(300 - shrunk.size.height));
    });

    test('restores the original position when the bounds grow back', () {
      // This is the reason intendedTopLeft exists: a transient shrink — a
      // rotation, a keyboard — must not permanently drag the signature zone
      // toward the top-left.
      final start = SignatureRectPlacement(
        bounds: bounds,
        initialTopLeft: const Offset(300, 700),
      );

      final restored =
          start.resized(bounds: const Size(200, 300)).resized(bounds: bounds);

      expect(restored.topLeft, start.topLeft);
      expect(restored.size, start.size);
    });

    test('re-fits the size to the new width', () {
      final resized =
          SignatureRectPlacement(bounds: bounds).resized(bounds: const Size(800, 800));

      expect(resized.size.width, closeTo(800 * 0.45, 1e-6));
    });
  });
}
