import 'package:flutter/material.dart';
import 'package:cashflowapp/pages/Dashboard.dart';
import 'package:cashflowapp/pages/Account.dart';
import 'package:cashflowapp/pages/Transaction.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: Pages());
  }
}

class Pages extends StatefulWidget {
  @override
  Homes createState() => Homes();
}

class Homes extends State<Pages> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    Dashboard(),
    Account(),
    Transaction()
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("TItle"), actions: [Icon(Icons.contacts)]),
    );
  }
}
