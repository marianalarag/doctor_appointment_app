import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== CREAR CITA ==========
  Future<String> crearCita({
    required String idMedico,
    required DateTime fechaHora,
    required String motivo,
    required String nombrePaciente,
    required String nombreMedico,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final docRef = await _firestore.collection('citas').add({
          'id_paciente': user.uid,
          'id_medico': idMedico,
          'nombre_medico': nombreMedico,
          'nombre_paciente': nombrePaciente,
          'motivo': motivo,
          'fecha': Timestamp.fromDate(fechaHora),
          'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
          'estado': 'pendiente',
          'created_at': FieldValue.serverTimestamp(),
        });

        return docRef.id;
      } catch (e) {
        print('Error creando cita: $e');
        throw Exception('Error al crear la cita: $e');
      }
    }
    throw Exception('Usuario no autenticado');
  }

  // ========== ACTUALIZAR CITA ==========
  Future<void> actualizarCita({
    required String docId,
    required DateTime fechaHora,
    required String motivo,
    required String idMedico,
    required String nombreMedico,
  }) async {
    try {
      await _firestore.collection('citas').doc(docId).update({
        'fecha': Timestamp.fromDate(fechaHora),
        'motivo': motivo,
        'id_medico': idMedico,
        'nombre_medico': nombreMedico,
        'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error actualizando cita: $e');
      throw Exception('Error al actualizar la cita: $e');
    }
  }

  // ========== ELIMINAR CITA ==========
  Future<void> eliminarCita({required String docId}) async {
    try {
      await _firestore.collection('citas').doc(docId).delete();
    } catch (e) {
      print('Error eliminando cita: $e');
      throw Exception('Error al eliminar la cita: $e');
    }
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

        // Si no existe el documento de usuario, crear uno básico
        final userData = {
          'nombre': user.email?.split('@').first ?? 'Usuario',
          'email': user.email ?? '',
          'telefono': '',
          'historial_medico': '',
          'role': 'patient', // Rol por defecto
          'uid': user.uid,
          'created_at': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('usuarios').doc(user.uid).set(userData);
        return userData;
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
    String role = 'patient',
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'historial_medico': historialMedico,
        'role': role,
        'uid': user.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ========== MÉTODO OBTENER MÉDICOS ACTUALIZADO ==========
  Future<List<Map<String, dynamic>>> obtenerMedicos() async {
    try {
      final snapshot = await _firestore.collection('medicos').get();

      if (snapshot.docs.isEmpty) {
        // Si no hay médicos, también verificar en la colección usuarios con rol doctor
        final usuariosSnapshot = await _firestore
            .collection('usuarios')
            .where('role', isEqualTo: 'doctor')
            .get();

        if (usuariosSnapshot.docs.isEmpty) {
          return []; // Retornar lista vacía si no hay médicos
        }

        // Convertir usuarios doctores a formato médico
        return usuariosSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'nombre': data['nombre'] ?? 'Dr. ' + (data['email']?.split('@').first ?? 'Médico'),
            'especialidad': data['especialidad'] ?? 'General',
            'doc_id': doc.id,
            'email': data['email'] ?? '',
            'telefono': data['telefono'] ?? '',
            'disponible': data['disponible'] ?? true,
          };
        }).toList();
      }

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
      return []; // Retornar lista vacía en caso de error
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

  // ========== MÉTODOS ESPECÍFICOS PARA MÉDICOS ==========

  // Obtener citas del médico con información del paciente
  Stream<List<Map<String, dynamic>>> obtenerCitasMedicoConPacientes(String doctorId) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .orderBy('fecha', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final citasConPacientes = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final citaData = doc.data() as Map<String, dynamic>;
        final pacienteId = citaData['id_paciente'];

        // Obtener información del paciente
        final pacienteDoc = await _firestore.collection('usuarios').doc(pacienteId).get();
        final pacienteData = pacienteDoc.data();

        final citaCompleta = {
          ...citaData,
          'doc_id': doc.id,
          'paciente_nombre': pacienteData?['nombre'] ?? 'Paciente',
          'paciente_telefono': pacienteData?['telefono'] ?? '',
          'paciente_email': pacienteData?['email'] ?? '',
        };

        citasConPacientes.add(citaCompleta);
      }

      return citasConPacientes;
    });
  }

  // Obtener pacientes únicos del médico
  Stream<List<Map<String, dynamic>>> obtenerPacientesDelMedico(String doctorId) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .snapshots()
        .asyncMap((snapshot) async {
      final pacientesMap = <String, Map<String, dynamic>>{};
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final citaData = doc.data() as Map<String, dynamic>;
        final pacienteId = citaData['id_paciente'];

        if (!pacientesMap.containsKey(pacienteId)) {
          // Obtener información completa del paciente
          final pacienteDoc = await _firestore.collection('usuarios').doc(pacienteId).get();
          final pacienteData = pacienteDoc.data();

          if (pacienteData != null) {
            // Contar citas del paciente
            final citasPaciente = snapshot.docs
                .where((d) => (d.data() as Map<String, dynamic>)['id_paciente'] == pacienteId)
                .length;

            // Contar citas pendientes
            final citasPendientes = snapshot.docs
                .where((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['id_paciente'] == pacienteId &&
                  data['estado'] == 'pendiente' &&
                  (data['fecha'] as Timestamp).toDate().isAfter(now);
            })
                .length;

            pacientesMap[pacienteId] = {
              ...pacienteData,
              'total_citas': citasPaciente,
              'citas_pendientes': citasPendientes,
              'ultima_cita': _obtenerUltimaCita(snapshot.docs, pacienteId),
            };
          }
        }
      }

      return pacientesMap.values.toList();
    });
  }

  // Método auxiliar para obtener última cita
  String _obtenerUltimaCita(List<QueryDocumentSnapshot> docs, String pacienteId) {
    final citasPaciente = docs
        .where((doc) => (doc.data() as Map<String, dynamic>)['id_paciente'] == pacienteId)
        .toList();

    if (citasPaciente.isEmpty) return 'Nunca';

    citasPaciente.sort((a, b) {
      final fechaA = (a.data() as Map<String, dynamic>)['fecha'] as Timestamp;
      final fechaB = (b.data() as Map<String, dynamic>)['fecha'] as Timestamp;
      return fechaB.compareTo(fechaA);
    });

    final ultimaCita = (citasPaciente.first.data() as Map<String, dynamic>)['fecha'] as Timestamp;
    return _formatearFecha(ultimaCita.toDate());
  }

  String _formatearFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  // Cambiar estado de cita como médico
  Future<void> cambiarEstadoCitaMedico({
    required String docId,
    required String estado,
    String? observaciones,
  }) async {
    await _firestore.collection('citas').doc(docId).update({
      'estado': estado,
      'observaciones_medico': observaciones ?? '',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Obtener estadísticas rápidas para el médico
  Stream<Map<String, dynamic>> obtenerEstadisticasMedico(String doctorId) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .snapshots()
        .asyncMap((snapshot) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final citas = snapshot.docs;

      // Estadísticas básicas
      final totalCitas = citas.length;
      final citasHoy = citas.where((doc) {
        final fecha = (doc.data() as Map<String, dynamic>)['fecha'] as Timestamp;
        final fechaCita = DateTime(fecha.toDate().year, fecha.toDate().month, fecha.toDate().day);
        return fechaCita == today;
      }).length;

      final citasPendientes = citas.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['estado'] == 'pendiente' &&
            (data['fecha'] as Timestamp).toDate().isAfter(now);
      }).length;

      // Pacientes únicos
      final pacientesUnicos = citas
          .map((doc) => (doc.data() as Map<String, dynamic>)['id_paciente'])
          .toSet()
          .length;

      return {
        'totalCitas': totalCitas,
        'citasHoy': citasHoy,
        'citasPendientes': citasPendientes,
        'totalPacientes': pacientesUnicos,
      };
    });
  }

  // ========== MÉTODOS PARA DASHBOARD ==========

  // Obtener estadísticas para el dashboard médico
  Stream<Map<String, int>> obtenerEstadisticasDashboard(String doctorId) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final appointments = snapshot.docs;

      final totalAppointments = appointments.length;
      final pendingAppointments = appointments
          .where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['estado'] ?? 'pendiente';
        final fecha = data['fecha'];
        if (fecha is Timestamp) {
          final appointmentDate = fecha.toDate();
          return status == 'pendiente' && appointmentDate.isAfter(now);
        }
        return false;
      })
          .length;

      final uniquePatients = appointments
          .map((doc) => (doc.data() as Map<String, dynamic>)['id_paciente'])
          .toSet()
          .length;

      final today = DateTime(now.year, now.month, now.day);
      final todayAppointments = appointments
          .where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final fecha = data['fecha'];
        if (fecha is Timestamp) {
          final appointmentDate = fecha.toDate();
          final appointmentDay = DateTime(
              appointmentDate.year,
              appointmentDate.month,
              appointmentDate.day
          );
          return appointmentDay == today;
        }
        return false;
      })
          .length;

      return {
        'totalCitas': totalAppointments,
        'citasPendientes': pendingAppointments,
        'totalPacientes': uniquePatients,
        'citasHoy': todayAppointments,
      };
    });
  }

  // Actualizar rol de usuario
  Future<void> actualizarRolUsuario(String role) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .update({'role': role});
    }
  }

  // Obtener rol del usuario actual
  Future<String> obtenerRolUsuarioActual() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] ?? 'patient';
      }
    }
    return 'patient';
  }

  // Obtener citas recientes para el dashboard
  Stream<List<Map<String, dynamic>>> obtenerCitasRecientesMedico(String doctorId, {int limit = 5}) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .orderBy('fecha', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> citaData;
        if (data is Map<String, dynamic>) {
          citaData = Map<String, dynamic>.from(data);
        } else {
          citaData = Map<String, dynamic>.from(data as Map);
        }
        citaData['doc_id'] = doc.id;
        return citaData;
      }).toList();
    });
  }

  // Obtener información del médico para el dashboard
  Future<Map<String, dynamic>?> obtenerInfoMedico(String doctorId) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(doctorId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          return data is Map<String, dynamic>
              ? Map<String, dynamic>.from(data)
              : Map<String, dynamic>.from(data as Map);
        }
      }
      return null;
    } catch (e) {
      print('Error obteniendo info médico: $e');
      return null;
    }
  }

  // ========== MÉTODOS ADICIONALES ÚTILES ==========

  // Verificar si un usuario es médico
  Future<bool> esUsuarioMedico() async {
    final role = await obtenerRolUsuarioActual();
    return role == 'doctor';
  }

  // Obtener citas del día actual para un médico
  Stream<List<Map<String, dynamic>>> obtenerCitasHoyMedico(String doctorId) {
    final now = DateTime.now();
    final inicioDia = DateTime(now.year, now.month, now.day);
    final finDia = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
        .orderBy('fecha')
        .snapshots()
        .map((snapshot) {
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
    });
  }

  // Obtener total de citas por estado para un médico
  Future<Map<String, int>> obtenerConteoCitasPorEstado(String doctorId) async {
    try {
      final snapshot = await _firestore
          .collection('citas')
          .where('id_medico', isEqualTo: doctorId)
          .get();

      final conteo = {
        'pendiente': 0,
        'confirmada': 0,
        'completada': 0,
        'cancelada': 0,
        'total': snapshot.docs.length,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final estado = data['estado'] ?? 'pendiente';
        if (conteo.containsKey(estado)) {
          conteo[estado] = (conteo[estado] ?? 0) + 1;
        }
      }

      return conteo;
    } catch (e) {
      print('Error obteniendo conteo de citas: $e');
      return {
        'pendiente': 0,
        'confirmada': 0,
        'completada': 0,
        'cancelada': 0,
        'total': 0,
      };
    }
  }
}