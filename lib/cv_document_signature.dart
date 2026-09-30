/// UI-free document-signature logic shared by the Cabo Verde government mobile
/// apps (`gov.cv-mobile` and `id.gov.cv-mobile`).
///
/// Two things live here:
///
///  * **Placement geometry** — turning a rectangle the user dragged onto a
///    rendered page into a position in the PDF's own coordinate space.
///  * **The CMD signing client** — the OAuth + sign exchange with Autentika.
///
/// Deliberately absent: any widget, any PDF engine, any web-auth plugin. The
/// two apps' signing screens look nothing alike and they use different PDF
/// libraries; what they share is the arithmetic and the network contract.
library cv_document_signature;

export 'src/cmd/cmd_signature_client.dart';
export 'src/cmd/cmd_signature_config.dart';
export 'src/cmd/cmd_signature_exceptions.dart';
export 'src/cmd/web_authenticator.dart';
export 'src/geometry/page_layout.dart';
export 'src/geometry/pdf_geometry.dart';
export 'src/geometry/rect_placement.dart';
export 'src/geometry/signature_anchor.dart';
export 'src/rendering/pdf_renderer.dart';
