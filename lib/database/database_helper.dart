import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register Student
  Future<void> registerStudent(Map<String, dynamic> data) async {
    await _firestore.collection("students").doc(data['uid']).set(data);
  }

  // Register Teacher
  Future<void> registerTeacher(Map<String, dynamic> data) async {
    await _firestore.collection("teachers").doc(data['uid']).set(data);
  }

  // Create Session
  Future<void> createSession(Map<String, dynamic> data) async {
    await _firestore.collection("sessions").add(data);
  }

  // Mark Attendance
  Future<void> markAttendance(Map<String, dynamic> data) async {
    await _firestore.collection("attendance").add(data);
  }

  // Get Active Session
  Future<QuerySnapshot> getActiveSession() async {
    return await _firestore
        .collection("sessions")
        .where("status", isEqualTo: "active")
        .get();
  }

  // Get Students Division Wise
  Stream<QuerySnapshot> getStudents(String division, String batch) {
    return _firestore
        .collection("students")
        .where("division", isEqualTo: division)
        .where("batch", isEqualTo: batch)
        .snapshots();
  }
}
