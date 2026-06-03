class EdgeTtsException implements Exception {
  const EdgeTtsException(this.code, this.message, {this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'EdgeTtsException($code): $message';
    }
    return 'EdgeTtsException($code): $message; cause=$cause';
  }
}
