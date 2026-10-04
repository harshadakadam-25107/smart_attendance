import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String role = "student";

  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final prn = TextEditingController();
  final division = TextEditingController();
  final batch = TextEditingController();

  bool isLoading = false;
  bool isPasswordHidden = true;

  // 🔐 REGISTER FUNCTION
  Future<void> registerUser() async {
    if (name.text.isEmpty ||
        email.text.isEmpty ||
        password.text.isEmpty ||
        (role == "student" &&
            (prn.text.isEmpty ||
                division.text.isEmpty ||
                batch.text.isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      String uid = user.user!.uid;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .set({
        "uid": uid,
        "name": name.text.trim(),
        "email": email.text.trim(),
        "role": role,
        "prn": role == "student" ? prn.text.trim() : "",
        "division": role == "student" ? division.text.trim() : "",
        "batch": role == "student" ? batch.text.trim() : "",
        "deviceId": "",
      });

      if (role == "student") {
        await FirebaseFirestore.instance
            .collection("students")
            .doc(uid)
            .set({
          "uid": uid,
          "name": name.text.trim(),
          "prn": prn.text.trim(),
          "division": division.text.trim(),
          "batch": batch.text.trim(),
          "email": email.text.trim(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );

      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      String message = "Registration failed";
      if (e.code == 'email-already-in-use') {
        message = "Email already in use";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    prn.dispose();
    division.dispose();
    batch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4F46E5), // Indigo
              Color(0xFF06B6D4), // Cyan
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Card(
              elevation: 16,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 48,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      "Create Account",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B), // Slate 800
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: role,
                      style: GoogleFonts.poppins(color: const Color(0xFF1E293B)),
                      decoration: const InputDecoration(
                        labelText: "Select Role",
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: "student", child: Text("Student")),
                        DropdownMenuItem(value: "teacher", child: Text("Teacher")),
                      ],
                      onChanged: (value) {
                        setState(() {
                          role = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: name,
                      style: GoogleFonts.poppins(),
                      decoration: const InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Student Specific Fields
                    if (role == "student") ...[
                      TextField(
                        controller: prn,
                        style: GoogleFonts.poppins(),
                        decoration: const InputDecoration(
                          labelText: "PRN Number",
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: division,
                              style: GoogleFonts.poppins(),
                              decoration: const InputDecoration(
                                labelText: "Division",
                                prefixIcon: Icon(Icons.class_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: batch,
                              style: GoogleFonts.poppins(),
                              decoration: const InputDecoration(
                                labelText: "Batch",
                                prefixIcon: Icon(Icons.group_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(),
                      decoration: const InputDecoration(
                        labelText: "Email Address",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: password,
                      obscureText: isPasswordHidden,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordHidden = !isPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : registerUser,
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text("REGISTER NOW"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}