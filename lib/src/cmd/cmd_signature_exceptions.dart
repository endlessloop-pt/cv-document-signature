/// Any failure of the CMD signing flow — OAuth or the sign request itself.
///
/// [detail] is for logs and bug reports, never for display: it is not
/// localized, and the two apps localize their own messages.
class CmdSignatureException implements Exception {
  const CmdSignatureException([this.detail]);

  final String? detail;

  @override
  String toString() => 'CmdSignatureException(${detail ?? ''})';
}

/// The user's CMD account does not have digital signature enabled.
///
/// Worth its own type because it is the one failure the user can actually fix,
/// and both apps show a different message for it.
class CmdSignatureNotActiveException extends CmdSignatureException {
  const CmdSignatureNotActiveException()
      : super('Digital signature not active for the user');
}

/// The user dismissed the OAuth web flow.
///
/// Not an error: the caller should return to the document, not show a failure.
class CmdSignatureCancelledException extends CmdSignatureException {
  const CmdSignatureCancelledException() : super('Cancelled by the user');
}
