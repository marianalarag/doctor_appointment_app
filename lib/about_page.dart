import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sobre nosotros"),
        backgroundColor: Colors.teal,
      ),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "Doctor Appointment App es una plataforma diseñada para facilitar "
              "la gestión de citas médicas y el acceso a consejos de salud. "
              "Nuestro objetivo es conectar pacientes con especialistas de manera rápida, "
              "segura y eficiente.",
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
