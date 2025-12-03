import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'agendar_cita.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  final FirebaseService _service = FirebaseService();
  final user = FirebaseAuth.instance.currentUser;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Mis Citas'),
        backgroundColor: CupertinoColors.systemTeal,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.add_circled_solid,
            color: CupertinoColors.white,
            size: 28,
          ),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const AgendarCitaPage()),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header del calendario
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatearMesAnio(_focusedDay),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.calendar_today,
                      color: CupertinoColors.systemTeal,
                    ),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                    },
                  ),
                ],
              ),
            ),

            // Selector de día
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _seleccionarDia,
                      child: Text(
                        _selectedDay == null
                            ? 'Seleccionar día'
                            : 'Día: ${_formatearFecha(_selectedDay!)}',
                        style: const TextStyle(
                          color: CupertinoColors.systemTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedDay != null) ...[
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: CupertinoColors.systemRed,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedDay = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Lista de citas - MODIFICADO: Solo citas del usuario
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: user != null ? _service.obtenerCitasDelUsuarioStream(user!.uid) : null,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CupertinoActivityIndicator(radius: 20),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              color: CupertinoColors.systemRed,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: ${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            CupertinoButton.filled(
                              onPressed: () => setState(() {}),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 64,
                            color: CupertinoColors.systemGrey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No tienes citas programadas',
                            style: TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final citas = snapshot.data!.docs;
                  final citasFiltradas = _selectedDay == null
                      ? citas
                      : _filtrarCitasPorDia(citas, _selectedDay!);

                  if (citasFiltradas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.calendar_badge_minus,
                            size: 64,
                            color: CupertinoColors.systemGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDay == null
                                ? 'No tienes citas programadas'
                                : 'No tienes citas para el ${_formatearFecha(_selectedDay!)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: citasFiltradas.length,
                    itemBuilder: (context, index) {
                      final doc = citasFiltradas[index];
                      final cita = doc.data() as Map<String, dynamic>;
                      final fecha = (cita['fecha'] as Timestamp).toDate();
                      final docId = doc.id;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemGrey.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _mostrarDetallesCita(cita, fecha),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Avatar con hora
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _getColorEspecialidad(cita['id_medico'])
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.clock_fill,
                                        size: 20,
                                        color: _getColorEspecialidad(cita['id_medico']),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getColorEspecialidad(cita['id_medico']),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Información de la cita - MODIFICADO: Muestra nombre_medico
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cita['nombre_medico'] ?? 'Dr. No especificado',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: CupertinoColors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Motivo: ${cita['motivo'] ?? 'Consulta'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${_formatearFecha(fecha)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: CupertinoColors.systemGrey2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Estado
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getColorEstado(cita['estado'])
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    cita['estado'] ?? 'pendiente',
                                    style: TextStyle(
                                      color: _getColorEstado(cita['estado']),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarDia() async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: const Border(
                  bottom: BorderSide(
                    color: CupertinoColors.systemGrey4,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Seleccionar Fecha',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Confirmar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDay ?? DateTime.now(),
                minimumDate: DateTime.now(),
                maximumDate: DateTime(DateTime.now().year + 1),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDay = newDate;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Object?>> _filtrarCitasPorDia(
      List<QueryDocumentSnapshot<Object?>> citas, DateTime dia) {
    return citas.where((citaDoc) {
      final cita = citaDoc.data() as Map<String, dynamic>;
      final fecha = (cita['fecha'] as Timestamp).toDate();
      return fecha.year == dia.year &&
          fecha.month == dia.month &&
          fecha.day == dia.day;
    }).toList();
  }

  void _mostrarDetallesCita(Map<String, dynamic> cita, DateTime fecha) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Detalles de la Cita'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoItem('Médico:', cita['nombre_medico'] ?? 'Dr. No especificado'),
              _buildInfoItem('Paciente:', cita['nombre_paciente'] ?? 'Usuario'),
              _buildInfoItem('Fecha:', _formatearFecha(fecha)),
              _buildInfoItem('Hora:', _formatearHora(fecha)),
              _buildInfoItem('Motivo:', cita['motivo']),
              _buildInfoItem('Estado:', cita['estado'] ?? 'pendiente'),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
      case 'confirmada':
        return CupertinoColors.systemGreen;
      case 'pendiente':
        return CupertinoColors.systemOrange;
      case 'cancelada':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  Color _getColorEspecialidad(String? especialidad) {
    final colores = {
      'Cardiólogo': CupertinoColors.systemRed,
      'Dermatólogo': CupertinoColors.systemBlue,
      'Ginecólogo': CupertinoColors.systemPink,
      'Pediatra': CupertinoColors.systemGreen,
      'Psicólogo': CupertinoColors.systemPurple,
    };
    return colores[especialidad] ?? CupertinoColors.systemTeal;
  }

  String _formatearMesAnio(DateTime fecha) {
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _formatearHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatearFechaHora(DateTime fecha) {
    return '${_formatearFecha(fecha)} ${_formatearHora(fecha)}';
  }
}