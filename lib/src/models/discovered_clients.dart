import '../../local_data_service.dart';

/// A class that holds the discovered clients and the currently connected client.
class Discoveredclients {

  /// A list of all discovered clients.
  final List<LocalDataServiceClient> allDiscoveredClients;

  /// The currently connected client, if any.
  final LocalDataServiceClient? connectedClient;

  /// Creates a new instance of [Discoveredclients].
  Discoveredclients({required this.allDiscoveredClients, this.connectedClient});
}
