import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

/// A class that represents a local data service client.
/// It can be created from a discovered service, a resolved service, or a remote connection.
class LocalDataServiceClient {
  final BonsoirService? service;
  final ResolvedBonsoirService? resolvedservice;

  /// The name of the client, used for identification when connecting to the server.
  @protected
  final String? clientName;

  /// The host of the client, used for identification when connecting to the server.
  @protected
  final String? clientHost;

  /// The port of the client, used for identification when connecting to the server.
  @protected
  final int? clientPort;

  /// The name of the client, either from the service, resolved service, or clientName.
  String get name {
    return service?.name ?? resolvedservice?.name ?? clientName!;
  }

  /// The port of the client, either from the service, resolved service, or clientPort.
  int get port => service?.port ?? resolvedservice?.port ?? clientPort!;

  /// The host of the client, either from the service, resolved service, or clientHost.
  String get host => service?.attributes['host'] ?? resolvedservice?.host ?? clientHost ?? '';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != LocalDataServiceClient) {
      return false;
    }
    return name == (other as LocalDataServiceClient).name;
  }

  LocalDataServiceClient(
      {this.service, this.resolvedservice, this.clientName,this.clientHost,this.clientPort});

  /// creates a LocalDataServiceClient from a resolved service.
  /// This is useful when you have already resolved a service and want to create a client from it.
  factory LocalDataServiceClient.fromResolvedService(
      ResolvedBonsoirService resolvedservice) {
    return LocalDataServiceClient(resolvedservice: resolvedservice);
  }

  /// creates a LocalDataServiceClient from a discovered service.
  /// This is useful when you have discovered a service and want to create a client from it.
  factory LocalDataServiceClient.fromDiscoveredService(dService) {
    return LocalDataServiceClient(service: dService);
  }

  /// creates a LocalDataServiceClient from a remote connection.
  /// This is useful when you have a connected client and want to create a client from it.
  factory LocalDataServiceClient.fromRemoteConnection(Socket connectedClient,String name) {
    return LocalDataServiceClient(
      clientName: name,
      clientHost: connectedClient.remoteAddress.address,
      clientPort: connectedClient.remotePort
    );
  }
}
