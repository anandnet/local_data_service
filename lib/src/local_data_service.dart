import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'models/local_data_service_client.dart';
import 'models/discovered_clients.dart';

import 'socket/client.dart';
import 'socket/server.dart';

class LocalDataService {
  late String _serviceName;
  late (String, String) _deviceDetails;
  late BonsoirBroadcast _broadcast;
  late BonsoirDiscovery _discovery;
  late Server _dataServer;
  Client? _dataClient;
  late StreamSubscription<(bool, String?)>
      _dataServerConnectionStreamSubscription;
  StreamSubscription<BonsoirDiscoveryEvent>? _bonsoirDiscoveryEventSubscription;
  final List<LocalDataServiceClient> _localDataServiceClients = [];
  final StreamController<Discoveredclients> _discoveredClients =
      StreamController<Discoveredclients>.broadcast();
  LocalDataServiceClient? _connectedClient;

  final StreamController<List<int>> _rawMessageStreamController =
      StreamController<List<int>>();

  Stream<Discoveredclients> get discoveredClientsStream =>
      _discoveredClients.stream;

  Stream<List<int>> get rawMessageStream => _rawMessageStreamController.stream;

  LocalDataServiceClient? get connectedClient => _connectedClient;
  List<LocalDataServiceClient> get discoveredClients =>
      _localDataServiceClients;

  /// initiates local data service
  ///
  /// length of `serviceId` should be less than or equal to 15 chars.
  /// Example: `awesomeservice` or `awesome-service`
  Future<void> init(
      {required String serviceId,
      bool startbroadcastAtInit = true,
      bool startDiscoveryAtInit = true,
      String? deviceName,
      int port = 62527}) async {
    if (serviceId.length > 15) {
      serviceId = serviceId.substring(0, 15);
    }
    _serviceName = '_$serviceId._tcp';
    _deviceDetails = await _deviceInfo;

    /// if device name provided by user it will replace device name
    _deviceDetails = (deviceName ?? _deviceDetails.$1, _deviceDetails.$2);

    // init data server
    _dataServer =
        Server(rawMessageStreamController: _rawMessageStreamController);
    await _dataServer.init(port, _rawMessageStreamController);

    final BonsoirService service = BonsoirService(
        name: _deviceDetails.$1,
        type: _serviceName,
        port: port,
        attributes: {'id': _deviceDetails.$2});
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast.ready;

    if (startbroadcastAtInit) {
      await _broadcast.start();
    }

    startDiscovery();
    _listenDataServerConnection();
  }

