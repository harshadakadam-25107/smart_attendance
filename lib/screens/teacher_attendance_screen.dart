import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/excel_service.dart';
import '../services/biometric_service.dart';

class TeacherAttendanceScreen extends StatelessWidget {
  final String sessionId;

  const TeacherAttendanceScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: BiometricService().authenticate(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }

        if (authSnap.data != true) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(color: Color(0xFF1E293B)),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint_rounded, size: 80, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    "Authentication Failed",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(
              "Attendance Records",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF4F46E5),
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_rounded),
                tooltip: "Export Excel",
                onPressed: () async {
                  String path = await ExcelService().exportSessionAttendance(sessionId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Excel Saved at: $path"),
                        backgroundColor: Colors.green.shade600,
                      ),
                    );
                  }
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Container(
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
              ),
            ),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("attendance")
                .where("sessionId", isEqualTo: sessionId)
                .orderBy("time", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        "No students marked yet",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              var docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index];
                  String studentId = data["studentId"];
                  DateTime time = (data["time"] as Timestamp).toDate();
                  String formattedTime = DateFormat('hh:mm a').format(time);

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection("students").doc(studentId).get(),
                    builder: (context, studentSnap) {
                      String name = "Loading...";
                      String prn = "Connecting...";

                      if (studentSnap.hasData && studentSnap.data!.exists) {
                        name = studentSnap.data!["name"] ?? "Unknown Student";
                        prn = studentSnap.data!["prn"] ?? "No PRN";
                      } else if (studentSnap.hasError) {
                        name = "Data Error";
                        prn = studentId.substring(0, 8);
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF4F46E5).withOpacity(0.15),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF4F46E5)),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.badge_rounded, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  prn,
                                  style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formattedTime,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981), // Emerald green
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Present",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}