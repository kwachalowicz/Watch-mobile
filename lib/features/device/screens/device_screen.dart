import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/providers.dart';
import '../../../data/ble/ble_service.dart';

class DeviceScreen extends ConsumerStatefulWidget {
  const DeviceScreen({super.key});

  @override
  ConsumerState<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends ConsumerState<DeviceScreen> {
  List<ScanResult> _results = [];
  StreamSubscription? _scanSub;
  bool _permissionsOk = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Na Windows/desktop nie ma BLE permissions handler.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      setState(() => _permissionsOk = true);
      return;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    setState(() {
      _permissionsOk = statuses.values.every((s) => s.isGranted || s.isLimited);
    });
  }

  Future<void> _startScan() async {
    if (!_permissionsOk) {
      await _checkPermissions();
      if (!_permissionsOk) return;
    }

    setState(() => _results = []);

    final ble = ref.read(bleServiceProvider);
    await _scanSub?.cancel();
    _scanSub = ble.scanForBangles().listen((list) {
      setState(() => _results = list);
    });
  }

  Future<void> _stopScan() async {
    final ble = ref.read(bleServiceProvider);
    await ble.stopScan();
    await _scanSub?.cancel();
  }

  Future<void> _connect(BluetoothDevice device) async {
    final ble = ref.read(bleServiceProvider);
    final coord = ref.read(bleSyncCoordinatorProvider);

    try {
      await ble.connect(device);
      coord.start();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Połączono z ${device.platformName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd połączenia: $e')));
      }
    }
  }

  Future<void> _disconnect() async {
    final ble = ref.read(bleServiceProvider);
    final coord = ref.read(bleSyncCoordinatorProvider);
    await coord.stop();
    await ble.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(bleStateProvider);
    final connState = stateAsync.value ?? BangleConnectionState.disconnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Zegarek')),
      body: Column(
        children: [
          _ConnectionStatusCard(
            state: connState,
            deviceName: ref.read(bleServiceProvider).device?.platformName,
            onDisconnect: _disconnect,
          ),
          if (!_permissionsOk)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Brak uprawnień Bluetooth'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _checkPermissions,
                        child: const Text('Nadaj uprawnienia'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (connState == BangleConnectionState.disconnected ||
              connState == BangleConnectionState.scanning) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: connState == BangleConnectionState.scanning
                      ? _stopScan
                      : _startScan,
                  icon: Icon(
                    connState == BangleConnectionState.scanning
                        ? Icons.stop_rounded
                        : Icons.bluetooth_searching_rounded,
                  ),
                  label: Text(
                    connState == BangleConnectionState.scanning
                        ? 'Zatrzymaj skanowanie'
                        : 'Szukaj Bangle.js',
                  ),
                ),
              ),
            ),
            Expanded(child: _buildResultsList()),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Brak znalezionych zegarków.\n\n'
            'Upewnij się że Bangle.js jest włączony i widoczny '
            '(Settings > Bluetooth > Make Connectable).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _results[i];
        return ListTile(
          leading: const Icon(Icons.watch_rounded),
          title: Text(r.device.platformName),
          subtitle: Text('${r.device.remoteId}  •  RSSI ${r.rssi}'),
          trailing: const Icon(Icons.link_rounded),
          onTap: () => _connect(r.device),
        );
      },
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final BangleConnectionState state;
  final String? deviceName;
  final VoidCallback onDisconnect;

  const _ConnectionStatusCard({
    required this.state,
    required this.deviceName,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (state) {
      BangleConnectionState.disconnected => (
        Icons.bluetooth_disabled_rounded,
        'Niepołączony',
        Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      BangleConnectionState.scanning => (
        Icons.bluetooth_searching_rounded,
        'Skanowanie...',
        Theme.of(context).colorScheme.tertiaryContainer,
      ),
      BangleConnectionState.connecting => (
        Icons.bluetooth_connected_rounded,
        'Łączenie...',
        Theme.of(context).colorScheme.tertiaryContainer,
      ),
      BangleConnectionState.connected => (
        Icons.bluetooth_connected_rounded,
        'Połączono${deviceName != null ? ': $deviceName' : ''}',
        Theme.of(context).colorScheme.primaryContainer,
      ),
      BangleConnectionState.error => (
        Icons.error_outline_rounded,
        'Błąd połączenia',
        Theme.of(context).colorScheme.errorContainer,
      ),
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (state == BangleConnectionState.connected)
                IconButton(
                  icon: const Icon(Icons.link_off_rounded),
                  onPressed: onDisconnect,
                  tooltip: 'Rozłącz',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
