/// Domain errors whose `message` is shown to the admin as SnackBar text.
abstract class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class StockException extends AppException {
  const StockException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class DeleteBlockedException extends AppException {
  const DeleteBlockedException(super.message);
}

class CsvException extends AppException {
  const CsvException(super.message);
}

class StorageException extends AppException {
  const StorageException(super.message);
}
