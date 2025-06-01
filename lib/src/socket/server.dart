import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A client class that manages a socket connection to a server.
/// It allows sending and receiving messages, and handles raw data streams.
class Server {

  /// A stream controller to handle raw messages received from the server.
  @protected
  final StreamController<List<int>> rawMessageStreamController;
  Server({required this.rawMessageStreamController});

  /// The server socket that listens for incoming connections.
  late ServerSocket _server;

  /// A stream subscription to listen for incoming client connections.
  late StreamSubscription<Socket> _serverSubscription;

  /// A stream subscription to listen for incoming data from the connected client.
  StreamSubscription<List<int>>? _clientSubscription;

  /// The currently connected client socket.
  Socket? _connectedClient;

  /// A stream controller to handle connection status updates.
  final StreamController<(bool, String?)> _connectionStreamController =
      StreamController();

  /// A stream that emits connection status updates.
  Stream<(bool, String?)> get connectionStrem =>
      _connectionStreamController.stream;

  /// The currently connected client socket. returns null if no client is connected.
  Socket? get connectedClient => _connectedClient;

  /// Checks if the server is currently connected to a client.
  bool get isConnectedToClient => _connectedClient != null;

  /// A flag to indicate if the client name has been received.
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

  /// Sends a message to the connected client.
  void sendMessage(String message) {
    _connectedClient?.write(message);
  }

  /// Sends a raw message (list of integers) to the connected client.
  void sendRawMessage(List<int> rawMessage) {
    _connectedClient?.add(rawMessage);
  }

  /// Sends a stream of data to the connected client.
  Future<void> sendDataAsStream(Stream<List<int>> dataStream) async {
    try {
      await _connectedClient?.addStream(dataStream);
      await _connectedClient?.flush();
    } catch (e) {
      rethrow;
    }
  }

  /// Closes the connected client and resets the connection state.
  Future<void> closeConnectedClient() async {
    await _connectedClient?.close();
    _connectedClient = null;
    _gotClientName = false;
  }

  /// Closes the server socket and cleans up resources.
  Future<void> release() async {
    await _clientSubscription?.cancel();
    await _serverSubscription.cancel();
    _connectedClient?.destroy();
    await _server.close();
    await _connectionStreamController.close();
    _connectedClient = null;
  }
}
