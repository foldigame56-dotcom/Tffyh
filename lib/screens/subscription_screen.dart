import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<ServerStore>();
    _controller.text = store.subscriptionUrl ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<ServerStore>();
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    await store.setSubscriptionUrl(url);
    await store.refreshServers();
    if (mounted) {
      if (store.lastError == null) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(store.lastError!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Подписка')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Вставь ссылку на подписку, которую прислал Telegram-бот',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'https://.../sub/xxxxxxxx',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: store.loading ? null : _save,
                child: store.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Сохранить и загрузить серверы'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
