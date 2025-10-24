import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== MÉTODOS DE DISPONIBILIDAD ==========

  // Verificar disponibilidad del médico
  Future<bool> verificarDisponibilidadMedico({
    required String idMedico,
    required DateTime fechaHora,
  }) async {
    try {
      final fecha = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
      final horaInicio = DateTime(fechaHora.year, fechaHora.month, fechaHora.day, fechaHora.hour, fechaHora.minute);
      final horaFin = horaInicio.add(const Duration(minutes: 30)); // Duración de la cita

      final snapshot = await _firestore
          .collection('disponibilidad_medicos')
          .where('id_medico', isEqualTo: idMedico)
          .where('fecha', isEqualTo: Timestamp.fromDate(fecha))
          .where('disponibilidad', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> disponibilidadData;
          if (data is Map<String, dynamic>) {
            disponibilidadData = data;
          } else {
            disponibilidadData = Map<String, dynamic>.from(data as Map);
          }

          final horaInicioDisponible = (disponibilidadData['hora_inicio'] as Timestamp).toDate();
          final horaFinDisponible = (disponibilidadData['hora_fin'] as Timestamp).toDate();

          // Verificar si el horario solicitado está dentro de la disponibilidad
          if (horaInicio.isAfter(horaInicioDisponible.subtract(const Duration(minutes: 1))) &&
              horaFin.isBefore(horaFinDisponible.add(const Duration(minutes: 1)))) {
            return true; // Hay disponibilidad
          }
        }
      }
      return false; // No hay disponibilidad
    } catch (e) {
      print('Error verificando disponibilidad: $e');
      return false;
    }
  }

  // Obtener el ID de disponibilidad para una cita específica
  Future<String?> obtenerDisponibilidadId({
    required String idMedico,
    required DateTime fechaHora,
  }) async {
    try {
      final fecha = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
      final horaInicio = DateTime(fechaHora.year, fechaHora.month, fechaHora.day, fechaHora.hour, fechaHora.minute);
      final horaFin = horaInicio.add(const Duration(minutes: 30));

      final snapshot = await _firestore
          .collection('disponibilidad_medicos')
          .where('id_medico', isEqualTo: idMedico)
          .where('fecha', isEqualTo: Timestamp.fromDate(fecha))
          .where('disponibilidad', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> disponibilidadData;
          if (data is Map<String, dynamic>) {
            disponibilidadData = data;
          } else {
            disponibilidadData = Map<String, dynamic>.from(data as Map);
          }

          final horaInicioDisponible = (disponibilidadData['hora_inicio'] as Timestamp).toDate();
          final horaFinDisponible = (disponibilidadData['hora_fin'] as Timestamp).toDate();

          if (horaInicio.isAfter(horaInicioDisponible.subtract(const Duration(minutes: 1))) &&
              horaFin.isBefore(horaFinDisponible.add(const Duration(minutes: 1)))) {
            return doc.id; // Retornar el ID de la disponibilidad
          }
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo ID de disponibilidad: $e');
      return null;
    }
  }

  // ========== CREAR CITA CON VALIDACIÓN DE DISPONIBILIDAD ==========
  Future<String> crearCita({
    required String idMedico,
    required DateTime fechaHora,
    required String motivo,
    required String nombrePaciente,
    required String nombreMedico,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      // 1. Verificar disponibilidad
      final tieneDisponibilidad = await verificarDisponibilidadMedico(
        idMedico: idMedico,
        fechaHora: fechaHora,
      );

      if (!tieneDisponibilidad) {
        throw Exception('El médico no tiene disponibilidad en este horario');
      }

      // 2. Obtener el ID de la disponibilidad
      final disponibilidadId = await obtenerDisponibilidadId(
        idMedico: idMedico,
        fechaHora: fechaHora,
      );

      if (disponibilidadId == null) {
        throw Exception('No se pudo encontrar la disponibilidad del médico');
      }

      // 3. Crear la cita
      final docRef = await _firestore.collection('citas').add({
        'id_paciente': user.uid,
        'id_medico': idMedico,
        'nombre_medico': nombreMedico,
        'nombre_paciente': nombrePaciente,
        'motivo': motivo,
        'fecha': Timestamp.fromDate(fechaHora),
        'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
        'estado': 'pendiente',
        'disponibilidad_id': disponibilidadId, // Guardar referencia a la disponibilidad
        'created_at': FieldValue.serverTimestamp(),
      });

      // 4. Marcar la disponibilidad como ocupada
      await _firestore
          .collection('disponibilidad_medicos')
          .doc(disponibilidadId)
          .update({
        'disponibilidad': false,
        'cita_id': docRef.id, // Guardar referencia a la cita
      });

      return docRef.id;
    }
    throw Exception('Usuario no autenticado');
  }

  // ========== ACTUALIZAR CITA CON VALIDACIÓN ==========
  Future<void> actualizarCita({
    required String docId,
    required DateTime fechaHora,
    required String motivo,
    required String idMedico,
    required String nombreMedico,
  }) async {
    // 1. Obtener cita actual
    final citaActual = await obtenerCitaPorId(docId);
    if (citaActual == null) {
      throw Exception('Cita no encontrada');
    }

    // 2. Si cambió el médico o la fecha/hora, verificar disponibilidad
    final medicoCambio = citaActual['id_medico'] != idMedico;
    final fechaActual = (citaActual['fecha'] as Timestamp).toDate();
    final fechaCambio = fechaActual.year != fechaHora.year ||
        fechaActual.month != fechaHora.month ||
        fechaActual.day != fechaHora.day ||
        fechaActual.hour != fechaHora.hour ||
        fechaActual.minute != fechaHora.minute;

    if (medicoCambio || fechaCambio) {
      final tieneDisponibilidad = await verificarDisponibilidadMedico(
        idMedico: idMedico,
        fechaHora: fechaHora,
      );

      if (!tieneDisponibilidad) {
        throw Exception('El médico no tiene disponibilidad en este horario');
      }

      // 3. Liberar disponibilidad anterior si existe
      final disponibilidadAnteriorId = citaActual['disponibilidad_id'];
      if (disponibilidadAnteriorId != null) {
        await _firestore
            .collection('disponibilidad_medicos')
            .doc(disponibilidadAnteriorId as String)
            .update({
          'disponibilidad': true,
          'cita_id': FieldValue.delete(),
        });
      }

      // 4. Obtener nueva disponibilidad
      final nuevaDisponibilidadId = await obtenerDisponibilidadId(
        idMedico: idMedico,
        fechaHora: fechaHora,
      );

      if (nuevaDisponibilidadId == null) {
        throw Exception('No se pudo encontrar la disponibilidad del médico');
      }

      // 5. Actualizar cita con nueva disponibilidad
      await _firestore.collection('citas').doc(docId).update({
        'fecha': Timestamp.fromDate(fechaHora),
        'motivo': motivo,
        'id_medico': idMedico,
        'nombre_medico': nombreMedico,
        'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
        'disponibilidad_id': nuevaDisponibilidadId,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // 6. Marcar nueva disponibilidad como ocupada
      await _firestore
          .collection('disponibilidad_medicos')
          .doc(nuevaDisponibilidadId)
          .update({
        'disponibilidad': false,
        'cita_id': docId,
      });
    } else {
      // Solo actualizar motivo si no cambió médico ni fecha
      await _firestore.collection('citas').doc(docId).update({
        'motivo': motivo,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ========== ELIMINAR CITA (LIBERAR DISPONIBILIDAD) ==========
  Future<void> eliminarCita({required String docId}) async {
    // 1. Obtener cita para liberar disponibilidad
    final cita = await obtenerCitaPorId(docId);
    if (cita != null && cita['disponibilidad_id'] != null) {
      final disponibilidadId = cita['disponibilidad_id'] as String;

      // 2. Liberar disponibilidad
      await _firestore
          .collection('disponibilidad_medicos')
          .doc(disponibilidadId)
          .update({
        'disponibilidad': true,
        'cita_id': FieldValue.delete(),
      });
    }

    // 3. Eliminar cita
    await _firestore.collection('citas').doc(docId).delete();
  }

  // ========== MÉTODOS DE CONSULTA ==========

  // Obtener próximas citas del usuario
  Stream<List<Map<String, dynamic>>> obtenerProximasCitasUsuario(String uid) {
    return _firestore
        .collection('citas')
        .where('id_paciente', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final ahora = DateTime.now();
      final citasFuturas = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> citaData;
          if (data is Map<String, dynamic>) {
            citaData = Map<String, dynamic>.from(data);
          } else {
            citaData = Map<String, dynamic>.from(data as Map);
          }

          final fecha = citaData['fecha'];
          if (fecha is Timestamp) {
            final fechaCita = fecha.toDate();
            if (fechaCita.isAfter(ahora)) {
              citaData['doc_id'] = doc.id;
              citasFuturas.add(citaData);
            }
          }
        }
      }

      citasFuturas.sort((a, b) {
        final fechaA = a['fecha'] as Timestamp;
        final fechaB = b['fecha'] as Timestamp;
        return fechaA.compareTo(fechaB);
      });

      return citasFuturas;
    });
  }

  // Obtener todas las citas del usuario (Stream)
  Stream<QuerySnapshot> obtenerCitasDelUsuarioStream(String uid) {
    return _firestore
        .collection('citas')
        .where('id_paciente', isEqualTo: uid)
        .orderBy('fecha')
        .snapshots();
  }

  // Obtener todas las citas del sistema
  Stream<QuerySnapshot> obtenerTodasLasCitas() {
    return _firestore
        .collection('citas')
        .orderBy('fecha')
        .snapshots();
  }

  // Obtener horarios disponibles de un médico
  Future<List<Map<String, dynamic>>> obtenerHorariosDisponibles({
    required String idMedico,
    required DateTime fecha,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('disponibilidad_medicos')
          .where('id_medico', isEqualTo: idMedico)
          .where('fecha', isEqualTo: Timestamp.fromDate(fecha))
          .where('disponibilidad', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final Map<String, dynamic> disponibilidadData;
        if (data is Map<String, dynamic>) {
          disponibilidadData = Map<String, dynamic>.from(data);
        } else {
          disponibilidadData = Map<String, dynamic>.from(data as Map);
        }
        disponibilidadData['doc_id'] = doc.id;
        return disponibilidadData;
      }).toList();
    } catch (e) {
      print('Error obteniendo horarios disponibles: $e');
      return [];
    }
  }

  // Obtener cita por ID
  Future<Map<String, dynamic>?> obtenerCitaPorId(String docId) async {
    try {
      final doc = await _firestore.collection('citas').doc(docId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> dataMap;
          if (data is Map<String, dynamic>) {
            dataMap = Map<String, dynamic>.from(data);
          } else {
            dataMap = Map<String, dynamic>.from(data as Map);
          }
          dataMap['doc_id'] = doc.id;
          return dataMap;
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo cita por ID: $e');
      return null;
    }
  }

  // Obtener usuario actual
  Future<Map<String, dynamic>?> obtenerUsuarioActual() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('usuarios').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            return data is Map<String, dynamic>
                ? Map<String, dynamic>.from(data)
                : Map<String, dynamic>.from(data as Map);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo usuario actual: $e');
      return null;
    }
  }

  // ========== MÉTODOS ADICIONALES ==========

  // Crear usuario
  Future<void> crearUsuario({
    required String nombre,
    required String email,
    String telefono = '',
    String historialMedico = '',
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'historial_medico': historialMedico,
        'uid': user.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // Obtener médicos disponibles
  Future<List<Map<String, dynamic>>> obtenerMedicos() async {
    try {
      final snapshot = await _firestore.collection('medicos').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final Map<String, dynamic> medicoData;
        if (data is Map<String, dynamic>) {
          medicoData = Map<String, dynamic>.from(data);
        } else {
          medicoData = Map<String, dynamic>.from(data as Map);
        }
        medicoData['doc_id'] = doc.id;
        return medicoData;
      }).toList();
    } catch (e) {
      print('Error obteniendo médicos: $e');
      return [];
    }
  }

  // Cambiar estado de cita
  Future<void> cambiarEstadoCita({
    required String docId,
    required String estado,
  }) async {
    await _firestore.collection('citas').doc(docId).update({
      'estado': estado,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Obtener citas por médico
  Stream<QuerySnapshot> obtenerCitasPorMedicoStream(String idMedico) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: idMedico)
        .orderBy('fecha', descending: false)
        .snapshots();
  }

  // Obtener citas por fecha
  Future<List<Map<String, dynamic>>> obtenerCitasPorFecha(DateTime fecha) async {
    try {
      final inicioDia = DateTime(fecha.year, fecha.month, fecha.day);
      final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('citas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
          .orderBy('fecha')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final Map<String, dynamic> citaData;
        if (data is Map<String, dynamic>) {
          citaData = Map<String, dynamic>.from(data);
        } else {
          citaData = Map<String, dynamic>.from(data as Map);
        }
        citaData['doc_id'] = doc.id;
        return citaData;
      }).toList();
    } catch (e) {
      print('Error obteniendo citas por fecha: $e');
      return [];
    }
  }
}