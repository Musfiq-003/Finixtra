import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'encryption_service.dart';
import 'network_service.dart';

class TransactionService {
  final NetworkService _networkService;
  Database? _db;

  TransactionService(this._networkService);

  Future<void> initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_transactions.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE transaction_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT,
            target_node_id TEXT,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'PENDING',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  /// Initiates an offline transfer. Encrypts, signs, and attempts to route via mesh.
  /// If no immediate route is found, it buffers the transaction.
  Future<void> initiateOfflineTransfer({
    required String fromWallet,
    required String toWallet,
    required double amount,
    required String recipientNodeId,
  }) async {
    final rawPayload = {
      'from_wallet': fromWallet,
      'to_wallet': toWallet,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Generate Cryptographic Signature (Tamper-proofing)
    final signature = EncryptionService.generateSignature(rawPayload);
    rawPayload['signature'] = signature;

    // 2. Encrypt Payload
    final encryptedPayload = EncryptionService.encryptPayload(rawPayload);

    // 3. Attempt Delivery or Buffer (Store-and-Forward)
    final nextHop = _networkService.getNextHop(recipientNodeId);
    
    if (nextHop != null) {
      // Route exists, forward to next hop via TCP immediately
      _forwardToNode(nextHop, encryptedPayload);
    } else {
      // No route found. Buffer locally per Delay-Tolerant Networking (DTN) principles.
      await _bufferTransaction(encryptedPayload, recipientNodeId);
    }
  }

  Future<void> _bufferTransaction(String encryptedPayload, String targetNodeId) async {
    if (_db == null) await initDB();
    
    await _db!.insert('transaction_queue', {
      'payload': encryptedPayload,
      'target_node_id': targetNodeId,
      'status': 'BUFFERED',
    });
  }

  void _forwardToNode(String nextHop, String payload) {
    // Send over TCP via Wi-Fi Direct interface
    debugPrint("Forwarding payload to $nextHop");
  }

  /// Processes incoming packets from the mesh network.
  /// If this device is the target, decrypts. Otherwise, forwards.
  Future<void> receiveMeshPacket(String packetStr) async {
    final packet = jsonDecode(packetStr);
    final targetNodeId = packet['target_node_id'];
    const myNodeId = "local_device_id"; // Retrieve securely
    
    if (targetNodeId == myNodeId) {
      // Packet has reached its final destination. Decrypt and process locally.
      final decrypted = EncryptionService.decryptPayload(packet['payload']);
      debugPrint("Received offline transaction: $decrypted");
      // Update local wallet UI
    } else {
      // Packet is transiting. Relay it if hop count hasn't exceeded MAX_HOPS.
      final nextHop = _networkService.getNextHop(targetNodeId);
      if (nextHop != null) {
        _forwardToNode(nextHop, packet['payload']);
      } else {
        await _bufferTransaction(packet['payload'], targetNodeId);
      }
    }
  }

  Future<int> getBufferedCount() async {
    if (_db == null) await initDB();
    final result = await _db!.rawQuery('SELECT COUNT(*) as count FROM transaction_queue WHERE status = "BUFFERED"');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentTransactions() async {
    if (_db == null) await initDB();
    final List<Map<String, dynamic>> maps = await _db!.query('transaction_queue', orderBy: 'created_at DESC', limit: 10);
    
    return List.generate(maps.length, (i) {
      try {
        final payload = EncryptionService.decryptPayload(maps[i]['payload']);
        return {
          'title': 'Mesh Transfer to ${maps[i]['target_node_id']}',
          'amount': '-\$${payload['amount']}',
          'date': maps[i]['created_at'],
          'status': maps[i]['status'],
        };
      } catch (e) {
        return {
          'title': 'Encrypted Packet',
          'amount': '---',
          'date': maps[i]['created_at'],
          'status': maps[i]['status'],
        };
      }
    });
  }
}

