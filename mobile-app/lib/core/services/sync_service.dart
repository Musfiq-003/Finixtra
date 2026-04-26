import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'encryption_service.dart';

class SyncService {
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final String _apiGatewayUrl = "http://10.0.2.2:3000/api/v1/wallet/sync-offline"; // Android emulator localhost alias
  Database? _db;
  
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectivityController.stream;
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_transactions.db');
    _db = await openDatabase(path);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      final online = result == ConnectivityResult.wifi || result == ConnectivityResult.mobile;
      if (online != _isOnline) {
        _isOnline = online;
        _connectivityController.add(_isOnline);
      }
      
      if (online) {
        // We have internet! Time to act as the Mesh Uplink.
        _flushOfflineQueue();
      }
    });
  }

  /// Extracts all locally buffered transactions and uploads them to the FINIXTRA API Gateway
  Future<void> _flushOfflineQueue() async {
    if (_db == null) return;

    final pendingTx = await _db!.query('transaction_queue', where: "status = 'BUFFERED'");
    
    if (pendingTx.isEmpty) return;

    List<Map<String, dynamic>> syncPayloads = [];
    
    for (var tx in pendingTx) {
      // In a real scenario, the API gateway expects the decrypted payload with the cryptographic signature.
      // Since this node is just an uplink, it decrypts the packet (if it has the shared group key) 
      // or passes the encrypted blob depending on the architecture. 
      // Assuming we decrypt before uploading to API Gateway:
      final decrypted = EncryptionService.decryptPayload(tx['payload'] as String);
      syncPayloads.add(decrypted);
    }

    try {
      final response = await http.post(
        Uri.parse(_apiGatewayUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'transactions': syncPayloads}),
      );

      if (response.statusCode == 200) {
        // Sync successful. Remove from local queue.
        for (var tx in pendingTx) {
          await _db!.delete('transaction_queue', where: 'id = ?', whereArgs: [tx['id']]);
        }
        debugPrint("Successfully synced ${pendingTx.length} offline transactions.");
      }
    } catch (e) {
      debugPrint("Sync failed: $e. Retrying on next connection.");
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _connectivityController.close();
  }
}
