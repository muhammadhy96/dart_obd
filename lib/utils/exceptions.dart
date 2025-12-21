class OBDException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  OBDException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => 'OBDException: $message${cause != null ? " (cause: $cause)" : ""}';
}

class OBDTimeoutException extends OBDException {
  OBDTimeoutException(super.message, {super.cause, super.stackTrace});
}

class OBDConnectionException extends OBDException {
  OBDConnectionException(super.message, {super.cause, super.stackTrace});
}

class OBDProtocolException extends OBDException {
  OBDProtocolException(super.message, {super.cause, super.stackTrace});
}

class OBDResponseException extends OBDException {
  OBDResponseException(super.message, {super.cause, super.stackTrace});
}

class OBDNotConnectedException extends OBDException {
  OBDNotConnectedException() : super('Not connected');
}

class OBDUnsupportedCommand extends OBDException {
  OBDUnsupportedCommand(super.message);
}
