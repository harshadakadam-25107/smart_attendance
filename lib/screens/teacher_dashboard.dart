import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/excel_service.dart';
import '../services/ble_service.dart';
import 'teacher_attendance_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {

  String? lectureType;
  String? selectedDivision;
  String? selectedBatch;
  String? selectedRoomType;

  bool sessionActive = false;
  String? sessionId;
  String? bleId;

  Timer? timer;

  final BleService bleService = BleService();

  // ─────────────────────────────────────────────
  // ✅ START SESSION (FINAL FIXED)
  // ─────────────────────────────────────────────
  Future<void> startSession() async {
    try {
      if (lectureType == null ||
          selectedDivision == null ||
          selectedRoomType == null) {
        _show("⚠️ Please fill all required fields");
        return;
      }

      if (lectureType == "Lab" && selectedBatch == null) {
        _show("⚠️ Please select a batch for Laboratory");
        return;
      }

      if (sessionActive) {
        _show("⚠️ A session is already currently active");
        return;
      }

      bool isSupported = await bleService.isSupported();
      if (!isSupported) {
        _show("❌ CRITICAL: This phone's hardware DOES NOT support BLE Advertising.");
        return;
      }

      final start = DateTime.now();
      final end = start.add(const Duration(minutes: 10));

      bleId = const Uuid().v4();
      
      try {
        await bleService.startAdvertising(bleId!);
      } catch (e) {
        _show("⚠️ BLE failed to start broadcasting, but continuing...");
      }

      final doc = await FirebaseFirestore.instance
          .collection("sessions")
          .add({
        "sessionId": "",
        "bleId": bleId,
        "division": selectedDivision,
        "batch": lectureType == "Lab" ? selectedBatch : null,
        "type": lectureType,
        "roomType": selectedRoomType,
        "status": "active",
        "startTime": start,
        "endTime": end,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await doc.update({"sessionId": doc.id});

      sessionId = doc.id;

      setState(() {
        sessionActive = true;
      });

      _show("✅ Attendance session started");

      timer = Timer(const Duration(minutes: 10), () {
        stopSession();
      });

    } catch (e) {
      _show("❌ Error starting session: $e");
    }
  }

  // ─────────────────────────────────────────────
  // ✅ STOP SESSION
  // ─────────────────────────────────────────────
  Future<void> stopSession() async {
    try {
      timer?.cancel();
      await bleService.stopAdvertising();

      if (sessionId != null) {
        await FirebaseFirestore.instance
            .collection("sessions")
            .doc(sessionId)
            .update({"status": "closed"});
      }

      setState(() {
        sessionActive = false;
      });

      _show("⛔ Session Ended Successfully");

    } catch (e) {
      _show("❌ Error stopping session");
    }
  }

  // ─────────────────────────────────────────────
  void _show(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Teacher Dashboard",
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: sessionActive 
                    ? [const Color(0xFF10B981), const Color(0xFF059669)] // Green when active
                    : [const Color(0xFF4F46E5), const Color(0xFF06B6D4)], // Indigo/cyan when idle
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (sessionActive ? Colors.green : const Color(0xFF4F46E5)).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    sessionActive ? Icons.podcasts_rounded : Icons.sensors_off_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    sessionActive ? "Broadcasting BLE Signal" : "Ready to Start Session",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (sessionActive) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Students can now verify proximity and mark attendance.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9)),
                    ),
                  ]
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Form Card
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Session Details",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          DropdownButtonFormField<String>(
                            hint: const Text("Lecture Type"),
                            value: lectureType,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.class_rounded)),
                            items: ["Theory", "Lab"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: sessionActive
                                ? null
                                : (val) => setState(() => lectureType = val),
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            hint: const Text("Division"),
                            value: selectedDivision,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.group_rounded)),
                            items: ["A", "B", "C", "D"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: sessionActive
                                ? null
                                : (val) => setState(() => selectedDivision = val),
                          ),
                          const SizedBox(height: 16),

                          if (lectureType == "Lab") ...[
                            DropdownButtonFormField<String>(
                              hint: const Text("Batch"),
                              value: selectedBatch,
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.science_rounded)),
                              items: ["Batch 1", "Batch 2", "Batch 3", "Batch 4"]
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: sessionActive
                                  ? null
                                  : (val) => setState(() => selectedBatch = val),
                            ),
                            const SizedBox(height: 16),
                          ],

                          DropdownButtonFormField<String>(
                            hint: const Text("Room Type"),
                            value: selectedRoomType,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.meeting_room_rounded)),
                            items: ["Classroom", "Seminar Hall", "Laboratory"]
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: sessionActive
                                ? null
                                : (val) => setState(() => selectedRoomType = val),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  if (!sessionActive)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text("START ATTENDANCE"),
                      onPressed: startSession,
                    )
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text("STOP SESSION"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shadowColor: Colors.red.shade300,
                      ),
                      onPressed: stopSession,
                    ),

                  const SizedBox(height: 20),

                  if (sessionId != null) ...[
                    const Divider(height: 40),
                    Text(
                      "Management",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility_rounded),
                            label: const Text("View"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeacherAttendanceScreen(sessionId: sessionId!),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.file_download_rounded),
                            label: const Text("Export"),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.green.shade600, width: 1.5),
                              foregroundColor: Colors.green.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              String path = await ExcelService().exportSessionAttendance(sessionId!);
                              _show("Saved at: $path");
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    bleService.stopAdvertising();
    super.dispose();
  }
}