import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uids_io_sdk_flutter/auth.dart';
import 'auth_buttons.dart';

final GlobalKey<AuthScreenState> globalKey = GlobalKey<AuthScreenState>();

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  String currentScreen = "login";
  List<String> entityOptions = [];
  String username = "";
  String deviceId = "";
  List<String> refreshTokens = [];
  void switchScreen(String screen) {
    setState(() {
      currentScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400, // Constrain the width for web view
            padding: const EdgeInsets.all(20.0),
            child: _getScreen(),
          ),
        ),
      ),
    );
  }

  Widget _getScreen() {
    switch (currentScreen) {
      case "login":
        return LoginScreen(switchScreen: switchScreen);
      case "register":
        return RegisterScreen(switchScreen: switchScreen);
      case "otp":
        return OtpScreen(switchScreen: switchScreen);
      default:
        return Container();
    }
  }
}

class LoginScreen extends StatelessWidget {
  final Function(String) switchScreen;
  const LoginScreen({required this.switchScreen, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Login",
          style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        UsernameAndPassword(switchScreen: switchScreen),
        AuthButtons(),
      ],
    );
  }
}

class RegisterScreen extends StatelessWidget {
  final Function(String) switchScreen;
  const RegisterScreen({required this.switchScreen, super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();

    // Register function
    void _register() async {
      final String username = _usernameController.text;
      final String email = _emailController.text;
      final String password = _passwordController.text;

      // Validate fields
      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }

      try {
        await registerUser(username, email, password, context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User registered successfully')),
        );
        // switchScreen("otp"); // After successful registration, go to OTP screen
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())), // Show the exact error message
        );
      }
    }

    return Column(
      children: [
        const Text("Register",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 40),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: "Username",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.person, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.email, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _register,
            // onPressed: () => switchScreen("otp"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Sign Up",
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Already have an account? ",
                style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => switchScreen("login"),
              child: const Text("Login",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}

class OtpScreen extends StatelessWidget {
  final Function(String) switchScreen;
  const OtpScreen({required this.switchScreen, super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _otpController = TextEditingController();
    void _verifyOtp() async {
      final String otp = _otpController.text;

      if (otp.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter otp')),
        );
        return;
      }

      try {
        final FlutterSecureStorage secureStorage = FlutterSecureStorage();
        String? otp_at = await secureStorage.read(key: "opt_access_token");
        await verifyOtp(otp, otp_at ?? '', context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())), // Show the exact error message
        );
      }
    }

    return Column(
      children: [
        const Text("Verify OTP",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 40),
        TextField(
          controller: _otpController,
          decoration: InputDecoration(
            labelText: "Enter OTP",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Verify OTP",
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
        // Resend OTP Text
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   children: [
        //     const Text("Didn't receive the OTP? ",
        //         style: TextStyle(color: Colors.grey)),
        //     TextButton(
        //       onPressed: () {
        //         // Add resend OTP logic here
        //       },
        //       child: const Text(
        //         "Resend OTP",
        //         style: TextStyle(
        //           color: Colors.black,
        //           fontWeight: FontWeight.bold,
        //         ),
        //       ),
        //     ),
        //   ],
        // ),
      ],
    );
  }
}

class UsernameAndPassword extends StatefulWidget {
  final Function(String) switchScreen;

  const UsernameAndPassword({required this.switchScreen, super.key});

  @override
  _UsernameAndPasswordState createState() => _UsernameAndPasswordState();
}

class _UsernameAndPasswordState extends State<UsernameAndPassword> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  bool _isAnySSOAvailable = false;
  bool _isEmailAvailable = false;

  void _login() async {
    final String email = _emailController.text;
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    try {
      await loginWithCredentials(
          email, password); // Assume loginWithCredentials is defined elsewhere
      widget.switchScreen("otp");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())), // Show the exact error message
      );
    }
  }

  Future<void> _loadConfig() async {
    final confString = await secureStorage.read(key: 'Configurations');
    if (confString != null) {
      List<dynamic> conf = jsonDecode(confString);

      final emailConfig = conf.firstWhere(
        (config) => config['idpname'] == 'Email',
        orElse: () => null,
      );
      final gmailConfig = conf.firstWhere(
        (config) => config['idpname'] == 'Gmail',
        orElse: () => null,
      );
      final gitHubConfig = conf.firstWhere(
        (config) => config['idpname'] == 'GitHub',
        orElse: () => null,
      );
      final facebookConfig = conf.firstWhere(
        (config) => config['idpname'] == 'Facebook',
        orElse: () => null,
      );

      // Set the single flag to true if any of the services are available
      bool isAnyAvailable =
          gmailConfig != null || gitHubConfig != null || facebookConfig != null;

      // Update the flag based on the availability of any service
      setState(() {
        _isEmailAvailable = emailConfig != null;
        _isAnySSOAvailable = isAnyAvailable;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isEmailAvailable)...[
        const SizedBox(height: 40),
        // Email input field
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.email, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        // Password input field
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.lock, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 30),
        // Login button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Login",
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
        // Sign up link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ",
                style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => widget.switchScreen("register"),
              child: const Text("Sign Up",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ],
        // Divider with "OR" text
        if (_isAnySSOAvailable && _isEmailAvailable)
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.grey)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text("OR", style: TextStyle(color: Colors.grey)),
              ),
              const Expanded(child: Divider(color: Colors.grey)),
            ],
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
