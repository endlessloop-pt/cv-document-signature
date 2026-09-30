# cv_document_signature

UI-free document-signature logic shared by the two Cabo Verde government mobile
apps — `gov.cv` and `id.gov.cv` (the wallet).

Two things live here:

* **Placement geometry** — turning a rectangle the user dragged onto a rendered
  page into a position in the PDF's own coordinate space.
* **The CMD signing client** — the OAuth + sign exchange with Autentika's Chave
  Móvel Digital service.

Deliberately absent: any widget, any PDF engine, any web-auth plugin. The two
apps' signing screens look nothing alike and they use different PDF libraries.
What they share is the arithmetic and the network contract, and that is all this
package contains.

> **There is no client-side cryptography here beyond PKCE.** The CMD service
> signs the document and draws the visible signature itself. This package
> uploads the original bytes plus a position, and downloads the result. Nothing
> computes a document hash, builds a PKCS#7 blob, or modifies a PDF.

## Installing

```yaml
dependencies:
  cv_document_signature:
    git:
      url: https://github.com/endlessloop-pt/cv-document-signature.git
      ref: 0.1.0   # always pin a tag
```

Supports Dart 3.5+ / Flutter 3.24+, which is what the older of the two apps
runs. Verified against both Flutter 3.24.4 and 3.27.4.

Its only dependencies are `http`, `crypto`, `uuid` and `meta` — all of which
both apps already ship, so adopting this costs neither of them a new package.

## The coordinate pipeline

This is the part worth understanding before using anything else. Four
conversions stand between "the user dragged a box" and "the signature is in the
right place", and three of them are easy to get subtly wrong.

```
  overlay rect, in viewport coordinates
         │   PdfPageLayout.placementFor(scrollOffset:, overlayRect:)
         │     → which page, and where on that page
         ▼
  PagePlacement { pageIndex, rectInPageDisplay, pageDisplaySize }
         │   displayRectToPagePoints(...)
         │     → display pixels to PDF points, and Y flips to bottom-up
         ▼
  PdfRectInPoints { left, bottom, width, height }
         │   cmdPositionFor(rect:, pageIndex:)
         │     → bottom-left corner, and the page becomes 1-based
         ▼
  CmdSignaturePosition { page, x, y }   →   CmdSignatureClient.sign(...)
```

The three traps, all encoded in the types and covered by tests:

1. **PDF's Y axis points up** from the bottom-left of the page; Flutter's points
   down from the top-left. `PdfRectInPoints` has a `bottom`, not a `top`, so the
   two cannot be confused by accident.
2. **The CMD API numbers pages from 1**, while everything else here is 0-based.
   `cmdPositionFor` is the single place that conversion happens.
3. **The CMD API wants the rectangle's bottom-left point, not its centre or its
   top-left**, and it ignores the extent entirely — it sizes the visible
   signature itself. `CmdSignaturePosition` therefore carries no width or
   height, so no caller can believe otherwise.

### Example

```dart
final placement = layout.placementFor(
  scrollOffset: scrollController.offset,
  overlayRect: draggedRect,
);
if (placement == null) return; // empty document

final inPoints = displayRectToPagePoints(
  displayRect: placement.rectInPageDisplay,
  displaySize: placement.pageDisplaySize,
  pagePointSize: await session.pagePointSize(placement.pageIndex),
);

final position = cmdPositionFor(
  rect: inPoints,
  pageIndex: placement.pageIndex,
);
```

`example/geometry_pipeline.dart` is this same walk with every intermediate value
printed, and `test/example_test.dart` asserts its output — so the example, and
these snippets, cannot quietly stop matching the API. Run it with
`flutter test test/example_test.dart`.

## Rendering

The package ships the `PdfRenderer` / `PdfRenderSession` / `RenderedPdfPage`
interfaces and no implementation, so each app keeps the PDF engine it already
has rather than shipping a second PDFium build. A pdfx-backed adapter is about
forty lines:

```dart
class PdfxPdfRenderer implements PdfRenderer {
  const PdfxPdfRenderer();

  @override
  Future<PdfRenderSession> open(Uint8List bytes) async =>
      _PdfxSession(await pdfx.PdfDocument.openData(bytes));
}
```

`pagePointSize` should be cheap: the CMD path opens a document purely to read
one page's size.

## Signing with CMD

```dart
final client = CmdSignatureClient(
  config: CmdSignatureConfig(
    authorizeUrl: Uri.parse(env.cmdAuthorizeUrl),
    tokenUrl: Uri.parse(env.cmdTokenUrl),
    signUrl: Uri.parse(env.cmdSignUrl),
    clientId: env.cmdClientId,
    redirectUri: env.cmdRedirectUri,   // e.g. 'myapp://oauth'
  ),
  webAuthenticator: MyWebAuthenticator(),
  onError: logger.error,
);

final token = await client.authenticate();       // OAuth + PKCE
final signedPdf = await client.sign(
  accessToken: token,
  pin: pinTypedByTheUser,
  documentBytes: originalPdfBytes,               // NOT a modified copy
  page: position.page,
  x: position.x,
  y: position.y,
);
```

Then submit `signedPdf` to your own backend. **The CMD service does not notify
either app's backend** — it signs the document and returns it, nothing more.

Things the client guarantees, each with a test that would fail if it stopped
being true:

* No `client_secret` is ever sent. This is a public OAuth client and PKCE is
  what proves the token exchange belongs to the app that started the flow.
* The PKCE code verifier comes from `Random.secure()`.
* The returned `state` is checked against the one sent, and neither value is
  ever written to the log sink.
* The PIN never reaches the log sink or an exception message.
* `sign()` gives up after 120 seconds — signing is slow server-side and the
  default matches the native Android app.
* `failed: true` in the body is an error even with a 200 status, and the
  "digital signature not active" message is mapped to its own exception whatever
  status carries it.

### What the host app must provide

* A `WebAuthenticator` implementation. The doc comment on the interface has a
  ready-made `flutter_web_auth` adapter. It should throw
  `CmdSignatureCancelledException` when the user dismisses the browser, so the
  caller can tell "went back" from "went wrong".
* The custom URL scheme in `AndroidManifest.xml` (the web-auth plugin's callback
  activity) and `Info.plist` (`CFBundleURLSchemes`). Without it the OAuth
  callback never returns to the app. Each app uses its own scheme.
* An OAuth client provisioned for that redirect URI and the `cmd` scope. The
  apps' ordinary sign-in clients use `openid` alone and will not work here.

## Known limitations

* **Page rotation (`/Rotate`) is not handled.** `displayRectToPagePoints`
  assumes the page's point size is already in its displayed orientation. If a
  renderer reports unrotated dimensions for a rotated page, the signature will
  be misplaced on that page. Neither app has hit this yet; it has not been
  designed away, only not encountered.
* **Width-fit layout is assumed.** The scale comes from width alone, because
  both apps fit pages to the content width. A letterboxed viewer would need a
  different conversion.

## Provenance

Extracted from `gov.cv-mobile`'s `document_signature` feature (branch
`feature/biometrics-cmd-document-signature`). The raster stamping used by that
app's hand-drawn signature flow deliberately stayed behind: it has one consumer,
the wallet never calls it, and bringing it here would have forced `pdfx`, `pdf`
and `image` onto both apps.

`PdfPageLayout` and `SignatureRectPlacement` were private state inside
`PdfPager` and `DraggableSignatureRect` — untestable in place, and untested. See
`CHANGELOG.md` for the two behaviour changes made during extraction.
