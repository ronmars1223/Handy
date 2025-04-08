import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:handycrew/provider_homepage.dart';
import 'package:handycrew/register.dart';
import 'User_homepage.dart';
import 'edit_profile.dart';
import 'login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/edit_profile': (context) => EditProfilePage(),
        '/user_homepage': (context) => UserHomePage(),
        '/provider_homepage': (context) => ProviderHomePage(),
      },
    );
  }
}
