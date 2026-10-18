import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../material_especial.dart';

/// Modal de texto con la informacion de un material especial, abierto desde
/// el submenú "Materiales especiales" del menú lateral (`MenuLateral`).
/// Mismo patrón de cabecera que `CarruselPasosModal` (título + `BotonCerrarHoja`),
/// pero el contenido es texto en vez de un carrusel de fotos -- estos
/// materiales no tienen un proceso casero de varios pasos.
class InfoMaterialEspecialModal extends StatelessWidget {
  const InfoMaterialEspecialModal({super.key, required this.material});

  final MaterialEspecial material;

  @override
  Widget build(BuildContext context) {
    final estiloEncabezado = Theme.of(context).textTheme.titleSmall;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(espacioMd),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      material.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: espacioSm),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(material.descripcion),
                      const SizedBox(height: espacioMd),
                      Text('Cómo prepararlo', style: estiloEncabezado),
                      const SizedBox(height: espacioXs),
                      Text(material.comoPrepararlo),
                      const SizedBox(height: espacioMd),
                      Text('Dónde reciclar', style: estiloEncabezado),
                      const SizedBox(height: espacioXs),
                      Text(material.dondeReciclar),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
