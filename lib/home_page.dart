import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'messages_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  final List<String> especialistas = [
    'Cardiólogo',
    'Dermatólogo',
    'Ginecólogo',
    'Pediatra',
    'Psicólogo',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Inicio"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Mensajes"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Configuración"),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 1:
        return const MessagesPage();
      case 2:
        return const SettingsPage();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "¡Hola, ${user?.email ?? "Usuario"}!",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 20),

          // Botones principales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Agendar Cita"),
                  onPressed: () => _abrirFormularioCita(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text("Consejos Médicos"),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Consejos Médicos"),
                        content: const Text(
                          "• Bebe suficiente agua\n"
                              "• Duerme bien\n"
                              "• Haz ejercicio ligero\n"
                              "• Consulta a un especialista si el dolor persiste.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cerrar"),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Especialistas
          const Text(
            "Especialistas",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: especialistas.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Especialista seleccionado: ${especialistas[index]}'),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        especialistas[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),

          // Tips rápidos
          const Text(
            "Tips rápidos",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "• Mantente hidratado\n"
                  "• Descansa adecuadamente\n"
                  "• Realiza actividad física ligera\n"
                  "• Evita el estrés prolongado",
              style: TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 30),

          // Próximas citas
          const Text(
            "Próximas Citas",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('citas')
                .where('id_paciente', isEqualTo: user?.uid ?? '')
                .orderBy('fecha', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text("No tienes citas próximas.");
              }

              final citas = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: citas.length,
                itemBuilder: (context, index) {
                  final cita = citas[index].data() as Map<String, dynamic>;
                  final fecha = (cita['fecha'] as Timestamp).toDate();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text("Especialista: ${cita['id_medico']}"),
                      subtitle: Text(
                        "Fecha: ${fecha.day}/${fecha.month}/${fecha.year} - Hora: ${cita['hora']}\nMotivo: ${cita['motivo']}",
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _abrirFormularioCita() {
    String especialistaSeleccionado = especialistas.first;
    DateTime? fechaSeleccionada;
    TimeOfDay? horaSeleccionada;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Agendar Cita"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: especialistaSeleccionado,
                items: especialistas
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setStateDialog(() => especialistaSeleccionado = value);
                },
                decoration: const InputDecoration(labelText: "Especialista"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2026),
                  );
                  if (picked != null) setStateDialog(() => fechaSeleccionada = picked);
                },
                child: Text(fechaSeleccionada == null
                    ? "Seleccionar fecha"
                    : "Fecha: ${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) setStateDialog(() => horaSeleccionada = picked);
                },
                child: Text(horaSeleccionada == null
                    ? "Seleccionar hora"
                    : "Hora: ${horaSeleccionada!.format(context)}"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fechaSeleccionada == null || horaSeleccionada == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Completa todos los campos antes de continuar')),
                  );
                  return;
                }

                await FirebaseFirestore.instance.collection('citas').add({
                  'id_paciente': user?.uid ?? '',
                  'id_medico': especialistaSeleccionado,
                  'motivo': 'Consulta general',
                  'fecha': Timestamp.fromDate(fechaSeleccionada!),
                  'hora': '${horaSeleccionada!.hour}:${horaSeleccionada!.minute.toString().padLeft(2, '0')}',
                  'estado': 'pendiente',
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cita agendada con $especialistaSeleccionado')),
                  );
                  // El StreamBuilder se actualiza automáticamente, no se necesita setState
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text("Agendar"),
            ),
          ],
        ),
      ),
    );
  }
}
