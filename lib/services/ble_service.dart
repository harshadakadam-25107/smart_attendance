import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // ─────────────────────────────────────────────
  // 👨‍🏫 TEACHER: START ADVERTISING
  // ─────────────────────────────────────────────
  Future<void> startAdvertising(String uuid) async {
    try {
      // 🔴 REQUIRED FOR ANDROID 12+: Request ALL Bluetooth Permissions (OnePlus / Samsung fix)
      await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      // Create a Uint8List from the first 8 characters of the UUID
      final List<int> utf8Bytes = uuid.substring(0, 8).codeUnits;
      final manufacturerData = Uint8List.fromList(utf8Bytes);

      final advertiseData = AdvertiseData(
        includeDeviceName: false, 
        serviceUuids: ['0000180D-0000-1000-8000-00805f9b34fb'], // 🔴 TRICK: 16-bit Bluetooth SIG UUID avoids payload overflow but satisfies OS.
        manufacturerId: 0x00E0, 
        manufacturerData: manufacturerData,
      );

      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeBalanced, // 🔴 RELAXED: Strict battery optimization sometimes kills "LowLatency".
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium, // 🔴 RELAXED: Samsung/OnePlus aggressively block "High" power broadcasts silently to save battery!
          connectable: false,
          timeout: 0,
        ),
      );

      print("✅ BLE Advertising STARTED");
      print("📡 UUID: $uuid");

    } catch (e) {
      print("❌ Advertising Error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // 🛑 STOP ADVERTISING
  // ─────────────────────────────────────────────
  Future<void> stopAdvertising() async {
    try {
      await _blePeripheral.stop();
      print("🛑 BLE Advertising STOPPED");
    } catch (e) {
      print("❌ Stop Error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // ⚙️ HARDWARE SUPPORT CHECK
  // ─────────────────────────────────────────────
  Future<bool> isSupported() async {
    final result = await _blePeripheral.isSupported;
    return result;
  }

  // ─────────────────────────────────────────────
  // 👩‍🎓 STUDENT: SCAN & MATCH
  // ─────────────────────────────────────────────
  Future<bool> scanForTeacher({
    required String sessionUUID,
    int? rssiThreshold,
    Function(String)? onLog,
  }) async {
    final Completer<bool> completer = Completer<bool>();
    StreamSubscription? subscription;

    final shortId = sessionUUID.substring(0, 8).toLowerCase();
    onLog?.call("Scanning...\nLooking for: $shortId...");

    int devicesFound = 0;

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
    );

    subscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        devicesFound++;
        
        final serviceUuids = r.advertisementData.serviceUuids;
        final serviceDataKeys = r.advertisementData.serviceData.keys;

        onLog?.call("Found $devicesFound devices...\nLast: ${r.device.platformName.isEmpty ? 'Unknown' : r.device.platformName}");

        bool matchService = serviceUuids.any((uuid) => 
            uuid.toString().toLowerCase() == sessionUUID.toLowerCase());
            
        bool matchData = serviceDataKeys.any((uuid) => 
            uuid.toString().toLowerCase() == sessionUUID.toLowerCase());

        // 🔴 PARSE MANUFACTURER DATA BYTES BACK TO STRING
        bool matchManufacturer = false;
        r.advertisementData.manufacturerData.forEach((id, bytes) {
          try {
            String decoded = String.fromCharCodes(bytes).toLowerCase();
            if (decoded.contains(shortId)) {
              matchManufacturer = true;
            }
          } catch (_) {}
        });

        // 🔴 FALLBACK MATCH
        bool fallbackMatch = r.advertisementData.toString().toLowerCase().contains(shortId);

        if (matchService || matchData || matchManufacturer || fallbackMatch) {
          onLog?.call("MATCH FOUND! ✅\nStopping scan.");
          print("✅ MATCH FOUND!");

          await FlutterBluePlus.stopScan();
          await subscription?.cancel();

          if (!completer.isCompleted) {
            completer.complete(true);
          }
          return;
        }
      }
    });

    FlutterBluePlus.isScanning.listen((isScanning) async {
      if (!isScanning && !completer.isCompleted) {
        onLog?.call("Scan finished. 0 Matches.");
        await subscription?.cancel();
        completer.complete(false);
      }
    });

    return completer.future;
  }
}