import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'provider_homepage.dart';
import 'user_homepage.dart';
import 'admin_homepage.dart'; // Import AdminHomePage

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userUid = userCredential.user?.uid;

      // Fetch userType and disable status from Realtime Database
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('userprofiles/$userUid');
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final userType = data['userType'];
        final isDisabled = data['disable'] ?? false;

        if (isDisabled) {
          // User is banned
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been banned.'),
              backgroundColor: Colors.red,
            ),
          );

          await _auth.signOut(); // Log out the banned user
          return;
        }

        if (userType == 'User') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UserHomePage()),
          );
        } else if (userType == 'Provider') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ProviderHomePage()),
          );
        } else if (userType == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminHomePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported user type: $userType')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Unified white container for logo and login form
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          // Logo inside the card
                          Image.asset(
                            'img/logosss.png',
                            height: 120,
                            width: 120,
                          ),
                          const SizedBox(
                              height: 24), // Spacing between logo and inputs
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 80, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: Colors.blueAccent,
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: const Text(
                      'Don’t have an account? Register',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
