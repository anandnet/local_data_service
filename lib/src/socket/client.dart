import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class Client {
  @protected
  final StreamController<List<int>> rawMessageStreamController;
  @protected
  final String clientName;

  Socket? _client;
  StreamSubscription<List<int>>? _streamSubscription;
  bool get connected => _client != null;

  Client({required this.rawMessageStreamController, required this.clientName});

  Future<void> connect(String address, int port,
      {VoidCallback? onErrorOrDone}) async {
    // disconnect current device
    if (_client != null) {
      await close();
    }

    _client = await Socket.connect(address, port);
    _client!.write(clientName);
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

  void sendMessage(String message) {
    if (connected) {
      _client?.write(message);
    }
  }

  void sendRawMessage(List<int> rawMessage) {
    if (connected) {
      _client?.add(rawMessage);
    }
  }

  Future<void> sendDataAsStream(Stream<List<int>> dataStream) async {
    try {
      await _client?.addStream(dataStream);
      await _client?.flush();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> close() async {
    await _streamSubscription?.cancel();
    await _client?.close();
    _client = null;
    _streamSubscription = null;
  }

  Future<void> release() async {
    await close();
  }
}
