import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../telemetry/screen_time_tracker.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key, required this.tracker});

  final ScreenTimeTracker tracker;

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  static const _channel = MethodChannel('focusknight/apps');
  late final Map<String, String> _selected = Map.of(widget.tracker.trackedApps);
  late Future<Map<String, String>> _apps = _loadApps();
  String _query = '';
  bool _saving = false;

  Future<Map<String, String>> _loadApps() async =>
      await _channel.invokeMapMethod<String, String>('listApps') ?? {};

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.tracker.setTrackedApps(_selected);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được danh sách ứng dụng. Hãy thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Chọn ứng dụng')),
      body: FutureBuilder<Map<String, String>>(
        future: _apps,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không tải được danh sách ứng dụng.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _apps = _loadApps();
                    }),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final installed = snapshot.data!;
          final apps = {...widget.tracker.trackedApps, ...installed};
          final visible =
              apps.entries
                  .where(
                    (app) =>
                        app.value.toLowerCase().contains(_query) ||
                        app.key.toLowerCase().contains(_query),
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      a.value.toLowerCase().compareTo(b.value.toLowerCase()),
                );
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'App được chọn sẽ được theo dõi thời gian, áp dụng Strict mode và chặn trong trận Pomodoro.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Tìm ứng dụng',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('Không tìm thấy ứng dụng.'))
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final app = visible[index];
                          return CheckboxListTile(
                            key: ValueKey(app.key),
                            title: Text(
                              app.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: installed.containsKey(app.key)
                                ? null
                                : const Text('Đã chọn trước đó'),
                            value: _selected.containsKey(app.key),
                            onChanged: _saving
                                ? null
                                : (checked) => setState(() {
                                    if (checked == true) {
                                      _selected[app.key] = app.value;
                                    } else {
                                      _selected.remove(app.key);
                                    }
                                  }),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Đang lưu…' : 'Lưu (${_selected.length})',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
