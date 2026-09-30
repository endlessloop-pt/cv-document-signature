import 'dart:ui' show Rect, Size;

import 'package:cv_document_signature/cv_document_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canvas = Size(400, 200);

  test('ink drawn in the middle anchors to the centre', () {
    final anchor = anchorFor(
      inkBounds: const Rect.fromLTWH(150, 75, 100, 50),
      canvasSize: canvas,
    );

    expect(anchor.fx, closeTo(0.5, 1e-6));
    expect(anchor.fy, closeTo(0.5, 1e-6));
  });

  test('ink drawn on the left anchors left', () {
    final anchor = anchorFor(
      inkBounds: const Rect.fromLTWH(0, 75, 80, 50),
      canvasSize: canvas,
    );

    expect(anchor.fx, closeTo(0.1, 1e-6));
    expect(anchor.fy, closeTo(0.5, 1e-6));
  });

  test('ink drawn near the top anchors up', () {
    final anchor = anchorFor(
      inkBounds: const Rect.fromLTWH(150, 0, 100, 20),
      canvasSize: canvas,
    );

    expect(anchor.fy, closeTo(0.05, 1e-6));
  });

  test('ink outside the canvas is clamped to the 0..1 range', () {
    final anchor = anchorFor(
      inkBounds: const Rect.fromLTWH(-500, -500, 10, 10),
      canvasSize: canvas,
    );

    expect(anchor.fx, 0.0);
    expect(anchor.fy, 0.0);
  });

  test('a zero-area canvas falls back to centre instead of dividing by zero',
      () {
    expect(
      anchorFor(inkBounds: Rect.zero, canvasSize: Size.zero),
      SignatureAnchor.centre,
    );
    expect(
      anchorFor(inkBounds: Rect.zero, canvasSize: const Size(0, 200)),
      SignatureAnchor.centre,
    );
  });
}
