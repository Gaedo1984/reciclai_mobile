class ReciclaiApiException implements Exception {
  const ReciclaiApiException(this.message);

  final String message;

  @override
  String toString() => 'ReciclaiApiException: $message';
}
