import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:local_data_service/local_data_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class Message {
  final bool me;
  final String message;
  Message({required this.me, required this.message});
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Message> _message = [];
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _connectedClientName;
  final LocalDataService _localDataService = LocalDataService();

  void _listenForMessages() {
    _localDataService.rawMessageStream.listen((data) {
      _addNewMessage(Message(me: false, message: utf8.decode(data)));
    });
  }

  void _sendMessage(String message) {
    _localDataService.sendMessage(message);
    _addNewMessage(Message(me: true, message: message));
  }

  Future<void> _setConnectedClientName(String? name) async {
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _connectedClientName = name;
      _message.clear();
    });
  }

  void _addNewMessage(Message message) {
    setState(() {
      _message.add(message);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    _localDataService.init(serviceId: "awesome-service");
    _listenForMessages();
    super.initState();
  }

  @override
  void dispose() {
    _localDataService.close();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("build");
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: StreamBuilder(
                  initialData: Discoveredclients(allDiscoveredClients: []),
                  stream: _localDataService.discoveredClientsStream,
                  builder: (context, snapshot) {
                    final data = snapshot.data!;
                    final discocoveredClients = data.allDiscoveredClients;
                    final connectedClient = data.connectedClient;
                    if (connectedClient?.name != _connectedClientName) {
                      _setConnectedClientName(connectedClient?.name);
                    }
                    return ListView(
                      children: discocoveredClients
                          .map((e) => ListTile(
                                title: Text(e.name),
                                leading: Container(
                                  height: 10,
                                  width: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: connectedClient?.name == e.name
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                subtitle: connectedClient?.name == e.name
                                    ? Text(
                                        '${connectedClient?.host}:${connectedClient?.port}',
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: connectedClient?.name == e.name
                                    ? IconButton(
                                        icon: const Icon(Icons.connected_tv),
                                        onPressed: () {
                                          _localDataService.disconnect();
                                        },
                                      )
                                    : null,
                                onTap: () {
                                  _localDataService.connect(e);
                                },
                              ))
                          .toList(),
                    );
                  }),
            ),
            Expanded(
                child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _message.length,
                    itemBuilder: (context, index) {
                      final message = _message[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5.0),
                        child: Align(
                          alignment: message.me
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            //width: size.width * 0.6,
                            constraints:
                                BoxConstraints(maxWidth: size.width * 0.6),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                                borderRadius: message.me
                                    ? const BorderRadius.only(
                                        topRight: Radius.circular(16),
                                        topLeft: Radius.circular(8),
                                        bottomLeft: Radius.circular(8))
                                    : const BorderRadius.only(
                                        topRight: Radius.circular(8),
                                        topLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(8)),
                                color: message.me
                                    ? Colors.blueGrey[300]
                                    : Colors.brown[300]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  child: Text(
                                    message.me
                                        ? "Me"
                                        : _connectedClientName ?? "Client",
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                                Text(message.message),
                              ],
                            ),
                          ),
                        ),
                      );
                    })),
            TextField(
              enabled: _connectedClientName != null,
              controller: _textEditingController,
              maxLines: 1,
              onSubmitted: (value) {
                _sendMessage(_textEditingController.text);
                _textEditingController.clear();
              },
              decoration: InputDecoration(
                  hintText: "Message",
                  border: const OutlineInputBorder(),
                  isDense: true, // Reduces the height
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  suffixIcon: IconButton(
                      onPressed: () {
                        _sendMessage(_textEditingController.text);
                        _textEditingController.clear();
                      },
                      icon: const Icon(Icons.send))),
            )
          ],
        ),
      ),
      // floatingActionButton: Column(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: [
      //     FloatingActionButton.extended(
      //       onPressed: () {
      //         _localDataService.sendMessage("Hello");
      //       },
      //       tooltip: 'broadcast',
      //       icon: const Icon(Icons.start),
      //       label: const Text("Start Broadcast"),
      //     ),
      //     FloatingActionButton.extended(
      //       onPressed: _localDataService.close,
      //       tooltip: 'close local data service',
      //       icon: const Icon(Icons.close),
      //       label: const Text("Close LAC"),
      //     ),
      //   ],
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
