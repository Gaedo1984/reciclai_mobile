import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../../materiales_especiales/material_especial.dart';
import '../material_reciclable.dart';
import 'carrusel_pasos_modal.dart';

const _urlTerminos = 'https://gaedo1984.github.io/reciclai_mobile/terminos.html';
const _urlPrivacidad = 'https://gaedo1984.github.io/reciclai_mobile/privacidad.html';

/// Menú lateral de la app, abierto desde el ícono de hamburguesa que Flutter
/// agrega solo en el AppBar cuando `Scaffold.drawer` esta seteado. Cada
/// sección es un `ExpansionTile` (un children más en el ListView) para que
/// agregar más a futuro sea directo, según lo discutido con el usuario.
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

  void _abrirUrl(String url) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Mismo criterio que TextoConLinks: un fallo de Uri.parse/launchUrl no
      // debe tumbar el gesto del usuario (Minor diferido).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        // Column (no todo dentro de un solo ListView) -- asi Terminos y
        // Privacidad quedan pegados al fondo real del drawer, separados del
        // resto por el Divider, en vez de aparecer justo debajo de "Como
        // reciclar" cuando el contenido no llena toda la altura.
        child: Column(
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ExpansionTile(
                    title: const Text('Cómo reciclar'),
                    children: materialesReciclables
                        .map(
                          (material) => ListTile(
                            leading: _iconoDeMaterial(material),
                            title: Text(material.nombre),
                            onTap: () => _abrirCarrusel(context, material),
                          ),
                        )
                        .toList(),
                  ),
                  ExpansionTile(
                    title: const Text('Materiales especiales'),
                    children: materialesEspeciales
                        .map(
                          (material) => ListTile(
                            leading: _iconoDeMaterial(material),
                            title: Text(material.nombre),
                            onTap: () => _abrirCarrusel(context, material),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Términos y condiciones'),
              onTap: () => _abrirUrl(_urlTerminos),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidad'),
              onTap: () => _abrirUrl(_urlPrivacidad),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _iconoDeMaterial(MaterialReciclable material) {
  final iconoSvg = material.iconoSvg;
  if (iconoSvg != null) {
    return SvgPicture.asset(iconoSvg, width: 20, height: 20);
  }
  return Text(material.emoji!, style: const TextStyle(fontSize: 20));
}
