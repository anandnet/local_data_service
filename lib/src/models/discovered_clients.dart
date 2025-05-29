import '../../local_data_service.dart';

class Discoveredclients {
  final List<LocalDataServiceClient> allDiscoveredClients;
  final LocalDataServiceClient? connectedClient;
  Discoveredclients({required this.allDiscoveredClients, this.connectedClient});
}
