import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

class WsClient {
  WsClient({String? baseUrl}) : _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String _baseUrl;
  WebSocketChannel? _channel;

  bool get isConnected => _channel != null;

  String _wsUrl(String token) {
    var base = _baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.startsWith('https://')) {
      base = 'wss://${base.substring(8)}';
    } else if (base.startsWith('http://')) {
      base = 'ws://${base.substring(7)}';
    }
    // Avoid ERR_CONNECTION_REFUSED on Flutter Web when the host resolves oddly.
    base = base.replaceFirst('ws://localhost', 'ws://127.0.0.1');
    base = base.replaceFirst('wss://localhost', 'wss://127.0.0.1');
    // Already ws:// or wss:// -> leave untouched.
    return '$base/ws?token=$token';
  }

  void connect({required String token}) {
    _channel = WebSocketChannel.connect(Uri.parse(_wsUrl(token)));
  }

  Stream<Map<String, dynamic>> get messages {
    final channel = _channel;
    if (channel == null) return const Stream.empty();
    return channel.stream.map((data) {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;
      return decoded;
    });
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }
}
