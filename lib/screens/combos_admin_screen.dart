import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../services/locale_service.dart';
import 'inventory_screen.dart'; // Just in case, though maybe we can use a custom picker

String _t(String es) => LocaleService().esEspanol ? es : es;

final formater = NumberFormat.currency(
  locale: 'es_CO',
  symbol: '\$',
  decimalDigits: 0,
);

class CombosAdminScreen extends StatefulWidget {
  const CombosAdminScreen({super.key});

  @override
  State<CombosAdminScreen> createState() => _CombosAdminScreenState();
}

class _CombosAdminScreenState extends State<CombosAdminScreen> {
  final DBHelper _db = DBHelper();
  bool _cargando = true;
  List<Map<String, dynamic>> _combos = [];

  @override
  void initState() {
    super.initState();
    _cargarCombos();
  }

  Future<void> _cargarCombos() async {
    final db = await _db.database;
    final data = await db.query('productos', where: 'es_combo = 1', orderBy: 'id DESC');
    setState(() {
      _combos = data;
      _cargando = false;
    });
  }

  bool _esAdmin() {
    return SessionService.userRole() == 'ADMIN';
  }

  void _mostrarAvisoRestriccion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ Solo el Administrador puede gestionar Combos.'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  void _abrirFormularioCombo() {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _CrearComboScreen()),
    ).then((_) => _cargarCombos());
  }

  Future<void> _eliminarCombo(int id) async {
    if (!_esAdmin()) {
      _mostrarAvisoRestriccion();
      return;
    }
    bool? confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t("Eliminar Combo")),
        content: Text(_t("¿Estás seguro de eliminar este combo?")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t("CANCELAR"))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t("ELIMINAR")),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      final db = await _db.database;
      await db.delete('productos', where: 'id = ?', whereArgs: [id]);
      await db.delete('combo_detalles', where: 'combo_id = ?', whereArgs: [id]);
      _cargarCombos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t("Gestión de Combos 🎁")),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _combos.isEmpty
              ? Center(child: Text(_t("No hay combos creados. ¡Crea uno nuevo!")))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _combos.length,
                  itemBuilder: (ctx, i) {
                    final c = _combos[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Icon(Icons.card_giftcard, color: Colors.white),
                        ),
                        title: Text(c['nombre']?.toString() ?? ''),
                        subtitle: Text("Precio: ${formater.format((c['precio_venta'] as num?)?.toDouble() ?? 0)}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarCombo(c['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioCombo,
        icon: const Icon(Icons.add),
        label: Text(_t("NUEVO COMBO")),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _CrearComboScreen extends StatefulWidget {
  const _CrearComboScreen();

  @override
  State<_CrearComboScreen> createState() => _CrearComboScreenState();
}

class _CrearComboScreenState extends State<_CrearComboScreen> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  
  final List<Map<String, dynamic>> _componentes = [];
  final DBHelper _db = DBHelper();

  void _agregarComponente() async {
    // We can show a simple dialog with a list of products
    final db = await _db.database;
    final productos = await db.query('productos', where: 'esta_activo = 1 AND es_combo = 0', orderBy: 'nombre ASC');
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t("Seleccionar Producto")),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: productos.length,
              itemBuilder: (c, i) {
                final p = productos[i];
                return ListTile(
                  title: Text(p['nombre']?.toString() ?? ''),
                  subtitle: Text("Stock: ${p['stock_actual']}"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pedirCantidad(p);
                  },
                );
              },
            ),
          ),
        );
      }
    );
  }

  void _pedirCantidad(Map<String, dynamic> prod) {
    final qtyCtrl = TextEditingController(text: "1");
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Cantidad de ${prod['nombre']}"),
          content: TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: _t("Cantidad")),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t("CANCELAR"))),
            ElevatedButton(
              onPressed: () {
                double qty = double.tryParse(qtyCtrl.text) ?? 1;
                setState(() {
                  _componentes.add({
                    'producto_id': prod['id'],
                    'nombre': prod['nombre'],
                    'cantidad': qty,
                  });
                });
                Navigator.pop(ctx);
              },
              child: Text(_t("AGREGAR")),
            ),
          ],
        );
      }
    );
  }

  void _guardarCombo() async {
    if (_nombreCtrl.text.isEmpty || _precioCtrl.text.isEmpty || _componentes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t("Faltan datos o componentes."))));
      return;
    }

    double precio = double.tryParse(_precioCtrl.text) ?? 0;

    final comboData = {
      'nombre': _nombreCtrl.text,
      'precio_venta': precio,
      'precio_costo': 0.0, // Podríamos calcularlo
      'codigo_barras': _codigoCtrl.text.isNotEmpty ? _codigoCtrl.text : 'COMBO-${DateTime.now().millisecondsSinceEpoch}',
      'categoria': 'Combos',
      'stock_actual': 9999.0, // Los combos son virtuales, no tienen stock directo limitante en UI rápida
      'es_combo': 1,
      'esta_activo': 1,
    };

    await _db.crearCombo(comboData, _componentes);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t("Crear Combo")),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nombreCtrl, decoration: InputDecoration(labelText: _t("Nombre del Combo (Ej: Arroz + Aceite)"))),
            const SizedBox(height: 10),
            TextField(controller: _precioCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _t("Precio de Venta Final"))),
            const SizedBox(height: 10),
            TextField(controller: _codigoCtrl, decoration: InputDecoration(labelText: _t("Código de Barras (Opcional)"))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t("Componentes:"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: _agregarComponente,
                  icon: const Icon(Icons.add),
                  label: Text(_t("Añadir Producto")),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _componentes.length,
                itemBuilder: (ctx, i) {
                  final c = _componentes[i];
                  return ListTile(
                    title: Text(c['nombre']?.toString() ?? ''),
                    subtitle: Text("Cantidad a descontar: ${c['cantidad']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _componentes.removeAt(i);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple[800], foregroundColor: Colors.white),
                onPressed: _guardarCombo,
                child: Text(_t("GUARDAR COMBO")),
              ),
            )
          ],
        ),
      ),
    );
  }
}
