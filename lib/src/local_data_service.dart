import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'exceptions/not_running_exception.dart';
import 'models/local_data_service_client.dart';
import 'models/discovered_clients.dart';

import 'socket/client.dart';
import 'socket/server.dart';

class LocalDataService {
  /// service name, it will be used for bonsoir service broadcasting and discovery
  late String _serviceName;

  /// device details (deviceName, deviceId)
  (String, String)? _deviceDetails;

  /// running state of the service
  bool _running = false;

  /// bonsoir service, used for broadcasting
  BonsoirService? _service;

  /// bonsoir broadcast, used for broadcasting the service
  BonsoirBroadcast? _broadcast;

  /// bonsoir discovery, used for discovering other services
  BonsoirDiscovery? _discovery;

  /// data server, used for handling data connections
  Server? _dataServer;

  /// data client, used for handling data connections
  Client? _dataClient;

  /// stream subscription for data server connection events
  StreamSubscription<(bool, String?)>? _dataServerConnectionStreamSubscription;

  /// stream subscription for bonsoir discovery events
  StreamSubscription<BonsoirDiscoveryEvent>? _bonsoirDiscoveryEventSubscription;

  /// list of discovered local data service clients
  final List<LocalDataServiceClient> _localDataServiceClients = [];

  /// stream controller for discovered clients
  final StreamController<Discoveredclients> _discoveredClients =
      StreamController<Discoveredclients>.broadcast();

  /// var to hold connected client
  /// this will be null if not connected to any client
  LocalDataServiceClient? _connectedClient;

  /// stream controller for raw messages/data received from clients
  final StreamController<List<int>> _rawMessageStreamController =
      StreamController<List<int>>();

  /// stream to get discovered clients
  /// this will emit a new [Discoveredclients] object whenever a new client is discovered or connected
  Stream<Discoveredclients> get discoveredClientsStream =>
      _discoveredClients.stream;

  /// stream to get raw messages/data received from clients
  /// this will emit a new [List<int>] object whenever a new raw message/data is received
  Stream<List<int>> get rawMessageStream => _rawMessageStreamController.stream;

  /// checks if data service is running
  bool get isRunning => _running;

  /// checks if data service is connected to any data client/data server
  bool get isConnected => _connectedClient != null;

  /// returns whether this LocalDataServiceClient is acting as a data client or data server
  /// when connected to other LocalDataServiceClient and returns null if not connected to any client
  LocalDataServiceClientActingAs? get thisClientActingAs =>
      (_dataClient?.connected ?? false)
          ? LocalDataServiceClientActingAs.client
          : _dataServer?.isConnectedToClient ?? false
              ? LocalDataServiceClientActingAs.server
              : null;

  /// returns the connected client if any
  /// this will be null if not connected to any client
  LocalDataServiceClient? get connectedClient => _connectedClient;

  /// returns the list of discovered clients
  List<LocalDataServiceClient> get discoveredClients =>
      _localDataServiceClients;

  /// requires a serviceId
  ///
  /// length of `serviceId`, should be less than or equal to 15 chars. if serviceId length is greater than 15, it will be truncated to 15 chars
  ///
  /// Example: `awesomeservice` or `awesome-service`
  ///
  /// [deviceName] is optional, if provided it will be used as the device name
  /// by default, it will use the platform provided device name from [device_info_plus] package.
  LocalDataService({required String serviceId, String? deviceName}) {
    if (serviceId.length > 15) {
      serviceId = serviceId.substring(0, 15);
    }
    _serviceName = '_$serviceId._tcp';

    _deviceInfo.then((info) {
      /// if device name provided by user it will replace device name
      _deviceDetails = (deviceName ?? info.$1, info.$2);
    });
  }

  /// initializes local data service
  /// this will start the data server and bonsoir service for broadcasting and discovery
  ///
  /// @param `startBroadcastAtInit` default true, if false, it will not start broadcasting the service at initialization
  ///
  /// @param `startDiscoveryAtInit` default true, if false, it will not start discovery at initialization
  ///
  /// @param `port` the port to use for the data server and bonsoir service, it should be same across all clients, default is 62527
  Future<void> init(
      {bool startbroadcastAtInit = true,
      bool startDiscoveryAtInit = true,
      int port = 62527}) async {
    if (_running) {
      return;
    }
    // init data server
    _dataServer =
        Server(rawMessageStreamController: _rawMessageStreamController);
    await _dataServer!.init(port, _rawMessageStreamController);

    _service = BonsoirService(
        name: _deviceDetails!.$1,
        type: _serviceName,
        port: port,
        attributes: {'id': _deviceDetails!.$2});

    _running = true;

    if (startbroadcastAtInit) {
      await startBroadcast();
    }

    if (startDiscoveryAtInit) {
      await startDiscovery();
    }

    _listenDataServerConnection();
  }

  /// returns (deviceName, deviceId) from the platform
  ///
  /// this will use [device_info_plus] package to get the device details
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

  /// starts broadcasting the service
  /// this will create a bonsoir broadcast and start it
  ///
  /// throws [LocalDataServiceNotRunningException] if the service is not running
  Future<void> startBroadcast() async {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    if (_broadcast != null && _broadcast!.isReady) {
      return;
    }
    _broadcast = BonsoirBroadcast(service: _service!);
    await _broadcast?.ready;
    await _broadcast?.start();
  }

