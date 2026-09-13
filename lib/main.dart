import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'db.dart';

const forest = Color(0xFF0F2E2B);
const gold = Color(0xFFC08A28);
const cream = Color(0xFFF6F2E8);
const ink = Color(0xFF16231F);

final money = NumberFormat('#,##0', 'en_US');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlowPilotApp());
}

class FlowPilotApp extends StatelessWidget {
  const FlowPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: forest, surface: cream),
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: forest,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int tick = 0;

  void refresh() => setState(() => tick++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('d$tick')),
      AccountsPage(onChanged: refresh),
      TransactionsPage(onChanged: refresh),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('FlowPilot')),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Money'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FlowDb.instance.dashboard(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('This phone only. No internet needed.', style: TextStyle(color: Color(0xFF6B6558))),
            const SizedBox(height: 16),
            _Stat('Current balance', d['balance']!, forest),
            _Stat('Cash out this month', d['cashOut']!, const Color(0xFFB3402B)),
            _Stat('Net cash this month', d['net']!, d['net']! >= 0 ? const Color(0xFF2F7A55) : const Color(0xFFB3402B)),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Color(0xFF8A8272))),
            const SizedBox(height: 6),
            Text('${money.format(value)} TZS', style: TextStyle(fontSize: 26, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late Future<List<Map<String, dynamic>>> future = FlowDb.instance.accounts();

  Future<void> reload() async {
    setState(() => future = FlowDb.instance.accounts());
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder(
            future: future,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!;
              if (rows.isEmpty) return const Center(child: Text('No accounts yet'));
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final a = rows[i];
                  return ListTile(
                    title: Text(a['name'] as String),
                    subtitle: Text(a['type'] as String),
                    trailing: Text('${money.format((a['balance'] as num).toDouble())} TZS'),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: forest),
            onPressed: () async {
              final name = TextEditingController();
              final opening = TextEditingController(text: '0');
              String type = 'cash';
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('New account'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: type,
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                          DropdownMenuItem(value: 'airtel_money', child: Text('Airtel Money')),
                          DropdownMenuItem(value: 'bank', child: Text('Bank')),
                        ],
                        onChanged: (v) => type = v ?? 'cash',
                        decoration: const InputDecoration(labelText: 'Type'),
                      ),
                      TextField(
                        controller: opening,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Opening balance'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                  ],
                ),
              );
              if (ok == true && name.text.trim().isNotEmpty) {
                await FlowDb.instance.addAccount(
                  name.text.trim(),
                  type,
                  double.tryParse(opening.text) ?? 0,
                );
                await reload();
              }
            },
            child: const Text('Add account'),
          ),
        ),
      ],
    );
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late Future<List<Map<String, dynamic>>> future = FlowDb.instance.transactions();

  Future<void> reload() async {
    setState(() => future = FlowDb.instance.transactions());
    widget.onChanged();
  }

  Future<void> addMoney() async {
    final accounts = await FlowDb.instance.accounts();
    if (accounts.isEmpty || !mounted) return;
    final amount = TextEditingController();
    final desc = TextEditingController();
    String type = 'expense';
    int accountId = accounts.first['id'] as int;
    int? categoryId;
    var categories = await FlowDb.instance.categories(type);

    final err = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Log money'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Money in')),
                      DropdownMenuItem(value: 'expense', child: Text('Money out')),
                    ],
                    onChanged: (v) async {
                      type = v ?? 'expense';
                      categoryId = null;
                      categories = await FlowDb.instance.categories(type);
                      setLocal(() {});
                    },
                  ),
                  DropdownButtonFormField<int>(
                    value: accountId,
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(value: a['id'] as int, child: Text(a['name'] as String)),
                    ],
                    onChanged: (v) => accountId = v ?? accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                  ),
                  DropdownButtonFormField<int?>(
                    value: categoryId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('What was this money for?')),
                      for (final c in categories)
                        DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String)),
                    ],
                    onChanged: (v) => categoryId = v,
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (TZS)'),
                  ),
                  TextField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(amount.text) ?? 0;
                  if (value <= 0) {
                    Navigator.pop(ctx, 'Enter an amount.');
                    return;
                  }
                  final result = await FlowDb.instance.addTransaction(
                    accountId: accountId,
                    categoryId: categoryId,
                    type: type,
                    amount: value,
                    description: desc.text.trim().isEmpty ? null : desc.text.trim(),
                    date: DateTime.now(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, result);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder(
            future: future,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final rows = snap.data!;
              if (rows.isEmpty) return const Center(child: Text('Nothing logged yet'));
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final t = rows[i];
                  final income = t['type'] == 'income';
                  return ListTile(
                    title: Text((t['description'] as String?)?.isNotEmpty == true
                        ? t['description'] as String
                        : (t['category_name'] as String? ?? t['type'] as String)),
                    subtitle: Text('${t['account_name'] ?? ''} · ${t['transaction_date']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${income ? '+' : '-'}${money.format((t['amount'] as num).toDouble())}',
                          style: TextStyle(color: income ? const Color(0xFF2F7A55) : const Color(0xFFB3402B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.undo, size: 18),
                          onPressed: () async {
                            await FlowDb.instance.rollback(t['id'] as int);
                            await reload();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: forest),
            onPressed: addMoney,
            child: const Text('Log money in / out'),
          ),
        ),
      ],
    );
  }
}
