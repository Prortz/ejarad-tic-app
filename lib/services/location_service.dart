// lib/services/location_service.dart
// Captura de GPS in situ (latitud, longitud y precisión en metros) con manejo
// de permisos dinámicos de Android y de servicios de ubicación deshabilitados.
import 'package:geolocator/geolocator.dart';

enum GpsEstado {
  ok,
  servicioDeshabilitado,
  permisoDenegado,
  permisoDenegadoPermanente,
  error,
}

class GpsCaptura {
  final GpsEstado estado;
  final Position? posicion;
  final String? mensaje;
  const GpsCaptura(this.estado, {this.posicion, this.mensaje});

  bool get ok => estado == GpsEstado.ok && posicion != null;
  double? get latitud => posicion?.latitude;
  double? get longitud => posicion?.longitude;
  double? get precisionM => posicion?.accuracy;
}

class LocationService {
  LocationService._();

  static Future<GpsCaptura> capturar() async {
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        return const GpsCaptura(GpsEstado.servicioDeshabilitado,
            mensaje: 'Los servicios de ubicación (GPS) del dispositivo están desactivados.');
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission(); // solicitud dinámica al SO
      }
      if (perm == LocationPermission.denied) {
        return const GpsCaptura(GpsEstado.permisoDenegado,
            mensaje: 'Permiso de ubicación denegado.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const GpsCaptura(GpsEstado.permisoDenegadoPermanente,
            mensaje: 'Permiso de ubicación denegado permanentemente. Actívalo en Ajustes.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 25),
        ),
      );
      return GpsCaptura(GpsEstado.ok, posicion: pos);
    } catch (e) {
      return GpsCaptura(GpsEstado.error,
          mensaje: 'No se pudo obtener la ubicación. Intenta de nuevo al aire libre.');
    }
  }

  static Future<void> abrirAjustes(GpsEstado estado) async {
    if (estado == GpsEstado.servicioDeshabilitado) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
