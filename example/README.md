# Example

`geometry_pipeline.dart` walks a dragged rectangle through every conversion
between the viewer and the CMD sign API: page resolution, display units to PDF
points with the Y flip, then the bottom-left point and 1-based page.

It needs no PDF file, no PDF engine and no widgets, but it does need the Flutter
VM for `dart:ui`, so run it as a test rather than with `dart run`:

```sh
flutter test test/example_test.dart
```

That test asserts the output, so this example cannot quietly stop matching the
API it documents.
