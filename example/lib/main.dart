import 'package:material_ui/material_ui.dart';
import 'package:wreq/wreq.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wreq Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const WreqHomePage(),
    );
  }
}

class WreqHomePage extends StatefulWidget {
  const WreqHomePage({super.key});

  @override
  State<WreqHomePage> createState() => _WreqHomePageState();
}

class _WreqHomePageState extends State<WreqHomePage> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://pingly.us.kg/api/all',
  );
  final TextEditingController _headersController = TextEditingController(
    text: 'X-Client: Wreq-Flutter-App',
  );

  String _selectedProfile = 'chrome149';
  late final String _version;
  bool _loading = false;
  int? _statusCode;
  int? _elapsedMs;
  String? _responseBody;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    try {
      _version = getWreqVersion();
    } catch (e) {
      _version = 'Unknown ($e)';
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  EmulationProfile _getProfile() {
    return switch (_selectedProfile) {
      'safariIos26_2' => EmulationProfile.safariIos26_2,
      'firefox151' => EmulationProfile.firefox151,
      _ => EmulationProfile.chrome149,
    };
  }

  Future<void> _sendRequest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _responseBody = null;
      _statusCode = null;
      _elapsedMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final headers = <String, String>{};
      for (final line in _headersController.text.split('\n')) {
        final colonIndex = line.indexOf(':');
        if (colonIndex > 0) {
          final key = line.substring(0, colonIndex).trim();
          final val = line.substring(colonIndex + 1).trim();
          if (key.isNotEmpty) headers[key] = val;
        }
      }

      final response = await wreqGet(
        url,
        headers: headers.isEmpty ? null : headers,
        emulation: _getProfile(),
      );

      try {
        setState(() {
          _statusCode = response.statusCode;
          _responseBody = response.body;
          _elapsedMs = stopwatch.elapsedMilliseconds;
        });
      } finally {
        response.dispose();
      }
    } on WreqException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _statusCode = e.statusCode != -1 ? e.statusCode : null;
        _elapsedMs = stopwatch.elapsedMilliseconds;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _elapsedMs = stopwatch.elapsedMilliseconds;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('wreq Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Native Core Version: $_version',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Request URL',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Emulation Profile: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedProfile,
                  items: const [
                    DropdownMenuItem(
                      value: 'chrome149',
                      child: Text('Chrome 149 (Blink)'),
                    ),
                    DropdownMenuItem(
                      value: 'safariIos26_2',
                      child: Text('Safari (iOS 26.2)'),
                    ),
                    DropdownMenuItem(
                      value: 'firefox151',
                      child: Text('Firefox 151 (Gecko)'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedProfile = value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headersController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Custom Headers (Key: Value per line)',
                hintText: 'X-Custom-Header: value',
                prefixIcon: Icon(Icons.code),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _sendRequest,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Send Request'),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_statusCode != null || _elapsedMs != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  if (_statusCode != null)
                    Chip(
                      avatar: Icon(
                        _statusCode! >= 200 && _statusCode! < 300
                            ? Icons.check_circle
                            : Icons.warning,
                        size: 16,
                        color: _statusCode! >= 200 && _statusCode! < 300
                            ? Colors.green
                            : Colors.orange,
                      ),
                      label: Text('Status: $_statusCode'),
                    ),
                  if (_elapsedMs != null)
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text('$_elapsedMs ms'),
                    ),
                  Chip(
                    avatar: const Icon(Icons.fingerprint, size: 16),
                    label: Text(_selectedProfile),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_responseBody != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Text(
                    _responseBody!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
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
