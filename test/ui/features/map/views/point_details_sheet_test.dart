import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclai_mobile/data/models/recycling_point.dart';
import 'package:reciclai_mobile/ui/core/material_colors.dart';
import 'package:reciclai_mobile/ui/features/map/views/point_details_sheet.dart';

RecyclingPoint _punto() {
  return RecyclingPoint(
    id: '1',
    nombre: 'Punto Limpio',
    direccion: 'Av. Siempre Viva 123',
    ubicacion: const LatLng(-33.52, -70.60),
    tipo: 'punto_limpio',
    materiales: const ['plastico', 'vidrio'],
    horario: null,
    esEmpresa: false,
    sitioWeb: null,
    confianza: 'media',
  );
}

void main() {
  testWidgets('cada chip de material usa el color de su categoria', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PointDetailsSheet(punto: _punto()))));

    final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
    expect(chips, hasLength(2));

    final avatarPlastico = chips[0].avatar as CircleAvatar;
    expect(avatarPlastico.backgroundColor, colorParaMaterial('plastico'));

    final avatarVidrio = chips[1].avatar as CircleAvatar;
    expect(avatarVidrio.backgroundColor, colorParaMaterial('vidrio'));
  });
}
