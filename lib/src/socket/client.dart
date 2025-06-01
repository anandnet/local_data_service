import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// A client class that manages a socket connection to a server.
/// It allows sending and receiving messages, and handles raw data streams.
class Client {

  /// A stream controller to handle raw messages received from the server.
  @protected
  final StreamController<List<int>> rawMessageStreamController;

  /// The name of the client, used for identification when connecting to the server.
  @protected
  final String clientName;

  /// The socket connection to the server.
  Socket? _client;

  /// A stream subscription to listen for incoming data from the server.
  StreamSubscription<List<int>>? _streamSubscription;

  /// Checks if the client is connected to the server.
  bool get connected => _client != null;

  /// requires stream controller to handle raw messages
  /// 
  /// and a client name for identification
  Client({required this.rawMessageStreamController, required this.clientName});

  Future<void> connect(String address, int port,
      {VoidCallback? onErrorOrDone}) async {
    // disconnect current device
    if (_client != null) {
      await close();
    }

    _client = await Socket.connect(address, port);
    /// sends the client name as the first message to the server 
    /// so that the server can identify the client
    _client!.write(clientName);

    /// listen for incoming data from the server
    _streamSubscription = _client!.listen((data) {
      // TODO logger print("Recieved: ${utf8.decode(data)}");
      rawMessageStreamController.add(data);
    }, onDone: () async {
      await close();
      if (onErrorOrDone != null) {
        onErrorOrDone();
      }
    }, onError: (e) async {
      // TODO logger print(e);
      await close();
      if (onErrorOrDone != null) {
        onErrorOrDone();
      }
    });
  }

  /// Sends a message to the server.
  void sendMessage(String message) {
    if (connected) {
      _client?.write(message);
    }
  }

  /// Sends a raw message (list of integers) to the server.
  void sendRawMessage(List<int> rawMessage) {
    if (connected) {
      _client?.add(rawMessage);
    }
  }

  /// Sends data as a stream to the server.
  Future<void> sendDataAsStream(Stream<List<int>> dataStream) async {
    try {
      await _client?.addStream(dataStream);
      await _client?.flush();
    } catch (e) {
      rethrow;
    }
  }

  /// Closes the socket connection and cleans up resources.
  Future<void> close() async {
    await _streamSubscription?.cancel();
    await _client?.close();
    _client = null;
    _streamSubscription = null;
  }

  /// Releases the client resources and closes the connection.
  Future<void> release() async {
    await close();
  }
}
