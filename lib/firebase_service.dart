import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========== VALIDAR DISPONIBILIDAD ==========
  Future<bool> validarDisponibilidad({
    required String idMedico,
    required DateTime fechaHora,
    required String? citaIdExcluir, // Para cuando se edita una cita
  }) async {
    try {
      // Convertir a fecha y hora
      final inicioCita = fechaHora;
      final finCita = fechaHora.add(const Duration(minutes: 30)); // Duración de la cita

      // Consultar citas existentes para el médico en el mismo día
      final inicioDia = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
      final finDia = DateTime(fechaHora.year, fechaHora.month, fechaHora.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('citas')
          .where('id_medico', isEqualTo: idMedico)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
          .where('estado', whereIn: ['pendiente', 'confirmada'])
          .get();

      for (final doc in snapshot.docs) {
        // Excluir la cita actual si se está editando
        if (citaIdExcluir != null && doc.id == citaIdExcluir) {
          continue;
        }

        final citaData = doc.data();
        final fechaCitaExistente = (citaData['fecha'] as Timestamp).toDate();
        final finCitaExistente = fechaCitaExistente.add(const Duration(minutes: 30));

        // Verificar superposición de horarios
        if (inicioCita.isBefore(finCitaExistente) && finCita.isAfter(fechaCitaExistente)) {
          return false; // Hay conflicto
        }
      }

      return true; // Disponible
    } catch (e) {
      print('Error validando disponibilidad: $e');
      return false;
    }
  }

  // ========== CREAR CITA CON VALIDACIÓN ==========
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
        // Validar disponibilidad antes de crear
        final disponible = await validarDisponibilidad(
          idMedico: idMedico,
          fechaHora: fechaHora,
          citaIdExcluir: null,
        );

        if (!disponible) {
          throw Exception('El médico no está disponible en ese horario');
        }

        // Obtener el nombre real del médico
        String nombreDoctorReal = nombreMedico;
        try {
          final medicoDoc = await _firestore.collection('usuarios').doc(idMedico).get();
          if (medicoDoc.exists && medicoDoc.data()?['nombre'] != null) {
            nombreDoctorReal = medicoDoc.data()!['nombre'];
          }
        } catch (e) {
          print('Error obteniendo nombre del médico: $e');
        }

        final docRef = await _firestore.collection('citas').add({
          'id_paciente': user.uid,
          'id_medico': idMedico,
          'nombre_medico': nombreDoctorReal,
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

  // ========== ACTUALIZAR CITA CON VALIDACIÓN ==========
  Future<void> actualizarCita({
    required String docId,
    required DateTime fechaHora,
    required String motivo,
    required String idMedico,
    required String nombreMedico,
  }) async {
    try {
      // Validar disponibilidad (excluyendo la cita actual)
      final disponible = await validarDisponibilidad(
        idMedico: idMedico,
        fechaHora: fechaHora,
        citaIdExcluir: docId,
      );

      if (!disponible) {
        throw Exception('El médico no está disponible en ese horario');
      }

      // Obtener el nombre real del médico
      String nombreDoctorReal = nombreMedico;
      try {
        final medicoDoc = await _firestore.collection('usuarios').doc(idMedico).get();
        if (medicoDoc.exists && medicoDoc.data()?['nombre'] != null) {
          nombreDoctorReal = medicoDoc.data()!['nombre'];
        }
      } catch (e) {
        print('Error obteniendo nombre del médico: $e');
      }

      await _firestore.collection('citas').doc(docId).update({
        'fecha': Timestamp.fromDate(fechaHora),
        'motivo': motivo,
        'id_medico': idMedico,
        'nombre_medico': nombreDoctorReal,
        'hora': '${fechaHora.hour.toString().padLeft(2, '0')}:${fechaHora.minute.toString().padLeft(2, '0')}',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error actualizando cita: $e');
      throw Exception('Error al actualizar la cita: $e');
    }
  }

  // ========== ELIMINAR/CANCELAR CITA ==========
  Future<void> eliminarCita({required String docId}) async {
    try {
      await _firestore.collection('citas').doc(docId).update({
        'estado': 'cancelada',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error cancelando cita: $e');
      throw Exception('Error al cancelar la cita: $e');
    }
  }

  // ========== MÉTODOS DE CONSULTA ==========

  // Obtener próximas citas del usuario - OPTIMIZADO
  // Método corregido para obtener citas con nombres de médicos
  Future<List<Map<String, dynamic>>> obtenerProximasCitasUsuario(String usuarioId) async {
    try {
      // Primero obtener las citas del usuario
      final citasSnapshot = await FirebaseFirestore.instance
          .collection('citas')
          .where('id_paciente', isEqualTo: usuarioId)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1))))
          .orderBy('fecha', descending: false)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> citasConNombres = [];

      for (var doc in citasSnapshot.docs) {
        final citaData = doc.data();
        citaData['doc_id'] = doc.id; // Agregar ID del documento

        // Obtener nombre del médico (ya debería venir en los datos)
        String nombreMedico = citaData['nombre_medico'] ?? 'Dr. No especificado';

        // Si no está en los datos, buscarlo
        if (nombreMedico == 'Dr. No especificado') {
          final medicoId = citaData['id_medico']?.toString() ?? '';
          if (medicoId.isNotEmpty) {
            try {
              final medicoDoc = await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(medicoId)
                  .get();

              if (medicoDoc.exists) {
                final medicoData = medicoDoc.data();
                nombreMedico = medicoData?['nombre']?.toString() ??
                    medicoData?['displayName']?.toString() ??
                    'Dr. $medicoId'.substring(0, 15);
              }
            } catch (e) {
              print('Error obteniendo médico $medicoId: $e');
            }
          }
        }

        // Agregar nombre del médico a los datos de la cita
        citaData['nombre_medico'] = nombreMedico;
        citasConNombres.add(citaData);
      }

      return citasConNombres;
    } catch (e) {
      print('Error en obtenerProximasCitasUsuario: $e');
      return [];
    }
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
          'role': 'patient',
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

  // ========== MÉTODO OBTENER MÉDICOS ==========
  Future<List<Map<String, dynamic>>> obtenerMedicos() async {
    try {
      final snapshot = await _firestore.collection('medicos').get();

      if (snapshot.docs.isEmpty) {
        final usuariosSnapshot = await _firestore
            .collection('usuarios')
            .where('role', isEqualTo: 'doctor')
            .get();

        if (usuariosSnapshot.docs.isEmpty) {
          return [];
        }

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
      return [];
    }
  }

  // ========== MÉTODOS ADICIONALES ==========
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
          final pacienteDoc = await _firestore.collection('usuarios').doc(pacienteId).get();
          final pacienteData = pacienteDoc.data();

          if (pacienteData != null) {
            final citasPaciente = snapshot.docs
                .where((d) => (d.data() as Map<String, dynamic>)['id_paciente'] == pacienteId)
                .length;

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

  Stream<Map<String, dynamic>> obtenerEstadisticasMedico(String doctorId) {
    return _firestore
        .collection('citas')
        .where('id_medico', isEqualTo: doctorId)
        .snapshots()
        .asyncMap((snapshot) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final citas = snapshot.docs;

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

  // ========== NUEVO: OBTENER CITAS DEL DÍA ACTUAL PARA PACIENTE ==========
  Stream<List<Map<String, dynamic>>> obtenerCitasHoyPaciente(String pacienteId) {
    final now = DateTime.now();
    final inicioDia = DateTime(now.year, now.month, now.day);
    final finDia = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('citas')
        .where('id_paciente', isEqualTo: pacienteId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
        .where('estado', whereIn: ['pendiente', 'confirmada'])
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

  // ========== NUEVO: VERIFICAR SI EL USUARIO YA TIENE CITA CON EL MÉDICO EN EL DÍA ==========
  Future<bool> tieneCitaConMedicoEnDia({
    required String pacienteId,
    required String idMedico,
    required DateTime fecha,
  }) async {
    try {
      final inicioDia = DateTime(fecha.year, fecha.month, fecha.day);
      final finDia = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('citas')
          .where('id_paciente', isEqualTo: pacienteId)
          .where('id_medico', isEqualTo: idMedico)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(finDia))
          .where('estado', whereIn: ['pendiente', 'confirmada'])
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error verificando cita existente: $e');
      return false;
    }
  }
  // EN firebase_service.dart - Agrega este método
  Stream<List<Map<String, dynamic>>> obtenerProximasCitasUsuarioStream(String usuarioId) {
    return FirebaseFirestore.instance
        .collection('citas')
        .where('id_paciente', isEqualTo: usuarioId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 1))))
        .orderBy('fecha', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final citasConNombres = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final citaData = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> citaDataCopy = Map<String, dynamic>.from(citaData);
        citaDataCopy['doc_id'] = doc.id;

        // Obtener nombre del médico
        final medicoId = citaDataCopy['id_medico']?.toString() ?? '';
        String nombreMedico = citaDataCopy['nombre_medico'] ?? 'Dr. No especificado';

        if (nombreMedico == 'Dr. No especificado' && medicoId.isNotEmpty) {
          try {
            final medicoDoc = await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(medicoId)
                .get();

            if (medicoDoc.exists) {
              final medicoData = medicoDoc.data();
              nombreMedico = medicoData?['nombre']?.toString() ??
                  medicoData?['displayName']?.toString() ??
                  'Dr. $medicoId'.substring(0, 15);
            }
          } catch (e) {
            print('Error obteniendo médico $medicoId: $e');
          }
        }

        // Agregar nombre del médico a los datos de la cita
        citaDataCopy['nombre_medico'] = nombreMedico;
        citasConNombres.add(citaDataCopy);
      }

      return citasConNombres;
    });
  }
}