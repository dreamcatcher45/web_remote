import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Control',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[900],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ),
      home: ControlPage(),
    );
  }
}

class ControlPage extends StatefulWidget {
  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final TextEditingController _ipController = TextEditingController();
  WebSocketChannel? _channel;
  double _audioValue = 0;
  double _brightnessValue = 0;
  bool _isConnected = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  void _loadSavedIp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedIp = prefs.getString('saved_ip');
    if (savedIp != null) {
      setState(() {
        _ipController.text = savedIp;
      });
    }
  }

  void _saveIp(String ip) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_ip', ip);
  }

  void _connect() {
    final ip = _ipController.text;
    if (ip.isNotEmpty) {
      try {
        final uri = 'ws://$ip:8765';
        _channel = WebSocketChannel.connect(Uri.parse(uri));
        _channel!.stream.listen(
          (message) {
            setState(() {
              _logs.insert(0, 'Received: $message');
            });
          },
          onError: (error) {
            setState(() {
              _isConnected = false;
              _logs.insert(0, 'Error: $error');
            });
          },
          onDone: () {
            setState(() {
              _isConnected = false;
              _logs.insert(0, 'Disconnected from server');
            });
          },
        );
        setState(() {
          _isConnected = true;
          _logs.insert(0, 'Connected to server');
        });
        _saveIp(ip); // Save the IP address when connected
      } catch (e) {
        setState(() {
          _logs.insert(0, 'Connection failed: $e');
        });
      }
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    setState(() {
      _isConnected = false;
      _logs.insert(0, 'Disconnected from server');
    });
  }

  void _sendMessage(String type, int value) {
    if (_channel != null && _isConnected) {
      final message = '${type}_$value';
      _channel!.sink.add(message);
      setState(() {
        _logs.insert(0, 'Sent: $message');
      });
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('System Control'),
        actions: [
          if (_isConnected)
            IconButton(
              icon: Icon(Icons.power_settings_new),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Connection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'Server IP Address',
                        border: OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_isConnected
                              ? Icons.check_circle
                              : Icons.add_link),
                          color: _isConnected ? Colors.green : null,
                          onPressed: _isConnected ? null : _connect,
                        ),
                      ),
                      enabled: !_isConnected,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 24),
                    // Audio Control
                    Row(
                      children: [
                        Icon(Icons.volume_up, size: 28),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Audio Volume',
                                  style: TextStyle(fontSize: 16)),
                              Slider(
                                value: _audioValue,
                                min: 0,
                                max: 10,
                                divisions: 10,
                                label: _audioValue.round().toString(),
                                onChanged: _isConnected
                                    ? (value) {
                                        setState(() {
                                          _audioValue = value;
                                        });
                                      }
                                    : null,
                                onChangeEnd: (value) {
                                  _sendMessage('a', value.round());
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          '${(_audioValue * 10).round()}%',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    // Brightness Control
                    Row(
                      children: [
                        Icon(Icons.brightness_6, size: 28),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Screen Brightness',
                                  style: TextStyle(fontSize: 16)),
                              Slider(
                                value: _brightnessValue,
                                min: 0,
                                max: 10,
                                divisions: 10,
                                label: _brightnessValue.round().toString(),
                                onChanged: _isConnected
                                    ? (value) {
                                        setState(() {
                                          _brightnessValue = value;
                                        });
                                      }
                                    : null,
                                onChangeEnd: (value) {
                                  _sendMessage('b', value.round());
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          '${(_brightnessValue * 10).round()}%',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Logs Section
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Log',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                _logs[index],
                                style: TextStyle(fontSize: 14),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
