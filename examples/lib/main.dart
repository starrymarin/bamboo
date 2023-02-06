import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:bamboo/bamboo.dart';
import 'package:bamboo/node/node.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
  const MyHomePage({Key? key, required this.title}) : super(key: key);

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
  List<dynamic> document = [];

  @override
  void initState() {
    super.initState();
    DefaultAssetBundle.of(context)
        .loadString("assets/test.json")
        .then((value) {
      setState(() {
        document = jsonDecode(value);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bamboo")),
      body: Bamboo(document: document.map((e) => e as NodeJson).toList()),
      // body: const DefaultTextStyle(
      //   style: TextStyle(
      //     fontSize: 20,
      //   ),
      //   child: Text.rich(
      //     TextSpan(
      //       children: [
      //         TextSpan(
      //           text: "1111",
      //           style: TextStyle(
      //             fontSize: 16
      //           )
      //         )
      //       ],
      //       style: TextStyle(
      //         height: 3
      //       )
      //     ),
      //     style: TextStyle(
      //       color: Colors.orange
      //     ),
      //   ),
      // ),
    );
  }
}