import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExcelService {

  // ─────────────────────────────────────────────
  // ✅ EXPORT SESSION ATTENDANCE
  // ─────────────────────────────────────────────
  Future<String> exportSessionAttendance(String sessionId) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Attendance'];

      // HEADER
      sheet.appendRow([
        TextCellValue("Name"),
        TextCellValue("PRN"),
        TextCellValue("Division"),
        TextCellValue("Batch"),
        TextCellValue("Time"),
      ]);

      // 🔥 FETCH DATA
      QuerySnapshot attendanceSnap = await FirebaseFirestore.instance
          .collection("attendance")
          .where("sessionId", isEqualTo: sessionId)
          .get();

      for (var attDoc in attendanceSnap.docs) {

        String studentId = attDoc["studentId"];

        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection("students")
            .doc(studentId)
            .get();

        if (!studentDoc.exists) continue;

        var student = studentDoc.data() as Map<String, dynamic>;

        final time = attDoc["time"];

        sheet.appendRow([
          TextCellValue(student["name"] ?? ""),
          TextCellValue(student["prn"] ?? ""),
          TextCellValue(student["division"] ?? ""),
          TextCellValue(student["batch"] ?? "-"),
          TextCellValue(
              time != null ? time.toDate().toString() : "N/A"),
        ]);
      }

      // ✅ SAFE PATH
      Directory dir = await getApplicationDocumentsDirectory();
      String path = "${dir.path}/attendance_$sessionId.xlsx";

      File file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(excel.encode()!);

      return path;

    } catch (e) {
      return "error";
    }
  }

  // ─────────────────────────────────────────────
  // ✅ EXPORT ALL STUDENTS
  // ─────────────────────────────────────────────
  Future<String> exportStudents() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Students'];

      sheet.appendRow([
        TextCellValue("Name"),
        TextCellValue("PRN"),
        TextCellValue("Division"),
        TextCellValue("Batch"),
        TextCellValue("Email"),
      ]);

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("students")
          .get();

      for (var doc in snapshot.docs) {
        var d = doc.data() as Map<String, dynamic>;

        sheet.appendRow([
          TextCellValue(d["name"] ?? ""),
          TextCellValue(d["prn"] ?? ""),
          TextCellValue(d["division"] ?? ""),
          TextCellValue(d["batch"] ?? "-"),
          TextCellValue(d["email"] ?? ""),
        ]);
      }

      Directory dir = await getApplicationDocumentsDirectory();
      String path = "${dir.path}/students.xlsx";

      File file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(excel.encode()!);

      return path;

    } catch (e) {
      return "error";
    }
  }
}