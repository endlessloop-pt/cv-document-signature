# Changelog

## 0.1.0 — 2026-09-30

First extraction, from `gov.cv-mobile`'s `document_signature` feature
(branch `feature/biometrics-cmd-document-signature`).

* PDF placement geometry: `displayRectToPagePoints`, `PdfRectInPoints`,
  `cmdPositionFor`, `CmdSignaturePosition`.
* `PdfPageLayout` — scroll offset to page and page-local rectangle. Previously
  private state inside `PdfPager`, and untested.
* `SignatureRectPlacement` — drag and resize clamping for the signature zone.
  Previously private state inside `DraggableSignatureRect`, and untested.
* `anchorFor` — ink bounding box to placement anchor.
* `PdfRenderer` / `PdfRenderSession` / `RenderedPdfPage` interfaces.
* `CmdSignatureClient` — OAuth authorization-code + PKCE, and the sign request.

Behaviour changes made during extraction, both deliberate:

* The PKCE code verifier is generated with `Random.secure()`. The original used
  `Random()`, which is not cryptographically secure.
* The verifier alphabet is RFC 7636's unreserved set. The original omitted
  `-._~` and drew from a 62-character set.
