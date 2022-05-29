import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:led_board/select_bonded_device_screen.dart';
import 'dart:convert';

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String dropdownValue = 'Цвет';

  BluetoothDevice? server;
  BluetoothConnection? connection;

  bool _isConnected = false;

  bool isConnecting = false;

  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  TextEditingController _textEditingController = TextEditingController();

  bool _toUpperCase = false;
  double _speed = 0.5;
  double _brightness = 0.5;
  double _color = 0.5;
  bool _isTurnedOn = true;

  showSnackBar(String text, BuildContext context) {
    SnackBar snackBar = SnackBar(
      content: Text(text),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  connect() {
    BluetoothConnection.toAddress(server?.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        _isConnected = true;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      showSnackBar('Не удалось подключиться', context);
      print('Cannot connect, exception occured');
      print(error);
      setState(() {
        isConnecting = false;
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Visibility(
        visible: isConnected,
        child: FloatingActionButton(
          onPressed: () {
            setState(() {
              if (_isTurnedOn) {
                _isTurnedOn = false;
              } else {
                _isTurnedOn = true;
              }
              _toggleText(_isTurnedOn);
            });
          },
          child: const Icon(
            Icons.power_settings_new,
          ),
          backgroundColor: _isTurnedOn ? Colors.red : Colors.green,
        ),
      ),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  color: const Color.fromARGB(255, 240, 240, 240),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Visibility(
                            child: const CircularProgressIndicator(),
                            visible: isConnecting,
                          ),
                          Visibility(
                            visible: !isConnecting,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isConnected ? "Устройство подключено" : "Устройство не подключено"),
                                Icon(
                                  _isConnected ? Icons.check : Icons.not_interested,
                                ),
                                const Padding(padding: EdgeInsets.only(right: 10)),
                                MaterialButton(
                                  onPressed: () async {
                                    if (_isConnected) {
                                      isDisconnecting = true;
                                      connection?.dispose();
                                      connection = null;
                                      _isConnected = false;
                                    } else if (!_isConnected) {
                                      final BluetoothDevice? selectedDevice =
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) {
                                            return SelectBondedDevicePage(
                                                checkAvailability: false);
                                          },
                                        ),
                                      );
                                      if (selectedDevice != null) {
                                        setState(() {
                                          isConnecting = true;
                                        });
                                        server = selectedDevice;
                                        connect();
                                        print('Connect -> selected ' + selectedDevice.address);
                                      } else {
                                        print('Connect -> no device selected');
                                      }
                                    }
                                  },
                                  color: _isConnected ? Colors.red : Colors.green,
                                  textColor: Colors.white,
                                  child: Text(_isConnected ? "Отключить" : "Подключить"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  color: const Color.fromARGB(255, 240, 240, 240),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: "Введите текст бегущей строки",
                          contentPadding: EdgeInsets.only(left: 16, right: 16)
                        ),
                        controller: _textEditingController,

                      ),
                      MaterialButton(
                        onPressed: () {
                          _sendMessage(_textEditingController.text);
                        },
                        color: Colors.teal,
                        textColor: Colors.white,
                        child: const Text("Отправить"),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Большие буквы",
                            style: TextStyle(fontSize: 16),
                          ),
                          Switch(value: _toUpperCase, onChanged: (value) {
                            setState(() {
                              _toUpperCase = value;
                            });
                          }),
                        ],
                      ),
                      DropdownButton<String>(
                        value: dropdownValue,
                        icon: const Icon(Icons.arrow_downward),
                        elevation: 16,
                        style: const TextStyle(color: Colors.black),
                        underline: Container(
                          height: 2,
                          color: Colors.teal,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            dropdownValue = newValue!;
                          });
                          _changeMode(dropdownValue);
                        },
                        items: <String>['Цвет', 'Разноцветные', 'Радуга']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  color: const Color.fromARGB(255, 240, 240, 240),
                  child: Column(
                    children: [
                      const Text(
                        "Скорость",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: _speed,
                        onChangeEnd: (value) async {
                          print(value);
                          await _sendSpeed(value);
                        },
                        onChanged: (value) {
                          setState(
                                () {
                              _speed = value;
                            },
                          );
                        },
                      ),
                      const Text(
                        "Яркость",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: _brightness,
                        onChangeEnd: (value) async {
                          print(value);
                          await _sendBrightness(value);
                        },
                        onChanged: (value) {
                          setState(
                                () {
                              _brightness = value;
                            },
                          );
                        },
                      ),
                      const Text(
                        "Цвет",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: _color,
                        onChangeEnd: (value) async {
                          print(value);
                          await _sendColor(value);
                        },
                        onChanged: (value) {
                          setState(
                                () {
                              _color = value;
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

              ],
            ),
            Padding(padding: EdgeInsets.only(top: 16),),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Padding(padding: EdgeInsets.only(right: 10)),
                SizedBox(
                  height: 40,
                  child: Image(
                    image: AssetImage('assets/miem_logo.png'),
                  ),
                ),
                Padding(padding: EdgeInsets.only(right: 10)),
                SizedBox(
                  height: 70,
                  child: Image(
                    image: AssetImage('assets/hse_logo.png'),
                  ),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.only(top: 4),),
            const SizedBox(
              height: 30,
              child: Image(
                image: AssetImage('assets/logo.png'),
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 16),),
            const Text(
              'Автор – Шабалин Егор, БИВ205',
              style: TextStyle(
                fontSize: 9,
              ),

            ),
            const Padding(padding: EdgeInsets.only(bottom: 20),),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleText(bool isTurnedOn) async {
    int code = _isTurnedOn ? 1 : 0;
    try {
      print("\$1," + code.toString() + ";");
      connection!.output.add(Uint8List.fromList(utf8.encode("\$1," + code.toString() + ";")));
      await connection!.output.allSent;
    } catch (e) {
      print(e);
      setState(() {});
    }
  }

  Future<void> _changeMode(String mode) async {
    int code = 0;

    switch (mode) {
      case 'Цвет':
        code = 0;
        break;
      case 'Радуга':
        code = 1;
        break;
      case 'Разноцветные':
        code = 2;
        break;
    }

    try {
      print("\$4," + code.toString() + ";");
      connection!.output.add(Uint8List.fromList(utf8.encode("\$4," + code.toString() + ";")));
      await connection!.output.allSent;
    } catch (e) {
      print(e);
      setState(() {});
    }
  }

  Future<void> _sendSpeed(double speed) async {
    String speedString = (speed * 100).toInt().toString().trim();

    try {
      print("\$2," + speedString + ";");
      connection!.output.add(Uint8List.fromList(utf8.encode("\$2," + speedString + ";")));
      await connection!.output.allSent;
    } catch (e) {
      print(e);
      setState(() {});
    }
  }

  Future<void> _sendBrightness(double brightness) async {
    String brightnessString = (brightness * 255).toInt().toString().trim();

    try {
      print("\$3," + brightnessString + ";");
      connection!.output.add(Uint8List.fromList(utf8.encode("\$3," + brightnessString + ";")));
      await connection!.output.allSent;
    } catch (e) {
      print(e);
      setState(() {});
    }
  }

  Future<void> _sendColor(double color) async {
    String colorString = (color * 255).toInt().toString().trim();

    try {
      print("\$5," + colorString + ";");
      connection!.output.add(Uint8List.fromList(utf8.encode("\$5," + colorString + ";")));
      await connection!.output.allSent;
    } catch (e) {
      print(e);
      setState(() {});
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (_toUpperCase) {
      text = text.toUpperCase();
    }

    if (text.length > 0) {
      try {
        print("#" + text + "\r\n");
        connection!.output.add(Uint8List.fromList(utf8.encode("#" + text)));
        await connection!.output.allSent;
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }
  }
}
