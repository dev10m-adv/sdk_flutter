import 'package:flutter/material.dart';
import 'package:uids_io_sdk_flutter/gmail_sso.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // For jsonDecode
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthButtons extends StatefulWidget {
  const AuthButtons({super.key});

  @override
  _AuthButtonsState createState() => _AuthButtonsState();
}

class _AuthButtonsState extends State<AuthButtons> {
  final GmailSSO _gmailSSO = GmailSSO();
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  bool _isGmailAvailable = false;
  bool _isGitHubAvailable = false;
  bool _isFacebookAvailable = false;

  // Function to get the configuration from secure storage
  Future<void> _loadConfig() async {
    final confString = await secureStorage.read(key: 'Configurations');
    if (confString != null) {
      List<dynamic> conf = jsonDecode(confString);
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

      // Update the flags based on the config
      setState(() {
        _isGmailAvailable = gmailConfig != null;
        _isGitHubAvailable = gitHubConfig != null;
        _isFacebookAvailable = facebookConfig != null;
      });
    }
  }

  // Sign in function for Gmail
  void _signIn(BuildContext context) async {
    await _gmailSSO.signInWithGoogle(context);
  }

  @override
  void initState() {
    super.initState();
    _loadConfig(); // Load config when the widget is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Conditionally render the sign-in button
        if (_isGmailAvailable)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _signIn(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: const BorderSide(color: Colors.grey),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConditionalImageWidget(
                      imagePath: "assets/images/google_icon.png"),
                  const SizedBox(width: 10),
                  const Text("Sign in with Google",
                      style: TextStyle(fontSize: 18, color: Colors.black)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        if (_isGitHubAvailable)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {}, // ❌ No implementation for GitHub
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConditionalImageWidget(
                    imagePath: "assets/images/github_icon.png"),
                const SizedBox(width: 10),
                const Text("Sign in with GitHub",
                    style: TextStyle(fontSize: 18, color: Colors.black)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
         if (_isFacebookAvailable)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {}, // ❌ No implementation for Facebook
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConditionalImageWidget(
                    imagePath: "assets/images/facebook_icon.png"),
                const SizedBox(width: 10),
                const Text("Sign in with Facebook",
                    style: TextStyle(fontSize: 18, color: Colors.black)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ConditionalImageWidget extends StatefulWidget {
  final String imagePath;

  const ConditionalImageWidget({required this.imagePath, super.key});

  @override
  _ConditionalImageWidgetState createState() => _ConditionalImageWidgetState();
}

class _ConditionalImageWidgetState extends State<ConditionalImageWidget> {
  bool _imageExists = false;

  @override
  void initState() {
    super.initState();
    _checkImageExistence();
  }

  Future<void> _checkImageExistence() async {
    try {
      await rootBundle.load(widget.imagePath);
      setState(() {
        _imageExists = true;
      });
    } catch (e) {
      setState(() {
        _imageExists = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _imageExists
        ? Image.asset(widget.imagePath, height: 24, width: 24)
        : const SizedBox(); // Empty space if no image exists
  }
}
