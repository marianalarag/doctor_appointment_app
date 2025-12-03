import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgendarCitaPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? doctorSeleccionado;

  const AgendarCitaPage({
    super.key,
    this.docId,
    this.doctorSeleccionado,
  });

  @override
  State<AgendarCitaPage> createState() => _AgendarCitaPageState();
}

class _AgendarCitaPageState extends State<AgendarCitaPage> {
  final FirebaseService _service = FirebaseService();
  final User? user = FirebaseAuth.instance.currentUser;

  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  String motivo = '';
  String idMedico = '';
  String nombreMedico = '';
  bool _cargando = false;
  bool _validando = false;
  String? _errorDisponibilidad;
  List<Map<String, dynamic>> _doctoresDisponibles = [];

  final TextEditingController _motivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDoctoresDisponibles();

    if (widget.doctorSeleccionado != null) {
      idMedico = widget.doctorSeleccionado!['doc_id'] ?? '';
      nombreMedico = widget.doctorSeleccionado!['nombre'] ?? '';
    }

    if (widget.docId != null) _cargarCitaExistente();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDoctoresDisponibles() async {
    try {
      final doctores = await _service.obtenerMedicos();
      if (mounted) {
        setState(() {
          _doctoresDisponibles = doctores;

          if (idMedico.isEmpty && _doctoresDisponibles.isNotEmpty) {
            idMedico = _doctoresDisponibles.first['doc_id'] ?? '';
            nombreMedico = _doctoresDisponibles.first['nombre'] ?? '';
          }
        });
      }
    } catch (e) {
      print('Error cargando doctores: $e');
    }
  }

