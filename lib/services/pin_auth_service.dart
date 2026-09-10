import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import '../firebase_options.dart';

class PinAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<File> _sesionFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}novapos_sesion.json');
  }

  /// Guardar sesion verificada en el dispositivo
  static Future<void> guardarSesion(String email, String uid) async {
    final file = await _sesionFile();
    await file.writeAsString(jsonEncode({
      'sesion_verificada': true,
      'usuario_email': email,
      'usuario_uid': uid,
    }));
  }

  /// Verificar si ya hay sesion verificada en este dispositivo
  static Future<bool> haySesion() async {
    try {
      final file = await _sesionFile();
      if (!await file.exists()) return false;
      String contenido = await file.readAsString();
      Map<String, dynamic> datos = jsonDecode(contenido);
      return datos['sesion_verificada'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener email guardado
  static Future<String?> emailGuardado() async {
    try {
      final file = await _sesionFile();
      if (!await file.exists()) return null;
      String contenido = await file.readAsString();
      Map<String, dynamic> datos = jsonDecode(contenido);
      return datos['usuario_email'];
    } catch (e) {
      return null;
    }
  }

  /// Limpiar sesion guardada (archivo)
  static Future<void> limpiarSesion() async {
    try {
      final file = await _sesionFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {}
  }

  /// Cerrar sesion completa: firma fuera de Firebase y borra el archivo local
  static Future<void> cerrarSesion() async {
    try {
      await _auth.signOut();
    } catch (e) {}
    await limpiarSesion();
  }

  /// Trae el documento del usuario desde Firestore (ya autenticado)
  static Future<Map<String, dynamic>?> _obtenerDocUsuario(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('usuarios').doc(uid).get();
      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['esta_activo'] != true) return null;

      data['uid'] = doc.id;
      try {
        final idLocal = await DBHelper().asegurarUsuarioLocal(
          uid: doc.id,
          nombre: data['nombre']?.toString() ?? '',
          rol: (data['rol'] ?? 'CAJERO').toString(),
          activo: data['esta_activo'] != false,
        );
        data['id'] = idLocal;
      } catch (e) {
        data['id'] = null;
      }
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Enviar enlace de recuperacion (admin resetea PIN de un cajero)
  static Future<bool> enviarEnlaceRecuperacion(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Login con email + PIN (primera vez en el dispositivo).
  /// El PIN es el password real de la cuenta Firebase.
  /// Devuelve null si las credenciales son invalidas o el usuario no existe.
  static Future<Map<String, dynamic>?> loginConEmailPin(
      String email, String pin) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: pin,
      );
      return await _obtenerDocUsuario(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        return null;
      }
      rethrow;
    }
  }

  /// Login con solo PIN usando la sesion guardada (email en disco).
  static Future<Map<String, dynamic>?> loginConPin(String pin) async {
    String? email = await emailGuardado();
    if (email == null || email.isEmpty) return null;

    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pin,
      );
      return await _obtenerDocUsuario(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        return null;
      }
      rethrow;
    }
  }

  /// Verificar el PIN actual del usuario conectado (para acciones sensibles)
  static Future<bool> verificarPinActual(String pinActual) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: pinActual),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cambiar el propio PIN (self-service): requiere el PIN actual
  static Future<Map<String, dynamic>> cambiarPinPropio(
      String pinActual, String nuevoPin) async {
    try {
      final ok = await verificarPinActual(pinActual);
      if (!ok) {
        return {'exito': false, 'mensaje': 'El PIN actual es incorrecto'};
      }

      await _auth.currentUser!.updatePassword(nuevoPin);
      return {'exito': true, 'mensaje': 'PIN actualizado correctamente'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al cambiar el PIN'};
    }
  }

  /// Crear negocio + admin (wizard de instalacion / herramientas de desarrollo)
  static Future<Map<String, dynamic>> crearNegocioAdmin({
    required String nombreNegocio,
    required String nit,
    required String direccion,
    required String emailAdmin,
    required String passwordAdmin,
    required String nombreAdmin,
    String? licenciaFin,
  }) async {
    try {
      final creado = await _crearCuentaFirebase(
        email: emailAdmin,
        pin: passwordAdmin,
      );
      if (!creado['exito']) return creado;

      String uid = creado['uid'];

      DocumentReference negocioRef = await _firestore
          .collection('negocios')
          .add({
        'nombre': nombreNegocio,
        'nit': nit,
        'direccion': direccion,
        'estado': 'activa',
        'licencia_fin': licenciaFin,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
      });

      await _firestore.collection('usuarios').doc(uid).set({
        'email': emailAdmin.trim(),
        'nombre': nombreAdmin,
        'rol': 'ADMIN',
        'negocio_id': negocioRef.id,
        'esta_activo': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'negocioId': negocioRef.id,
        'userId': uid,
        'mensaje': 'Negocio y administrador creados correctamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Crear una cuenta en Firebase Auth por REST sin cambiar la sesion actual.
  /// El PIN queda como password real de la cuenta.
  static Future<Map<String, dynamic>> _crearCuentaFirebase({
    required String email,
    required String pin,
  }) async {
    try {
      final config = DefaultFirebaseOptions.currentPlatform;
      final url =
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${config.apiKey}';

      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': pin,
          'returnSecureToken': true,
        }),
      );

      Map<String, dynamic> data = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        return {'exito': true, 'uid': data['localId'] as String};
      }

      String code = data['error']?['message'] ?? 'Error desconocido';
      if (code.contains('EMAIL_EXISTS')) {
        return {'exito': false, 'mensaje': 'Ese correo ya esta registrado'};
      }
      if (code.contains('WEAK_PASSWORD')) {
        return {
          'exito': false,
          'mensaje': 'El PIN debe tener al menos 6 caracteres'
        };
      }
      return {'exito': false, 'mensaje': 'No se pudo crear la cuenta: $code'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error de conexion al crear cuenta'};
    }
  }

  /// Crear usuario (cajero o admin) desde la app sin afectar la sesion actual
  static Future<Map<String, dynamic>> crearUsuario({
    required String nombre,
    required String email,
    required String pin,
    required String rol,
    required String negocioId,
  }) async {
    try {
      final creado = await _crearCuentaFirebase(email: email, pin: pin);
      if (!creado['exito']) return creado;

      String uid = creado['uid'];

      await _firestore.collection('usuarios').doc(uid).set({
        'email': email.trim(),
        'nombre': nombre,
        'rol': rol,
        'negocio_id': negocioId,
        'esta_activo': true,
        'created_by': _auth.currentUser?.uid,
        'created_at': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'userId': uid,
        'mensaje': 'Usuario $nombre creado correctamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Obtener usuarios de un negocio
  static Future<List<Map<String, dynamic>>> obtenerUsuarios(
      String negocioId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('usuarios')
          .where('negocio_id', isEqualTo: negocioId)
          .where('esta_activo', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Desactivar usuario
  static Future<bool> desactivarUsuario(String uid) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'esta_activo': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Editar nombre y rol de un usuario
  static Future<bool> editarUsuario(String uid, String nombre, String rol) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'nombre': nombre,
        'rol': rol,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verificar si el negocio tiene licencia valida
  static Future<Map<String, dynamic>> verificarLicencia(String negocioId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('negocios')
          .doc(negocioId)
          .get();

      if (!doc.exists) {
        return {'valida': false, 'mensaje': 'Negocio no encontrado'};
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['estado'] == 'bloqueada') {
        return {
          'valida': false,
          'mensaje': 'Licencia bloqueada. Contacte al administrador.'
        };
      }

      dynamic licenciaFin = data['licencia_fin'];
      if (licenciaFin == null) {
        return {'valida': true};
      }

      DateTime fechaFin = (licenciaFin as Timestamp).toDate();
      if (fechaFin.isBefore(DateTime.now())) {
        return {
          'valida': false,
          'mensaje': 'Tu licencia de NovaPOS ha vencido. Renueva para continuar.'
        };
      }

      return {'valida': true};
    } catch (e) {
      return {'valida': false, 'mensaje': 'Error de conexion'};
    }
  }
}