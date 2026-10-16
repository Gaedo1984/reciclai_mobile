import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../material_reciclable.dart';
import 'carrusel_pasos_modal.dart';

/// Menú lateral de la app, abierto desde el ícono de hamburguesa que Flutter
/// agrega solo en el AppBar cuando `Scaffold.drawer` esta seteado. Por ahora
/// solo tiene el submenú "Cómo reciclar" -- se arma como `ExpansionTile` para
/// que agregar más secciones a futuro sea directo (un children más en el
/// ListView), según lo discutido con el usuario.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key});

  void _abrirCarrusel(BuildContext context, MaterialReciclable material) {
    // Cierra el drawer antes de abrir el modal -- dejarlo abierto detras
    // del modal es ruido visual, y Navigator.pop por si solo (sin cerrar
    // el drawer primero) deja el drawer tapado pero montado.
    Navigator.of(context).pop();
    showDialog<void>(
      context: context,
      builder: (_) => CarruselPasosModal(material: material),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Sin color fijo -- BotonCerrarHoja usa el color de icono del
            // tema por defecto, que ya contrasta solo contra el fondo del
            // Drawer tanto en modo claro como oscuro (a diferencia de un
            // logo rasterizado, un Icon normal no necesita una placa fija).
            Padding(
              padding: const EdgeInsets.fromLTRB(espacioSm, espacioXs, espacioSm, 0),
              child: Align(
                alignment: Alignment.topRight,
                child: BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
              ),
            ),
            ExpansionTile(
              title: const Text('Cómo reciclar'),
              children: materialesReciclables
                  .map(
                    (material) => ListTile(
                      leading: Text(
                        material.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(material.nombre),
                      onTap: () => _abrirCarrusel(context, material),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