  Future<void> _cargarCitaExistente() async {
    if (!mounted) return;

    setState(() => _cargando = true);
    try {
      final data = await _service.obtenerCitaPorId(widget.docId!);
      if (data != null && mounted) {
        final dynamic fechaField = data['fecha_hora'] ?? data['fecha'];
        final fechaHora = (fechaField is Timestamp)
            ? fechaField.toDate()
            : DateTime.now();

        setState(() {
          fechaSeleccionada = fechaHora;
          horaSeleccionada = TimeOfDay(hour: fechaHora.hour, minute: fechaHora.minute);
          motivo = data['motivo'] ?? '';
          idMedico = data['id_medico'] ?? '';
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
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _validarDisponibilidad() async {
    if (fechaSeleccionada == null || horaSeleccionada == null || idMedico.isEmpty) {
      return;
    }

    setState(() {
      _validando = true;
      _errorDisponibilidad = null;
    });

    try {
      final fechaHora = DateTime(
        fechaSeleccionada!.year,
        fechaSeleccionada!.month,
        fechaSeleccionada!.day,
        horaSeleccionada!.hour,
        horaSeleccionada!.minute,
      );

      final disponible = await _service.validarDisponibilidad(
        idMedico: idMedico,
        fechaHora: fechaHora,
        citaIdExcluir: widget.docId,
      );

      if (!disponible) {
        setState(() {
          _errorDisponibilidad = '⚠️ El médico no está disponible en este horario';
        });
      } else {
        setState(() {
          _errorDisponibilidad = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorDisponibilidad = 'Error validando disponibilidad: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _validando = false);
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        fechaSeleccionada = picked;
        _errorDisponibilidad = null;
      });
      _validarDisponibilidad();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        horaSeleccionada = picked;
        _errorDisponibilidad = null;
      });
      _validarDisponibilidad();
    }
  }

  Future<String> _obtenerNombreUsuario() async {
    try {
      final usuario = await _service.obtenerUsuarioActual();
      return usuario?['nombre'] ?? user?.email?.split('@').first ?? 'Usuario';
    } catch (e) {
      return user?.email?.split('@').first ?? 'Usuario';
    }
  }

  Future<void> _guardar() async {
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

    if (idMedico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un médico'))
      );
      return;
    }

    // Validar disponibilidad final antes de guardar
    setState(() => _validando = true);
    try {
      final fechaHora = DateTime(
        fechaSeleccionada!.year,
        fechaSeleccionada!.month,
        fechaSeleccionada!.day,
        horaSeleccionada!.hour,
        horaSeleccionada!.minute,
      );

      final disponible = await _service.validarDisponibilidad(
        idMedico: idMedico,
        fechaHora: fechaHora,
        citaIdExcluir: widget.docId,
      );

      if (!disponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El médico ya tiene una cita en este horario'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error validando disponibilidad: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } finally {
      setState(() => _validando = false);
    }

    if (!mounted) return;
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

      final doctorSeleccionado = _doctoresDisponibles.firstWhere(
            (doctor) => doctor['doc_id'] == idMedico,
        orElse: () => {'nombre': 'Médico', 'especialidad': 'General'},
      );
      final nombreMedicoReal = doctorSeleccionado['nombre'] ?? 'Médico';

      if (widget.docId == null) {
        await _service.crearCita(
          idMedico: idMedico,
          fechaHora: fechaHora,
          motivo: motivo.trim(),
          nombrePaciente: nombrePaciente,
          nombreMedico: nombreMedicoReal, // <-- Esto guarda el nombre
        );
      } else {
        await _service.actualizarCita(
          docId: widget.docId!,
          fechaHora: fechaHora,
          motivo: motivo.trim(),
          idMedico: idMedico,
          nombreMedico: nombreMedicoReal, // <-- Esto guarda el nombre
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita guardada correctamente'),
              backgroundColor: Colors.green,
            )
        );
        Navigator.pop(context, true); // Devuelve true para indicar éxito
      }
    } catch (e) {
      if (mounted) {
        String mensajeError = 'Error al guardar la cita';

        if (e.toString().contains('no disponible')) {
          mensajeError = 'El médico no está disponible en ese horario';
        } else if (e.toString().contains('no autenticado')) {
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
              // Selector de Médico
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Médico',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (widget.doctorSeleccionado != null) ...[
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 80,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.teal),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.medical_services, color: Colors.teal, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.doctorSeleccionado!['nombre'] ?? 'Médico',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.doctorSeleccionado!['especialidad'] ?? 'Especialista',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal.withOpacity(0.8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle, color: Colors.teal, size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '¿Quieres cambiar de médico?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],

                      _doctoresDisponibles.isEmpty
                          ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Center(
                          child: Text(
                            'No hay médicos disponibles',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                          : DropdownButtonFormField<String>(
                        value: idMedico.isEmpty ? null : idMedico,
                        items: _doctoresDisponibles.map((doctor) {
                          final nombre = doctor['nombre'] ?? 'Médico';
                          final especialidad = doctor['especialidad'] ?? 'General';
                          final docId = doctor['doc_id'] ?? '';

                          return DropdownMenuItem<String>(
                            value: docId,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                '$nombre - $especialidad',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            idMedico = value ?? '';
                            _errorDisponibilidad = null;
                          });
                          if (fechaSeleccionada != null && horaSeleccionada != null) {
                            _validarDisponibilidad();
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          hintText: 'Selecciona un médico',
                        ),
                        isExpanded: true,
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
                    mainAxisSize: MainAxisSize.min,
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

                      // Mensaje de disponibilidad
                      if (_errorDisponibilidad != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorDisponibilidad!,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Selección actual:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: ${_formatearFecha(fechaSeleccionada)}',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Hora: ${_formatearHora(horaSeleccionada)}',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _seleccionarFecha,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today),
                              SizedBox(width: 8),
                              Text('Seleccionar fecha'),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: fechaSeleccionada == null ? null : _seleccionarHora,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time),
                              SizedBox(width: 8),
                              Text('Seleccionar hora'),
                            ],
                          ),
                        ),
                      ),

                      // Indicador de validación
                      if (_validando) ...[
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Validando disponibilidad...',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
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
                    mainAxisSize: MainAxisSize.min,
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
                        maxLength: 500,
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
                  if (_errorDisponibilidad != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No puedes agendar en este horario porque el médico ya tiene una cita programada',
                              style: TextStyle(color: Colors.orange, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_cargando || _validando || _errorDisponibilidad != null)
                          ? null
                          : _guardar,
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
                  ),

                  if (widget.docId != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
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
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Información adicional
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Información importante',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Las citas tienen una duración de 30 minutos\n'
                          '• No puedes agendar en horarios ocupados por el mismo médico\n'
                          '• Puedes cancelar o modificar hasta 2 horas antes\n'
                          '• Llega 10 minutos antes de tu cita',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
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