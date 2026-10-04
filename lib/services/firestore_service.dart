import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // ✅ CREATE SESSION (BLE BASED)
  // ─────────────────────────────────────────────
  Future<String> createSession({
    required String subject,
    required String division,
    String? batch,
    required String bleId, // ✅ IMPORTANT
  }) async {

    DateTime start = DateTime.now();
    DateTime end = start.add(const Duration(minutes: 5));

    DocumentReference doc = await _db.collection("sessions").add({
      "sessionId": "",
      "subject": subject,
      "division": division,
      "batch": batch,
      "bleId": bleId, // ✅ BLE ID
      "startTime": start,
      "endTime": end,
      "status": "active",
    });

    await doc.update({"sessionId": doc.id});

    return doc.id;
  }

  // ─────────────────────────────────────────────
  // ✅ CLOSE SESSION
  // ─────────────────────────────────────────────
  Future<void> closeSession(String sessionId) async {
    await _db.collection("sessions")
        .doc(sessionId)
        .update({"status": "closed"});
  }

  // ─────────────────────────────────────────────
  // ✅ GET ACTIVE SESSION
  // ─────────────────────────────────────────────
  Future<QuerySnapshot> getActiveSession() async {
    return await _db.collection("sessions")
        .where("status", isEqualTo: "active")
        .get();
  }

  // ─────────────────────────────────────────────
  // ✅ MARK ATTENDANCE (IMPROVED)
  // ─────────────────────────────────────────────
  Future<String> markAttendance({
    required String sessionId,
    required String studentId,
    required String deviceId,
  }) async {
    try {

      // 🔥 CHECK SESSION
      DocumentSnapshot sessionDoc =
      await _db.collection("sessions").doc(sessionId).get();

      if (!sessionDoc.exists) {
        return "Invalid session";
      }

      var session = sessionDoc.data() as Map<String, dynamic>;

      if (session["status"] != "active") {
        return "Session closed";
      }

      DateTime endTime =
      (session["endTime"] as Timestamp).toDate();

      if (DateTime.now().isAfter(endTime)) {
        return "Session expired";
      }

      // 🔥 DUPLICATE CHECK (student)
      var existing = await _db.collection("attendance")
          .where("sessionId", isEqualTo: sessionId)
          .where("studentId", isEqualTo: studentId)
          .get();

      if (existing.docs.isNotEmpty) {
        return "Already marked";
      }

      // 🔥 DEVICE CHECK
      var deviceCheck = await _db.collection("attendance")
          .where("sessionId", isEqualTo: sessionId)
          .where("deviceId", isEqualTo: deviceId)
          .get();

      if (deviceCheck.docs.isNotEmpty) {
        return "Device already used";
      }

      // 🔥 SAVE
      await _db.collection("attendance").add({
        "sessionId": sessionId,
        "studentId": studentId,
        "deviceId": deviceId,
        "time": FieldValue.serverTimestamp(),
        "method": "BLE + Fingerprint",
      });

      return "success";

    } catch (e) {
      return "error";
    }
  }
}