  /// returns (deviceName, deviceId)
  Future<(String, String)> get _deviceInfo async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    (String, String) deviceInfoTemp = ("", "");
    if (Platform.isAndroid) {
      final deviceDetails = (await deviceInfo.androidInfo);
      deviceInfoTemp =
          (deviceDetails.name, "${deviceDetails.name}@${deviceDetails.host}");
    } else if (Platform.isWindows) {
      final deviceDetails = (await deviceInfo.windowsInfo);
      deviceInfoTemp = (deviceDetails.computerName, deviceDetails.deviceId);
    } else if (Platform.isLinux) {
      final deviceDetails = (await deviceInfo.linuxInfo);
      deviceInfoTemp = (
        deviceDetails.name,
        deviceDetails.machineId ??
            "${deviceDetails.name}@${deviceDetails.prettyName}"
      );
    } else if (Platform.isIOS) {
      final deviceDetails = (await deviceInfo.iosInfo);
      deviceInfoTemp =
          (deviceDetails.name, "${deviceDetails.name}@${deviceDetails.model}");
    } else if (Platform.isMacOS) {
      final deviceDetails = (await deviceInfo.macOsInfo);
      deviceInfoTemp = (
        deviceDetails.computerName,
        "${deviceDetails.computerName}@${deviceDetails.model}"
      );
    }
    return deviceInfoTemp;
  }

  Future<void> startDiscovery() async {
    _discovery = BonsoirDiscovery(type: _serviceName);
    await _discovery.ready;

    _bonsoirDiscoveryEventSubscription =
        _discovery.eventStream!.listen((event) async {
      if (event.service == null || event.service?.name == _deviceDetails.$1) {
        return;
      }

      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        final client = LocalDataServiceClient(service: event.service);
        print('Service found : ${event.service?.toString()}');

        if (_localDataServiceClients.indexWhere((c) => c.name == client.name) ==
            -1) {
          _localDataServiceClients
              .add(LocalDataServiceClient(service: event.service!));
        }
      } else if (event.type ==
          BonsoirDiscoveryEventType.discoveryServiceResolved) {
        /// This will encountered when user try to connect a other clients
        _connectedClient = LocalDataServiceClient(
            resolvedservice: event.service! as ResolvedBonsoirService);

        /// intiate data client if null
        _dataClient = _dataClient ??
            Client(
                rawMessageStreamController: _rawMessageStreamController,
                clientName: _deviceDetails.$1);

        /// connect with data client, this will take host, port and onErrorOrDone
        await _dataClient!.connect(
            _connectedClient!.host, _connectedClient!.port, onErrorOrDone: () {
          _connectedClient = null;
          _discoveredClients.add(Discoveredclients(
              allDiscoveredClients: _localDataServiceClients.toList()));
        });
        // TODO logger print("Resolved and connected :)");
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        final lostClient = LocalDataServiceClient(service: event.service);
        _localDataServiceClients
            .removeWhere((client) => client.name == lostClient.name);
        if (lostClient.name == _connectedClient?.name) {
          _connectedClient = null;
        }
      }
      _discoveredClients.add(Discoveredclients(
          allDiscoveredClients: _localDataServiceClients.toList(),
          connectedClient: _connectedClient));
    });

    await _discovery.start();
  }

  void _listenDataServerConnection() {
    _dataServerConnectionStreamSubscription =
        _dataServer.connectionStrem.listen((connectedDetails) {
      if (connectedDetails.$1) {
        final Socket connectedDataClient = _dataServer.connectedClient!;
        _connectedClient = LocalDataServiceClient.fromRemoteConnection(
            connectedDataClient, connectedDetails.$2!);
      } else {
        _connectedClient = null;
      }
      _discoveredClients.add(Discoveredclients(
          allDiscoveredClients: _localDataServiceClients.toList(),
          connectedClient: _connectedClient));
    });
  }

  Future<void> stopDiscovery() async {
    await _bonsoirDiscoveryEventSubscription?.cancel();
    await _discovery.stop();
    _connectedClient = null;
    _localDataServiceClients.clear();
    _discoveredClients
        .add(Discoveredclients(allDiscoveredClients: _localDataServiceClients));
  }

  Future<void> connect(LocalDataServiceClient client) async {
    if (client.name == _connectedClient?.name) return;
    await client.service!.resolve(_discovery.serviceResolver);
  }

  void sendMessage(String message) {
    if (_dataClient != null && _dataClient!.connected) {
      _dataClient?.sendMessage(message);
    } else if (_dataServer.isConnectedToClient) {
      _dataServer.sendMessage(message);
    }
  }

  void sendRawMessage(List<int> rawMessage) {
    if (_dataClient != null && _dataClient!.connected) {
      _dataClient!.sendRawMessage(rawMessage);
    } else if (_dataServer.isConnectedToClient) {
      _dataServer.sendRawMessage(rawMessage);
    }
  }

  void sendDataAsStream(Stream<List<int>> dataStream) {
    if (_dataClient != null && _dataClient!.connected) {
      _dataClient!.sendDataAsStream(dataStream);
    } else if (_dataServer.isConnectedToClient) {
      _dataServer.sendDataAsStream(dataStream);
    }
  }

  Future<void> disconnect() async {
    if (_dataClient != null && _dataClient!.connected) {
      _connectedClient = null;
      await _dataClient?.close();
      _discoveredClients.add(Discoveredclients(
          allDiscoveredClients: _localDataServiceClients.toList()));
    }

    if (_dataServer.isConnectedToClient) {
      await _dataServer.closeConnectedClient();
    }
  }

  Future<void> close() async {
    await _dataServerConnectionStreamSubscription.cancel();
    await _bonsoirDiscoveryEventSubscription?.cancel();
    _discoveredClients.add(Discoveredclients(allDiscoveredClients: []));
    await _discoveredClients.close();
    await _discovery.stop();
    await _broadcast.stop();
    await _dataClient?.release();
    await _dataServer.release();
    await _rawMessageStreamController.close();
    _connectedClient = null;
    _localDataServiceClients.clear();
  }
}
