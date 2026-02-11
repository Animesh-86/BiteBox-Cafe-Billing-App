import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hangout_spot/services/thermal_printing_service.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    // Request permissions
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool? isConnected = await _bluetooth.isConnected;
    List<BluetoothDevice> devices = [];
    try {
      devices = await _bluetooth.getBondedDevices();
    } catch (e) {
      // ignore
    }

    setState(() {
      _devices = devices;
      _connected = isConnected ?? false;
    });

    if (_connected) {
      // Ideally we would know which device is connected, but blue_thermal_printer doesn't easily tell us matching the list object
      // We can just rely on user selecting again if needed, or check saved prefs
    }
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final devices = await _bluetooth.getBondedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error scanning: $e")));
      }
    } finally {
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Printer Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 20),
          const Text(
            "Paired Devices",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  "No paired devices found. Pair a printer in system settings first.",
                ),
              ),
            )
          else
            ..._devices.map(_buildDeviceTile).toList(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _connected ? Icons.check_circle : Icons.error,
                  color: _connected ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _connected ? "Connected" : "Not Connected",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_selectedDevice != null)
                      Text(_selectedDevice!.name ?? "Unknown Device"),
                  ],
                ),
              ],
            ),
            if (_connected) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Test Print
                  // final service = ref.read(thermalPrintingServiceProvider);
                  // For a real test we need an Order object, but we can just print simple text here
                  try {
                    // Simple test
                    _bluetooth.printCustom("TEST PRINT SUCCESS", 1, 1);
                    _bluetooth.printNewLine();
                    _bluetooth.printNewLine();
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Print error: $e")),
                      );
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text("Test Print"),
              ),
              TextButton(
                onPressed: () async {
                  await _bluetooth.disconnect();
                  setState(() => _connected = false);
                },
                child: const Text(
                  "Disconnect",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BluetoothDevice device) {
    bool isSelected = _selectedDevice?.address == device.address;
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(device.name ?? "Unknown"),
        subtitle: Text(device.address ?? "No Address"),
        trailing: isSelected && _connected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: () async {
                  setState(() => _selectedDevice = device);
                  try {
                    final service = ref.read(thermalPrintingServiceProvider);
                    await service.connect(device);
                    setState(() => _connected = true);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Connected!")),
                      );
                  } catch (e) {
                    setState(() => _connected = false);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Connection failed: $e")),
                      );
                  }
                },
                child: const Text("Connect"),
              ),
      ),
    );
  }
}
