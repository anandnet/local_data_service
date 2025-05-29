import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

class LocalDataServiceClient {
  final BonsoirService? service;
  final ResolvedBonsoirService? resolvedservice;

  @protected
  final String? clientName;

  @protected
  final String? clientHost;

  @protected
  final int? clientPort;

  String get name {
    return service?.name ?? resolvedservice?.name ?? clientName!;
  }

  int get port => service?.port ?? resolvedservice?.port ?? clientPort!;
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

  factory LocalDataServiceClient.fromResolvedService(
      ResolvedBonsoirService resolvedservice) {
    return LocalDataServiceClient(resolvedservice: resolvedservice);
  }

  factory LocalDataServiceClient.fromDiscoveredService(dService) {
    return LocalDataServiceClient(service: dService);
  }

  factory LocalDataServiceClient.fromRemoteConnection(Socket connectedClient,String name) {
    return LocalDataServiceClient(
      clientName: name,
      clientHost: connectedClient.remoteAddress.address,
      clientPort: connectedClient.remotePort
    );
  }
}
