// agendar_cita_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgendarCitaPage extends StatefulWidget {
  final String? docId;
  const AgendarCitaPage({super.key, this.docId});

  @override
  State<AgendarCitaPage> createState() => _AgendarCitaPageState();
}

class _AgendarCitaPageState extends State<AgendarCitaPage> {
  final FirebaseService _service = FirebaseService();
  final user = FirebaseAuth.instance.currentUser;

  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  String motivo = '';
  String idMedico = '';
  bool _cargando = false;

  final List<String> especialistas = [
    'Cardiólogo',
    'Dermatólogo',
    'Ginecólogo',
    'Pediatra',
    'Psicólogo',
  ];

  // Controlador para el TextField
  final TextEditingController _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.docId != null) _cargarCitaExistente();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarCitaExistente() async {
    setState(() => _cargando = true);
    final data = await _service.obtenerCitaPorId(widget.docId!);
    if (data != null) {
      // 🔹 Compatibilidad si el campo se llama 'fecha' en lugar de 'fecha_hora'
      final dynamic fechaField = data['fecha_hora'] ?? data['fecha'];
      final fechaHora = (fechaField is Timestamp)
          ? fechaField.toDate()
          : DateTime.now();

      setState(() {
        fechaSeleccionada = fechaHora;
        horaSeleccionada = TimeOfDay(hour: fechaHora.hour, minute: fechaHora.minute);
        motivo = data['motivo'] ?? '';
        idMedico = data['id_medico'] ?? especialistas.first;
        _motivoController.text = motivo;
      });
    }
    setState(() => _cargando = false);
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) setState(() => fechaSeleccionada = picked);
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: horaSeleccionada ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => horaSeleccionada = picked);
  }

  // Obtener nombre del usuario actual
  Future<String> _obtenerNombreUsuario() async {
    final usuario = await _service.obtenerUsuarioActual();
    return usuario?['nombre'] ?? user?.email?.split('@').first ?? 'Usuario';
  }

  Future<void> _guardar() async {
    if (fechaSeleccionada == null || horaSeleccionada == null || idMedico.isEmpty || motivo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todos los campos'))
      );
      return;
    }

    setState(() => _cargando = true);

    final fechaHora = DateTime(
      fechaSeleccionada!.year,
      fechaSeleccionada!.month,
      fechaSeleccionada!.day,
      horaSeleccionada!.hour,
      horaSeleccionada!.minute,
    );

    try {
      final nombrePaciente = await _obtenerNombreUsuario();
      final nombreMedico = 'Dr. $idMedico'; // Puedes personalizar esto

      if (widget.docId == null) {
        // Crear nueva cita
        await _service.crearCita(
          idMedico: idMedico,
          fechaHora: fechaHora,
          motivo: motivo.trim(),
          nombrePaciente: nombrePaciente,
          nombreMedico: nombreMedico,
        );
      } else {
        // Actualizar cita existente
        await _service.actualizarCita(
          docId: widget.docId!,
          fechaHora: fechaHora,
          motivo: motivo.trim(),
          idMedico: idMedico,
          nombreMedico: nombreMedico,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita guardada correctamente'),
              backgroundColor: Colors.green,
            )
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            )
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.docId == null ? 'Agendar Cita' : 'Editar Cita'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de Especialista
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Especialista',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: idMedico.isEmpty ? especialistas.first : idMedico,
                        items: especialistas.map((especialidad) =>
                            DropdownMenuItem(
                              value: especialidad,
                              child: Text(especialidad),
                            )).toList(),
                        onChanged: (value) => setState(() => idMedico = value ?? especialistas.first),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Selector de Fecha y Hora
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha y Hora',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Botón para seleccionar fecha
                      ElevatedButton(
                        onPressed: _seleccionarFecha,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(
                              fechaSeleccionada == null
                                  ? 'Seleccionar fecha'
                                  : '${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botón para seleccionar hora
                      ElevatedButton(
                        onPressed: _seleccionarHora,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.teal,
                          side: const BorderSide(color: Colors.teal),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time),
                            const SizedBox(width: 8),
                            Text(
                              horaSeleccionada == null
                                  ? 'Seleccionar hora'
                                  : horaSeleccionada!.format(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Campo de Motivo
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Motivo de la Consulta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _motivoController,
                        onChanged: (value) => motivo = value,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Describe el motivo de tu consulta...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botón Guardar
              ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _cargando
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  widget.docId == null ? 'Agendar Cita' : 'Guardar Cambios',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              // Botón Cancelar
              if (widget.docId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}