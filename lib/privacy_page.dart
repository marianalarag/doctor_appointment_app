import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacidad"),
        backgroundColor: Colors.teal,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "En esta aplicación, respetamos tu privacidad. "
              "La información personal que proporciones será utilizada únicamente "
              "para agendar tus citas y mejorar tu experiencia. "
              "No compartimos tus datos con terceros sin tu consentimiento.",
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
