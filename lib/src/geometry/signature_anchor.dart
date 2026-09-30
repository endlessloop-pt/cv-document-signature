import 'dart:ui' show Rect, Size;

import 'package:meta/meta.dart';

/// Where, as a fraction of the placement rectangle, the drawn ink should sit.
///
/// `(0.5, 0.5)` is dead centre; `(0, 0)` hugs the top-left.
@immutable
class SignatureAnchor {
  const SignatureAnchor(this.fx, this.fy);

  static const SignatureAnchor centre = SignatureAnchor(0.5, 0.5);

  final double fx;
  final double fy;

  @override
  bool operator ==(Object other) =>
      other is SignatureAnchor && other.fx == fx && other.fy == fy;

  @override
  int get hashCode => Object.hash(fx, fy);

  @override
  String toString() => 'SignatureAnchor($fx, $fy)';
}

/// Derives an anchor from where the ink was actually drawn on the pad.
///
/// [inkBounds] is the bounding box of the strokes, in the same coordinate space
/// as [canvasSize]. Someone who signs in the left half of the pad expects the
/// signature to sit on the left of the zone, not to be re-centred; this is what
/// carries that intent through.
///
/// Falls back to [SignatureAnchor.centre] when the canvas has no area, which
/// reproduces the old always-centred behaviour rather than dividing by zero.
SignatureAnchor anchorFor({
  required Rect inkBounds,
  required Size canvasSize,
}) {
  if (canvasSize.width <= 0 || canvasSize.height <= 0) {
    return SignatureAnchor.centre;
  }
  return SignatureAnchor(
    (inkBounds.center.dx / canvasSize.width).clamp(0.0, 1.0),
    (inkBounds.center.dy / canvasSize.height).clamp(0.0, 1.0),
  );
}
