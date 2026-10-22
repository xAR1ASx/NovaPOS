import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../services/balanza_service.dart';
import '../services/printer_service.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';

/// Asistente de primer uso: deja la caja lista para vender en 5 pasos, sin
/// tener que buscar en Ajustes. Guarda en las mismas claves que Ajustes.
class AsistenteInicioScreen extends StatefulWidget {
  /// Pantalla a la que se va al terminar o al saltar el asistente. Sin ella
  /// (abierto desde Ajustes) simplemente vuelve atrás.
  final Widget? siguiente;
  const AsistenteInicioScreen({super.key, this.siguiente});

  /// Se muestra al administrador mientras no lo haya terminado o saltado.
  static Future<bool> debeMostrarse() async {
    if (SessionService.userRole() != 'ADMIN') return false;
    final cfg = await DBHelper().obtenerConfiguracion();
    return cfg['asistente_inicio_hecho'] != '1';
  }

  @override
  State<AsistenteInicioScreen> createState() => _AsistenteInicioScreenState();
}

class _AsistenteInicioScreenState extends State<AsistenteInicioScreen> {
  static const _verde = Color(0xFF10B981);
  int _paso = 0;
  static const _total = 5;

  final _nombre = TextEditingController();
  final _nit = TextEditingController();
  final _direccion = TextEditingController();
  final _ciudad = TextEditingController();
  final _telefono = TextEditingController();
  final _caja = TextEditingController();
  String _modoBalanza = BalanzaService.modoManual;
  String _puerto = '';
  List<String> _puertos = [];
  List<String> _impresoras = [];
  String _impresora = '';
  bool _buscando = false;
  String _aviso = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _nit, _direccion, _ciudad, _telefono, _caja]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final cfg = await DBHelper().obtenerConfiguracion();
    // "NovaPOS" es el valor de fábrica, no el nombre del negocio.
    final nombre = (cfg['empresa_nombre'] ?? '').trim();
    _nombre.text = nombre == 'NovaPOS' ? '' : nombre;
    _nit.text = cfg['empresa_nit'] ?? '';
    _direccion.text = cfg['empresa_direccion'] ?? '';
    _ciudad.text = cfg['empresa_ciudad'] ?? '';
    _telefono.text = cfg['empresa_telefono'] ?? '';
    _caja.text = cfg['caja_nombre'] ?? 'Caja principal';
    _impresora = cfg['impresora_nombre'] ?? '';
    _puerto = cfg['balanza_puerto'] ?? '';
    _modoBalanza = await BalanzaService.modo();
    // Los datos del negocio ya están en la nube: se precargan para no
    // escribirlos dos veces.
    try {
      final id = SessionService.negocioId();
      if (id != null && _nombre.text.trim().isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('negocios').doc(id).get();
        final d = doc.data() ?? {};
        _nombre.text = (d['nombre'] ?? '').toString();
        if (_nit.text.isEmpty) _nit.text = (d['nit'] ?? '').toString();
        if (_direccion.text.isEmpty) _direccion.text = (d['direccion'] ?? '').toString();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _guardarPaso() async {
    final db = DBHelper();
    switch (_paso) {
      case 1:
        await db.guardarConfiguracion('empresa_nombre', _nombre.text.trim());
        await db.guardarConfiguracion('empresa_nit', _nit.text.trim());
        await db.guardarConfiguracion('empresa_direccion', _direccion.text.trim());
        await db.guardarConfiguracion('empresa_ciudad', _ciudad.text.trim());
        await db.guardarConfiguracion('empresa_telefono', _telefono.text.trim());
        await db.guardarConfiguracion('caja_nombre',
            _caja.text.trim().isEmpty ? 'Caja principal' : _caja.text.trim());
        break;
      case 2:
        await BalanzaService.guardarModo(_modoBalanza);
        if (_modoBalanza == BalanzaService.modoBalanza && _puerto.isNotEmpty) {
          await db.guardarConfiguracion('balanza_puerto', _puerto);
          await BalanzaService.conectarSiCorresponde();
        }
        break;
      case 3:
        if (_impresora.isNotEmpty) {
          await db.guardarConfiguracion('impresora_nombre', _impresora);
          await db.guardarConfiguracion('impresion_directa', '1');
        }
        break;
    }
  }

  Future<void> _terminar() async {
    await DBHelper().guardarConfiguracion('asistente_inicio_hecho', '1');
    if (!mounted) return;
    if (widget.siguiente == null) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => widget.siguiente!));
  }

  Future<void> _siguiente() async {
    if (_paso == 1 && _nombre.text.trim().isEmpty) {
      setState(() => _aviso = 'Escribe el nombre del negocio: sale en el ticket.');
      return;
    }
    setState(() => _aviso = '');
    await _guardarPaso();
    if (_paso == _total - 1) {
      await _terminar();
      return;
    }
    setState(() => _paso++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Paso ${_paso + 1} de $_total',
                          style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (_paso < _total - 1)
                        TextButton(onPressed: _terminar, child: const Text('Hacerlo después')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_paso + 1) / _total,
                      minHeight: 8,
                      backgroundColor: context.chipBg,
                      valueColor: const AlwaysStoppedAnimation(_verde),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: SingleChildScrollView(child: _contenido())),
                  if (_aviso.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_aviso, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  Row(
                    children: [
                      if (_paso > 0)
                        OutlinedButton(
                          onPressed: () => setState(() => _paso--),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                          child: const Text('Atrás'),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _siguiente,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _verde,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        child: Text(_paso == 0
                            ? 'Empezar'
                            : (_paso == _total - 1 ? 'Ir a vender' : 'Siguiente')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(IconData icono, String titulo, String ayuda) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 44, color: _verde),
          const SizedBox(height: 12),
          Text(titulo, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.textPrimary)),
          const SizedBox(height: 6),
          Text(ayuda, style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.4)),
          const SizedBox(height: 22),
        ],
      );

  Widget _campo(TextEditingController c, String etiqueta, {String? ayuda, TextInputType? teclado}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: teclado,
          decoration: InputDecoration(
            labelText: etiqueta,
            helperText: ayuda,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: context.inputBg,
          ),
        ),
      );

  Widget _opcion({
    required bool activa,
    required IconData icono,
    required String titulo,
    required String ayuda,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: activa ? _verde.withOpacity(context.isDarkMode ? 0.2 : 0.08) : context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: activa ? _verde : context.borderSubtle, width: activa ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(icono, size: 32, color: activa ? _verde : context.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                      const SizedBox(height: 3),
                      Text(ayuda, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                    ],
                  ),
                ),
                Icon(activa ? Icons.check_circle : Icons.circle_outlined,
                    color: activa ? _verde : context.textSecondary),
              ],
            ),
          ),
        ),
      );

  Widget _contenido() {
    switch (_paso) {
      case 0:
        return _titulo(
          Icons.waving_hand_rounded,
          '¡Bienvenido a NovaPOS!',
          'Vamos a dejar esta caja lista para vender en unos pocos pasos: los datos del ticket, '
              'la balanza y la impresora. Todo se puede cambiar después en Ajustes.',
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titulo(Icons.storefront_rounded, 'Tu negocio',
                'Estos datos salen en el ticket que recibe el cliente.'),
            _campo(_nombre, 'Nombre del negocio *'),
            _campo(_nit, 'NIT (opcional)'),
            _campo(_direccion, 'Dirección (opcional)'),
            _campo(_ciudad, 'Ciudad (opcional)'),
            _campo(_telefono, 'Teléfono (opcional)', teclado: TextInputType.phone),
            const SizedBox(height: 8),
            _campo(_caja, 'Nombre de esta caja',
                ayuda: 'Si el negocio tiene varias cajas, ponle un nombre a cada una (ej. "Caja 2" o "Caja frutas").'),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titulo(Icons.scale_rounded, '¿Cómo pesas los productos?',
                'Para frutas, verduras y todo lo que se vende por kilo.'),
            _opcion(
              activa: _modoBalanza == BalanzaService.modoManual,
              icono: Icons.keyboard_rounded,
              titulo: 'Escribo el peso a mano',
              ayuda: 'El cajero escribe los kilos, los gramos o el valor que pide el cliente.',
              onTap: () => setState(() => _modoBalanza = BalanzaService.modoManual),
            ),
            _opcion(
              activa: _modoBalanza == BalanzaService.modoBalanza,
              icono: Icons.monitor_weight_rounded,
              titulo: 'Tengo una balanza conectada al PC',
              ayuda: 'La balanza digital pone el peso sola en la caja.',
              onTap: () => setState(() => _modoBalanza = BalanzaService.modoBalanza),
            ),
            if (_modoBalanza == BalanzaService.modoBalanza) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _puertos.contains(_puerto) ? _puerto : null,
                      hint: const Text('Puerto de la balanza'),
                      items: _puertos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setState(() => _puerto = v ?? ''),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _puertos = BalanzaService.puertosDisponibles();
                      if (_puertos.isNotEmpty && !_puertos.contains(_puerto)) _puerto = _puertos.first;
                    }),
                    icon: const Icon(Icons.usb),
                    label: const Text('Buscar'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _puertos.isEmpty
                    ? 'Conecta la balanza y toca "Buscar". Si no aparece, revisa el cable o el driver.'
                    : 'Elige el puerto. La balanza se conectará sola cada vez que abras NovaPOS.',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titulo(Icons.print_rounded, 'Impresora de tickets',
                'La impresora térmica debe estar instalada en Windows con su driver.'),
            ElevatedButton.icon(
              onPressed: _buscando
                  ? null
                  : () async {
                      setState(() => _buscando = true);
                      final l = await PrinterService().obtenerImpresoras();
                      if (!mounted) return;
                      setState(() {
                        _buscando = false;
                        _impresoras = l;
                        if (l.isNotEmpty && !l.contains(_impresora)) _impresora = l.first;
                      });
                    },
              icon: const Icon(Icons.search),
              label: Text(_buscando ? 'Buscando…' : 'Buscar impresoras'),
            ),
            const SizedBox(height: 12),
            ..._impresoras.map((i) => _opcion(
                  activa: _impresora == i,
                  icono: Icons.print_outlined,
                  titulo: i,
                  ayuda: _impresora == i ? 'Esta se usará para los tickets' : 'Toca para elegirla',
                  onTap: () => setState(() => _impresora = i),
                )),
            if (_impresora.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await DBHelper().guardarConfiguracion('impresora_nombre', _impresora);
                  await DBHelper().guardarConfiguracion('impresion_directa', '1');
                  await PrinterService().imprimirTicketPrueba();
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Imprimir un ticket de prueba'),
              ),
            if (_impresoras.isEmpty)
              Text('Si no tienes impresora todavía, toca "Siguiente": se puede configurar después en Ajustes.',
                  style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titulo(Icons.check_circle_rounded, '¡Listo para vender!', 'Así es un día normal en NovaPOS:'),
            ...[
              ('1', 'Abre la caja', 'En "Caja", toca INICIAR TURNO y escribe el dinero con que empiezas.'),
              ('2', 'Vende', 'En "Vender", toca los productos o pasa el lector de código de barras.'),
              ('3', 'Anota los gastos', 'Si sacas plata de la caja (domicilio, bolsas, proveedor), regístrala en "Caja".'),
              ('4', 'Cierra la caja', 'Al final del día, cuenta el efectivo y toca CERRAR TURNO.'),
              ('5', 'Mira cómo te fue', 'En "Reportes" ves la ganancia, lo más vendido y los cierres de todas las cajas.'),
            ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: _verde,
                        child: Text(t.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.$2, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                            Text(t.$3, style: TextStyle(color: context.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
    }
  }
}
