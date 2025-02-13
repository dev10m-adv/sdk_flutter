import 'package:flutter/material.dart';
import 'package:uids_io_sdk_flutter/gmail_sso.dart';
import 'package:flutter/services.dart';

class AuthButtons extends StatelessWidget {
  AuthButtons({super.key});

  final GmailSSO _gmailSSO = GmailSSO();

  void _signIn(BuildContext context) async {
    await _gmailSSO.signInWithGoogle(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                ConditionalImageWidget(imagePath: "assets/images/google_icon.png"),
                const SizedBox(width: 10),
                const Text("Sign in with Google",
                    style: TextStyle(fontSize: 18, color: Colors.black)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
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
                ConditionalImageWidget(imagePath: "assets/images/github_icon.png"),
                const SizedBox(width: 10),
                const Text("Sign in with GitHub",
                    style: TextStyle(fontSize: 18, color: Colors.black)),
              ],
            ),
          ),
        ),
        // const SizedBox(height: 20),
        // SizedBox(
        //   width: double.infinity,
        //   child: OutlinedButton(
        //     onPressed: () {}, // ❌ No implementation for Facebook
        //     style: OutlinedButton.styleFrom(
        //       padding: const EdgeInsets.symmetric(vertical: 15),
        //       shape: RoundedRectangleBorder(
        //         borderRadius: BorderRadius.circular(10),
        //       ),
        //       side: const BorderSide(color: Colors.grey),
        //     ),
        //     child: Row(
        //       mainAxisAlignment: MainAxisAlignment.center,
        //       children: [
        //         ConditionalImageWidget(imagePath: "assets/images/facebook_icon.png"),
        //         const SizedBox(width: 10),
        //         const Text("Sign in with Facebook",
        //             style: TextStyle(fontSize: 18, color: Colors.black)),
        //       ],
        //     ),
        //   ),
        // ),
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
