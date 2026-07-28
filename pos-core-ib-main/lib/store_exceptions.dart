class StoreException implements Exception {
  final String message;

  const StoreException(this.message);

  @override
  String toString() => message;
}

class StoreAuthException extends StoreException {
  const StoreAuthException(super.message);
}

class StoreAuthorizationException extends StoreException {
  const StoreAuthorizationException(super.message);
}

class StoreSessionExpiredException extends StoreAuthException {
  const StoreSessionExpiredException(super.message);
}

class StoreOrderStateException extends StoreException {
  const StoreOrderStateException(super.message);
}

class StoreCreditRepaymentStateException extends StoreException {
  const StoreCreditRepaymentStateException(super.message);
}

class StoreDeviceAccessException extends StoreException {
  const StoreDeviceAccessException(super.message);
}

class StorePrinterException extends StoreException {
  const StorePrinterException(super.message);
}