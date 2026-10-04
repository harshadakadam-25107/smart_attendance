import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/biometric_service.dart';

class AttendanceService {

  Future<String> markAttendance(String sessionId) async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 🔥 1. CHECK SESSION
      DocumentSnapshot sessionDoc = await FirebaseFirestore.instance
          .collection("sessions")
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        return "❌ Invalid session";
      }

      var sessionData = sessionDoc.data() as Map<String, dynamic>;

      if (sessionData["status"] != "active") {
        return "⛔ Session not active";
      }

      // 🔥 2. CHECK TIME
      DateTime endTime =
      (sessionData["endTime"] as Timestamp).toDate();

      if (DateTime.now().isAfter(endTime)) {
        return "⛔ Session expired";
      }

      // 🔥 3. DEVICE CHECK
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final deviceId = deviceInfo.id ?? deviceInfo.fingerprint;

      final deviceCheck = await FirebaseFirestore.instance
          .collection("attendance")
          .where("sessionId", isEqualTo: sessionId)
          .where("deviceId", isEqualTo: deviceId)
          .get();

      if (deviceCheck.docs.isNotEmpty) {
        return "⚠️ Already marked from this device";
      }

      // 🔥 4. STUDENT DUPLICATE CHECK
      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection("attendance")
          .where("studentId", isEqualTo: uid)
          .where("sessionId", isEqualTo: sessionId)
          .get();

      if (existing.docs.isNotEmpty) {
        return "⚠️ Attendance already marked";
      }

      // 🔐 5. FINGERPRINT AUTH
      bool auth = await BiometricService().authenticate();

      if (!auth) {
        return "❌ Fingerprint failed";
      }

      // 🔥 6. SAVE ATTENDANCE
      await FirebaseFirestore.instance.collection("attendance").add({
        "studentId": uid,
        "sessionId": sessionId,
        "deviceId": deviceId,
        "time": FieldValue.serverTimestamp(),
        "method": "BLE + Fingerprint",
      });

      return "✅ Attendance marked";

    } catch (e) {
      return "❌ Error: $e";
    }
  }
}