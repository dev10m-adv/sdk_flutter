import 'package:flutter/material.dart';
import 'package:uids_io_sdk_flutter/gmail_sso.dart';
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
  void switchScreen(String screen, {List<String>? options, String? user, String? device, List<String>? tokens}) {
    setState(() {
      currentScreen = screen;
      if (options != null) {
        entityOptions = options;
      }
      if (user != null) {
        username = user;
      }
      if (device != null) {
        deviceId = device;
      }
      if (tokens != null) {
        refreshTokens = tokens;
      }
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
      case "selectEntity":
        return SelectEntityScreen(
          switchScreen: switchScreen,
          tenants: entityOptions,
          username: username,
          deviceId: deviceId,
          refreshTokens: refreshTokens,
        );
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
        const SizedBox(height: 40),
        TextField(
          decoration: InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.email, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
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
            onPressed: () => switchScreen("otp"),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ",
                style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => switchScreen("register"),
              child: const Text("Sign Up",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Divider with "OR" text
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
        // Auth Buttons (Google & Facebook)
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
    return Column(
      children: [
        const Text("Register",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 40),
        TextField(
          decoration: InputDecoration(
            labelText: "Full Name",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.person, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: InputDecoration(
            labelText: "Email",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.email, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
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
            onPressed: () => switchScreen("otp"),
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
  // final Function(String, {List<String>? options}) switchScreen;
  final Function(String) switchScreen;
  const OtpScreen({required this.switchScreen, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Verify OTP",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        const SizedBox(height: 40),
        TextField(
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
            onPressed: () {
            //   switchScreen("selectEntity", options: [
            //   "Option 1",
            //   "Option 2",
            //   "Option 3",
            //   "Option 4",
            // ]); // Change screen here
            },
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Didn't receive the OTP? ",
                style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () {
                // Add resend OTP logic here
              },
              child: const Text(
                "Resend OTP",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SelectEntityScreen extends StatefulWidget { 
  final Function(String, {List<String>? options, String? user, String? device, List<String>? tokens}) switchScreen;
  final List<String> tenants;
  final String username;
  final String deviceId;
  final List<String> refreshTokens;

  const SelectEntityScreen({
    required this.switchScreen,
    required this.tenants,
    required this.username,
    required this.deviceId,
    required this.refreshTokens,
    super.key,
  });

  @override
  _SelectEntityScreenState createState() => _SelectEntityScreenState();
}

class _SelectEntityScreenState extends State<SelectEntityScreen> {
  String? selectedTenant;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Select Entity",
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 20),
        ...widget.tenants.map((tenant) => buildSelectionBox(tenant)).toList(),

        const SizedBox(height: 30),

        // Next Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: selectedTenant != null
                ? () {
                    int index = widget.tenants.indexOf(selectedTenant!);
                    String selectedRefreshToken = widget.refreshTokens[index];
                    GmailSSO.getJwtFromBackend(
                      widget.username,
                      selectedTenant!,
                      selectedRefreshToken,
                      widget.deviceId,context
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Next",
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // Selection Box Widget
  Widget buildSelectionBox(String tenant) {
    bool isSelected = selectedTenant == tenant;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTenant = tenant;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey : Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(tenant,
            style: TextStyle(
              fontSize: 18,
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }
}