  /// starts discovery of local data services
  /// this will create a bonsoir discovery and start it
  ///
  /// throws [LocalDataServiceNotRunningException] if the service is not running
  Future<void> startDiscovery() async {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    _discovery = BonsoirDiscovery(type: _serviceName);
    await _discovery!.ready;

    _bonsoirDiscoveryEventSubscription =
        _discovery!.eventStream!.listen((event) async {
      if (event.service == null || event.service?.name == _deviceDetails!.$1) {
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
                clientName: _deviceDetails!.$1);

        /// connect data client with data server, this will take host, port and onErrorOrDone
        await _dataClient!.connect(
            _connectedClient!.host, _connectedClient!.port,

            /// onErrorOrDone will be called when connection is closed or error occurs
            onErrorOrDone: () {
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

    await _discovery!.start();
  }

  /// listens to data server connection events
  /// this will update the connected client and emit a new [Discoveredclients] object
  void _listenDataServerConnection() {
    _dataServerConnectionStreamSubscription =
        _dataServer!.connectionStrem.listen((connectedDetails) {
      if (connectedDetails.$1) {
        final Socket connectedDataClient = _dataServer!.connectedClient!;
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

  /// stops broadcasting the service
  /// this will stop the bonsoir broadcast
  Future<void> stopBroadcast() async {
    if (!_running) {
      return;
    }

    if (_broadcast != null && !(_broadcast!.isStopped)) {
      await _broadcast?.stop();
    }
  }

  /// stops discovery of LocalDataService clients
  Future<void> stopDiscovery() async {
    if (!_running) {
      return;
    }

    await _bonsoirDiscoveryEventSubscription?.cancel();
    await _discovery?.stop();
    _connectedClient = null;
    _localDataServiceClients.clear();
    _discoveredClients
        .add(Discoveredclients(allDiscoveredClients: _localDataServiceClients));
  }

  /// connects to a LocalDataService client
  ///
  /// resolves a bonsoir service and connects to data server with resoved host and port
  Future<void> connect(LocalDataServiceClient client) async {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    if (_discovery == null) return;
    if (client.name == _connectedClient?.name) return;
    await client.service!.resolve(_discovery!.serviceResolver);
  }

  /// sends a message to the connected LocalDataService client
  ///
  /// if the service is not running, it will throw [LocalDataServiceNotRunningException]
  void sendMessage(String message) {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    if (_dataClient != null && _dataClient!.connected) {
      _dataClient?.sendMessage(message);
    } else if (_dataServer!.isConnectedToClient) {
      _dataServer!.sendMessage(message);
    }
  }

  /// sends a raw message as `List<int>` to the connected LocalDataService client
  ///
  /// if the service is not running, it will throw [LocalDataServiceNotRunningException]
  void sendRawMessage(List<int> rawMessage) {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    if (_dataClient != null && _dataClient!.connected) {
      _dataClient!.sendRawMessage(rawMessage);
    } else if (_dataServer!.isConnectedToClient) {
      _dataServer!.sendRawMessage(rawMessage);
    }
  }

  /// sends data as a stream to the connected LocalDataService client
  ///
  /// if the service is not running, it will throw [LocalDataServiceNotRunningException]
  void sendDataAsStream(Stream<List<int>> dataStream) {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    if (_dataClient != null && _dataClient!.connected) {
      _dataClient!.sendDataAsStream(dataStream);
    } else if (_dataServer!.isConnectedToClient) {
      _dataServer!.sendDataAsStream(dataStream);
    }
  }

  /// disconnects from the connected LocalDataService client
  ///
  /// if the service is not running, it will throw [LocalDataServiceNotRunningException]
  Future<void> disconnect() async {
    if (!_running) {
      throw LocalDataServiceNotRunningException();
    }

    if (_dataClient != null && _dataClient!.connected) {
      _connectedClient = null;
      await _dataClient?.close();
      _discoveredClients.add(Discoveredclients(
          allDiscoveredClients: _localDataServiceClients.toList()));
    }

    if (_dataServer!.isConnectedToClient) {
      await _dataServer!.closeConnectedClient();
    }
  }

  /// close the LocalDataService
  ///
  /// service can be initize again by calling `init`
  Future<void> close() async {
    if (!_running) {
      return;
    }
    await _dataServerConnectionStreamSubscription?.cancel();
    await _bonsoirDiscoveryEventSubscription?.cancel();
    _discoveredClients.add(Discoveredclients(allDiscoveredClients: []));
    await _discovery?.stop();
    await stopBroadcast();
    await _dataClient?.release();
    await _dataServer!.release();
    _connectedClient = null;
    _localDataServiceClients.clear();
    _discovery = null;
    _broadcast = null;
    _running = false;
  }

  /// Completetly close the service.
  ///
  ///  should be called while closing the app or when service is no longer required.
  Future<void> release() async {
    await close();
    await _discoveredClients.close();
    await _rawMessageStreamController.close();
  }
}


/// Enum to represent whether the LocalDataServiceClient is acting as a client or server.
enum LocalDataServiceClientActingAs {
  client,
  server,
}
