import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class Server {
  @protected
  final StreamController<List<int>> rawMessageStreamController;
  Server({required this.rawMessageStreamController});

  late ServerSocket _server;
  late StreamSubscription<Socket> _serverSubscription;
  StreamSubscription<List<int>>? _clientSubscription;
  Socket? _connectedClient;

  final StreamController<(bool, String?)> _connectionStreamController =
      StreamController();
  Stream<(bool, String?)> get connectionStrem =>
      _connectionStreamController.stream;
  Socket? get connectedClient => _connectedClient;
  bool get isConnectedToClient => _connectedClient != null;
  bool _gotClientName = false;

  Future<void> init(
      int port, StreamController<List<int>> rawMessageStreamController) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    // TODO logger print("Data server running at ${_server.address.address}:${_server.port}");
    _serverSubscription = _server.listen((client) {
      if (_connectedClient == null) {
        _connectedClient = client;

        // TODO logger print("Data Server Connected to: ${client.remoteAddress}:${client.remotePort}");
        _clientSubscription = client.listen((data) {
          /// init message will be client name
          if (!_gotClientName) {
            final clientName = String.fromCharCodes(data);
            _connectionStreamController.add((true, clientName));
            _gotClientName = true;
            return;
          }
          // TODO logger print("Recieved: ${String.fromCharCodes(data)}");
          rawMessageStreamController.add(data);
        }, onDone: () {
          _connectedClient = null;
          client.close();
          _gotClientName = false;
          _connectionStreamController.add((false, null));
        }, onError: (e) {
          // TODO logger print(e);
          _connectedClient = null;
          client.destroy();
          _gotClientName = false;
          _connectionStreamController.add((false, null));
        });
      } else {
        // refuse a connection if already connected
        client.destroy();
      }
    });
  }

  void sendMessage(String message) {
    _connectedClient?.write(message);
  }

  void sendRawMessage(List<int> rawMessage) {
    _connectedClient?.add(rawMessage);
  }

  Future<void> sendDataAsStream(Stream<List<int>> dataStream) async {
    try {
      await _connectedClient?.addStream(dataStream);
      await _connectedClient?.flush();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeConnectedClient() async {
    await _connectedClient?.close();
    _connectedClient = null;
    _gotClientName = false;
  }

  Future<void> release() async {
    await _clientSubscription?.cancel();
    await _serverSubscription.cancel();
    _connectedClient?.destroy();
    await _server.close();
    await _connectionStreamController.close();
    _connectedClient = null;
  }
}
