// agendar_cita_page.dart - VERSIÓN CORREGIDA
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
    // Inicializar con el primer especialista
    if (idMedico.isEmpty) {
      idMedico = especialistas.first;
    }
    if (widget.docId != null) _cargarCitaExistente();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarCitaExistente() async {
    setState(() => _cargando = true);
    try {
      final data = await _service.obtenerCitaPorId(widget.docId!);
      if (data != null) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() => fechaSeleccionada = picked);
    }
  }

  Future<void> _seleccionarHora() async {
    if (fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primero selecciona una fecha'))
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: horaSeleccionada ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => horaSeleccionada = picked);
    }
  }

  // Obtener nombre del usuario actual
  Future<String> _obtenerNombreUsuario() async {
    try {
      final usuario = await _service.obtenerUsuarioActual();
      return usuario?['nombre'] ?? user?.email?.split('@').first ?? 'Usuario';
    } catch (e) {
      return user?.email?.split('@').first ?? 'Usuario';
    }
  }

  Future<void> _guardar() async {
    // Validaciones básicas
    if (fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una fecha'))
      );
      return;
    }

    if (horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una hora'))
      );
      return;
    }

    if (motivo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa el motivo de la consulta'))
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
      final nombreMedico = 'Dr. $idMedico';

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
        String mensajeError = 'Error al guardar la cita';

        // Mensajes más específicos según el tipo de error
        if (e.toString().contains('no autenticado')) {
          mensajeError = 'Usuario no autenticado. Por favor inicia sesión nuevamente.';
        } else if (e.toString().contains('network') || e.toString().contains('Internet')) {
          mensajeError = 'Error de conexión. Verifica tu internet e intenta nuevamente.';
        } else {
          mensajeError = 'Error: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeError),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            )
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'No seleccionada';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _formatearHora(TimeOfDay? hora) {
    if (hora == null) return 'No seleccionada';
    return '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
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

                      // Información de selección actual
                      if (fechaSeleccionada != null || horaSeleccionada != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selección actual:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: ${_formatearFecha(fechaSeleccionada)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Hora: ${_formatearHora(horaSeleccionada)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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
                                  : 'Cambiar fecha',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Botón para seleccionar hora
                      ElevatedButton(
                        onPressed: fechaSeleccionada == null ? null : _seleccionarHora,
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
                                  : 'Cambiar hora',
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
                      const SizedBox(height: 4),
                      Text(
                        '${motivo.length}/500 caracteres',
                        style: TextStyle(
                          fontSize: 12,
                          color: motivo.length > 400 ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botones de acción
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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

              // Información adicional
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Información importante',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Las citas tienen una duración de 30 minutos\n'
                          '• Puedes cancelar o modificar hasta 2 horas antes',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}