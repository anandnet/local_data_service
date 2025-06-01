class LocalDataServiceNotRunningException implements Exception {
  final String message;

  LocalDataServiceNotRunningException(
      [this.message =
          '''LocalDataService is not running, Perhaps you forgot to initialize or you have closed the local data service.
             Please initialize again''']);

  @override
  String toString() => message;
}
