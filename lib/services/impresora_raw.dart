import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Envía bytes tal cual (modo RAW) a una impresora instalada en Windows,
/// sin pasar por el controlador de dibujo. Sirve para órdenes ESC/POS como
/// la apertura del cajón monedero conectado por RJ11 a la impresora térmica.
class ImpresoraRaw {
  /// Pulso de apertura del cajón (ESC p m t1 t2) por los dos conectores,
  /// pin 2 y pin 5, porque cada marca de cajón usa uno de los dos.
  static const List<int> pulsoCajon = [
    0x1B, 0x70, 0x00, 0x19, 0xFA, //
    0x1B, 0x70, 0x01, 0x19, 0xFA,
  ];

  /// true si Windows aceptó los bytes en la cola de la impresora.
  static bool enviar(String impresora, List<int> bytes) {
    if (!Platform.isWindows || impresora.isEmpty || bytes.isEmpty) return false;
    final winspool = DynamicLibrary.open('winspool.drv');
    final openPrinter = winspool
        .lookupFunction<
          Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>),
          int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>)
        >('OpenPrinterW');
    final startDoc = winspool
        .lookupFunction<
          Uint32 Function(IntPtr, Uint32, Pointer<_DocInfo1>),
          int Function(int, int, Pointer<_DocInfo1>)
        >('StartDocPrinterW');
    final startPage = winspool
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'StartPagePrinter',
        );
    final writePrinter = winspool
        .lookupFunction<
          Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>),
          int Function(int, Pointer<Uint8>, int, Pointer<Uint32>)
        >('WritePrinter');
    final endPage = winspool
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'EndPagePrinter',
        );
    final endDoc = winspool
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'EndDocPrinter',
        );
    final closePrinter = winspool
        .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
          'ClosePrinter',
        );

    final nombre = impresora.toNativeUtf16(allocator: calloc);
    final nombreDoc = 'NovaPOS Cajon'.toNativeUtf16(allocator: calloc);
    final tipo = 'RAW'.toNativeUtf16(allocator: calloc);
    final handle = calloc<IntPtr>();
    final info = calloc<_DocInfo1>();
    final buffer = calloc<Uint8>(bytes.length);
    final escritos = calloc<Uint32>();
    try {
      if (openPrinter(nombre, handle, nullptr) == 0) return false;
      final h = handle.value;
      var ok = false;
      info.ref
        ..pDocName = nombreDoc
        ..pOutputFile = nullptr
        ..pDatatype = tipo;
      if (startDoc(h, 1, info) != 0) {
        if (startPage(h) != 0) {
          buffer.asTypedList(bytes.length).setAll(0, bytes);
          ok =
              writePrinter(h, buffer, bytes.length, escritos) != 0 &&
              escritos.value == bytes.length;
          endPage(h);
        }
        endDoc(h);
      }
      closePrinter(h);
      return ok;
    } finally {
      calloc.free(nombre);
      calloc.free(nombreDoc);
      calloc.free(tipo);
      calloc.free(handle);
      calloc.free(info);
      calloc.free(buffer);
      calloc.free(escritos);
    }
  }
}

final class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}
