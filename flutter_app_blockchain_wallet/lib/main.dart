import 'package:flutter/material.dart';

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
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
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
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

// ignore: must_be_immutable
class WebViewScreen extends StatelessWidget {
  final String url;
  final String ethWalletAddress =
      "0x092d2177a829996baf2bba9748ecf1b51a5b954d"; // TODO: replace it with your wallet address
  final String ethPrivateKey =
      "4af...bb0"; // TODO: replace it with your private key (dangerous here)
  Future<String> browserInitScript = rootBundle.loadString('assets/js/init.js');

  WebViewScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenSea Viewer"),
      ),
      body: FutureBuilder<String?>(
        future: browserInitScript,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return InAppWebView(
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source: snapshot.data ?? '',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              initialUrlRequest: URLRequest(url: Uri.parse(url)),
              onWebViewCreated: (controller) async {
                controller.clearCache(); // always logout first
                controller.addJavaScriptHandler(
                  handlerName: 'handleMessage',
                  callback: (args) async {
                    final json = jsonDecode(args[0]);
                    // now json["data"] is the JSON-RPC request object
                    debugPrint("[CW] $json");

                    final rpcId = (json["data"]["id"] is int)
                        ? json["data"]["id"]
                        : int.parse(json["data"]["id"]);
                    final method = json["data"]["method"];
                    final params = json["data"]["params"] ?? [];

                    handleMessage(method, params).then((result) {
                      debugPrint("[CW][TTT] $result");
                      controller.callAsyncJavaScript(
                        functionBody:
                            _getPostMessageFunctionBody(rpcId, result),
                      );
                    }).catchError((e) {
                      controller.callAsyncJavaScript(
                        functionBody:
                            _getPostErrorMessageFunctionBody(rpcId, e),
                      );
                    });
                  },
                );
              },
              onConsoleMessage: (InAppWebViewController controller,
                  ConsoleMessage consoleMessage) {
                debugPrint("[CW][OOO] ${consoleMessage.message}");
              },
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  List<int> hexToBytes(String hexString) {
    hexString = hexString.replaceAll('0x', ''); // remove the '0x' prefix
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      bytes.add(int.parse(hexString.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<dynamic> handleMessage(
    String method,
    List<dynamic> params,
  ) async {
    debugPrint("[CW][case] XXX");
    switch (method) {
      case "personal_sign":
        String hexMessage = params[0];
        Uint8List messageBytes = Uint8List.fromList(hexToBytes(hexMessage));
        String signature = EthSigUtil.signPersonalMessage(
            privateKey: ethPrivateKey, message: messageBytes);
        debugPrint('[CW] Signature: $signature');
        return signature;

      case "eth_getBalance":
        return [ethWalletAddress];
      case "eth_accounts":
        return [ethWalletAddress];
      case "eth_requestAccounts":
        // ...
//        if (userAccepted) {
//          return [wallet.address];
//        }
        return [ethWalletAddress];
//        throw JsonRpcError(
//            code: 4001, message: "The request was rejected by the user");
////       case "eth_signTransaction":
////         // ...
////         if (userAccepted) {
////           return signTransaction(params);
////         }
////         throw JsonRpcError(
////             code: 4001, message: "The request was rejected by the user");
////       case "wallet_switchEthereumChain":
////         // ...
////         if (!chainSupported) {
////           throw JsonRpcError(code: 4902, message: "Unrecognized chain ID.");
////         }
////         if (userAccepted) {
////           return switchEthereumChain(params);
////         }
////         throw JsonRpcError(
////             code: 4001, message: "The request was rejected by the user");
////
////       // add more cases here
////       // e.g. eth_signTypedData_v4
////       default:
////         return postAlchemyRpc(method, params);
    }
  }

  String _getPostMessageFunctionBody(int id, dynamic result) {
    return '''
        try {
          window.postMessage({
            "target":"metamask-inpage",
            "data":{
              "name":"metamask-provider",
              "data":{
                "jsonrpc":"2.0",
                "id":$id,
                "result":${jsonEncode(result)}
              }
            }
          }, '*');
        } catch (e) {
          console.log('Error in evaluating javascript: ' + e);
        }
  ''';
  }

  String _getPostErrorMessageFunctionBody(int id, String error) {
    return '''
        try {
          window.postMessage({
            "target":"metamask-inpage",
            "data":{
              "name":"metamask-provider",
              "data":{
                "jsonrpc":"2.0",
                "id":$id,
                "error":$error
              }
            }
          }, '*');
        } catch (e) {
          console.log('Error in evaluating javascript: ' + e);
        }
  ''';
  }
}
