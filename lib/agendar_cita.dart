import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgendarCitaPage extends StatefulWidget {
  const AgendarCitaPage({super.key});

  @override
  State<AgendarCitaPage> createState() => _AgendarCitaPageState();
}

class _AgendarCitaPageState extends State<AgendarCitaPage> {
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  String motivo = '';
  String idMedico = '';
  String idPaciente = '';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📅 Seleccionar fecha
  Future<void> _seleccionarFecha() async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );
    if (seleccion != null) {
      setState(() => fechaSeleccionada = seleccion);
    }
  }

  // ⏰ Seleccionar hora
  Future<void> _seleccionarHora() async {
    final TimeOfDay? seleccion = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (seleccion != null) {
      setState(() => horaSeleccionada = seleccion);
    }
  }

  // 💾 Guardar cita en Firestore
  Future<void> _guardarCita() async {
    if (fechaSeleccionada == null || horaSeleccionada == null || motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    // Combina fecha y hora seleccionadas
    final DateTime fechaHoraFinal = DateTime(
      fechaSeleccionada!.year,
      fechaSeleccionada!.month,
      fechaSeleccionada!.day,
      horaSeleccionada!.hour,
      horaSeleccionada!.minute,
    );

    try {
      await _db.collection('citas').add({
        'fecha': Timestamp.fromDate(fechaSeleccionada!),
        'hora': '${horaSeleccionada!.hour}:${horaSeleccionada!.minute.toString().padLeft(2, '0')}',
        'motivo': motivo,
        'id_medico': idMedico,
        'id_paciente': idPaciente,
        'estado': 'pendiente',
        'fecha_hora': Timestamp.fromDate(fechaHoraFinal),
      });

      // Cierra la ventana al guardar
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita agendada correctamente')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la cita: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Cita'),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona la fecha y hora de tu cita',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Botón seleccionar fecha
              ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                onPressed: _seleccionarFecha,
                label: Text(
                  fechaSeleccionada == null
                      ? 'Seleccionar fecha'
                      : 'Fecha: ${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}',
                ),
              ),
              const SizedBox(height: 10),

              // Botón seleccionar hora
              ElevatedButton.icon(
                icon: const Icon(Icons.access_time),
                onPressed: _seleccionarHora,
                label: Text(
                  horaSeleccionada == null
                      ? 'Seleccionar hora'
                      : 'Hora: ${horaSeleccionada!.format(context)}',
                ),
              ),
              const SizedBox(height: 20),

              // Campo motivo
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Motivo de la cita',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => motivo = value,
              ),
              const SizedBox(height: 20),

              // Botón guardar
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: _guardarCita,
                  child: const Text(
                    'Agendar',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
