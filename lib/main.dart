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
    Dashboard(), Account(), Transaction()
  ];

  final List<String> titles = const [
    "Dashboard",
    "Account",
    "Transaction",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]), 
        actions: [
          Icon(Icons.person_3)
        ]
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => {
          setState(() {
            _currentIndex = index;
          })
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Dashboard"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "Account"
          ),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on_sharp),
          label: "Transaction")
        ],
      ),
    );
  }
}
