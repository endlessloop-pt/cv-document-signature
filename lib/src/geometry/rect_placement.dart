import 'dart:ui' show Offset, Rect, Size;

import 'package:meta/meta.dart';

/// The position and size of the draggable signature zone, as an immutable value
/// the host widget can hold and replace.
///
/// Two positions are tracked, which is the subtle part. [intendedTopLeft] is
/// where the user last put the rectangle; [topLeft] is that position clamped
/// into the current [bounds]. When the bounds shrink — rotation, a keyboard
/// appearing, the viewer changing mode — the rectangle slides inward, and when
/// they grow again it returns to where the user left it. Clamping in place
/// would lose that intent permanently, one resize at a time.
@immutable
class SignatureRectPlacement {
  const SignatureRectPlacement._({
    required this.bounds,
    required this.size,
    required this.intendedTopLeft,
    required this.topLeft,
  });

  /// Creates a placement sized from [bounds], centred unless [initialTopLeft]
  /// says otherwise.
  factory SignatureRectPlacement({
    required Size bounds,
    double widthFraction = defaultWidthFraction,
    double aspectRatio = defaultAspectRatio,
    Offset? initialTopLeft,
  }) {
    final size = _sizeFor(
      bounds: bounds,
      widthFraction: widthFraction,
      aspectRatio: aspectRatio,
    );
    final intended = initialTopLeft ?? _centredTopLeft(bounds, size);
    return SignatureRectPlacement._(
      bounds: bounds,
      size: size,
      intendedTopLeft: intended,
      topLeft: _clamp(intended, bounds, size),
    );
  }

  /// Matches the sibling app's signature zone proportions.
  static const double defaultWidthFraction = 0.45;
  static const double defaultAspectRatio = 3.8;

  /// The area the rectangle may move within.
  final Size bounds;

  final Size size;

  /// Where the user last placed it, unclamped. See the class doc.
  final Offset intendedTopLeft;

  /// [intendedTopLeft] clamped into [bounds].
  final Offset topLeft;

  Rect get rect => topLeft & size;

  /// The rectangle moved by [delta], clamped. The clamped result becomes the
  /// new intent: a drag *is* the user expressing where they want it, so a drag
  /// that hits the edge should not be remembered as wanting to go further.
  SignatureRectPlacement movedBy(Offset delta) {
    final moved = _clamp(topLeft + delta, bounds, size);
    return SignatureRectPlacement._(
      bounds: bounds,
      size: size,
      intendedTopLeft: moved,
      topLeft: moved,
    );
  }

  /// The same placement re-fitted to new [bounds] (or new proportions),
  /// preserving [intendedTopLeft].
  SignatureRectPlacement resized({
    required Size bounds,
    double widthFraction = defaultWidthFraction,
    double aspectRatio = defaultAspectRatio,
  }) {
    final newSize = _sizeFor(
      bounds: bounds,
      widthFraction: widthFraction,
      aspectRatio: aspectRatio,
    );
    return SignatureRectPlacement._(
      bounds: bounds,
      size: newSize,
      intendedTopLeft: intendedTopLeft,
      topLeft: _clamp(intendedTopLeft, bounds, newSize),
    );
  }

  static Size _sizeFor({
    required Size bounds,
    required double widthFraction,
    required double aspectRatio,
  }) {
    final width = (bounds.width * widthFraction).clamp(1.0, bounds.width);
    final height = (width / aspectRatio).clamp(1.0, bounds.height);
    return Size(width, height);
  }

  static Offset _centredTopLeft(Size bounds, Size size) => Offset(
        ((bounds.width - size.width) / 2).clamp(0.0, double.infinity),
        ((bounds.height - size.height) / 2).clamp(0.0, double.infinity),
      );

  static Offset _clamp(Offset candidate, Size bounds, Size size) {
    final maxX = (bounds.width - size.width).clamp(0.0, double.infinity);
    final maxY = (bounds.height - size.height).clamp(0.0, double.infinity);
    return Offset(
      candidate.dx.clamp(0.0, maxX),
      candidate.dy.clamp(0.0, maxY),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SignatureRectPlacement &&
      other.bounds == bounds &&
      other.size == size &&
      other.intendedTopLeft == intendedTopLeft &&
      other.topLeft == topLeft;

  @override
  int get hashCode => Object.hash(bounds, size, intendedTopLeft, topLeft);

  @override
  String toString() =>
      'SignatureRectPlacement(rect: $rect, bounds: $bounds, '
      'intendedTopLeft: $intendedTopLeft)';
}
