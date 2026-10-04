import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/biometric_service.dart';
import '../services/ble_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool isLoading = false;
  String statusMessage = "Ready to scan for session";

  StreamSubscription? scanSub;

  // ─────────────────────────────────────────────
  // ✅ BLE SCAN WITH FILTER (FIXED)
  // ─────────────────────────────────────────────
  Future<void> scanBLE() async {
    try {
      setState(() {
        isLoading = true;
        statusMessage = "Fetching active session...";
      });

      final sessionQuery = await FirebaseFirestore.instance
          .collection("sessions")
          .where("status", isEqualTo: "active")
          .get();

      if (sessionQuery.docs.isEmpty) {
        _done("❌ No active session found in database");
        return;
      }

      final docs = sessionQuery.docs.toList();
      docs.sort((a, b) {
        final aTime = (a.data()["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b.data()["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      QueryDocumentSnapshot<Map<String, dynamic>>? activeSessionDoc;
      for (var doc in docs) {
        if (doc.data()["bleId"] != null && doc.data()["bleId"].toString().isNotEmpty) {
          activeSessionDoc = doc;
          break;
        }
      }

      if (activeSessionDoc == null) {
        _done("❌ Valid BLE Session not found");
        return;
      }

      final sessionDoc = activeSessionDoc;
      final data = sessionDoc.data();
      String bleId = data["bleId"];

      setState(() {
        statusMessage = "Scanning classroom signals...";
      });

      bool found = await BleService().scanForTeacher(
        sessionUUID: bleId, 
        onLog: (msg) {
          if (mounted) {
            setState(() => statusMessage = msg);
          }
        },
      );

      if (found) {
        await handleAttendance(sessionDoc.id);
      } else {
        _done("❌ Teacher proximity verification failed");
      }

    } catch (e) {
      _done("❌ Error: $e");
    }
  }

  // ─────────────────────────────────────────────
  // ✅ ATTENDANCE LOGIC
  // ─────────────────────────────────────────────
  Future<void> handleAttendance(String sessionId) async {
    try {
      setState(() => statusMessage = "Validating attendance info...");

      final sessionDoc = await FirebaseFirestore.instance
          .collection("sessions")
          .doc(sessionId)
          .get();

      final data = sessionDoc.data()!;
      final endTime = (data["endTime"] as Timestamp).toDate();

      if (DateTime.now().isAfter(endTime)) {
        _done("⛔ Session has expired");
        return;
      }

      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final deviceId = deviceInfo.id ?? deviceInfo.fingerprint;

      final studentId = FirebaseAuth.instance.currentUser!.uid;

      final already = await FirebaseFirestore.instance
          .collection("attendance")
          .where("sessionId", isEqualTo: sessionId)
          .where("studentId", isEqualTo: studentId)
          .get();

      if (already.docs.isNotEmpty) {
        _done("⚠️ Attendance already marked");
        return;
      }

      setState(() => statusMessage = "Waiting for fingerprint auth...");

      bool auth = await BiometricService().authenticate();

      if (!auth) {
        _done("❌ Fingerprint authentication failed");
        return;
      }

      await FirebaseFirestore.instance.collection("attendance").add({
        "sessionId": sessionId,
        "studentId": studentId,
        "deviceId": deviceId,
        "time": FieldValue.serverTimestamp(),
        "method": "BLE + Fingerprint",
      });

      _done("✅ Attendance Marked Successfully");

    } catch (e) {
      _done("❌ Error executing attendance: $e");
    }
  }

  // ─────────────────────────────────────────────
  void _done(String msg) {
    if (mounted) {
      setState(() {
        isLoading = false;
        statusMessage = msg;
      });
    }
  }

  @override
  void dispose() {
    scanSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    bool isSuccess = statusMessage.contains("✅");
    bool isError = statusMessage.contains("❌") || statusMessage.contains("⛔");
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Student Dashboard",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4F46E5),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          )
        ],
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            children: [
              // Header Gradient Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bluetooth_audio_rounded, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Proximity Verification",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ensure your bluetooth is enabled to mark attendance in class.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Status Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSuccess ? Colors.green.shade200 : (isError ? Colors.red.shade200 : Colors.indigo.shade100),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: CircularProgressIndicator(),
                      ),
                    
                    if (!isLoading && isSuccess)
                      Icon(Icons.check_circle_rounded, size: 48, color: Colors.green.shade400)
                    else if (!isLoading && isError)
                      Icon(Icons.error_rounded, size: 48, color: Colors.red.shade400)
                    else if (!isLoading)
                      const Icon(Icons.info_outline_rounded, size: 40, color: Colors.grey),

                    const SizedBox(height: 16),
                    Text(
                      statusMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSuccess ? Colors.green.shade700 : (isError ? Colors.red.shade700 : const Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Scan Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : scanBLE,
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text("MARK ATTENDANCE"),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}