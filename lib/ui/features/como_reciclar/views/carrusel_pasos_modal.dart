import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../material_reciclable.dart';

// Mas alto que el valor inicial (320) -- probado en celular real, el texto
// de las infografias se leia chico (pedido real del usuario, 2026-10-15).
// Es un tope, no un valor fijo: en una pantalla baja (ej. celular en
// horizontal) se achica solo para no desbordar el Dialog (ver _altoCarrusel
// en build(), calculado contra MediaQuery).
const _altoCarruselMaximo = 440.0;
const _altoCarruselMinimo = 200.0;

/// Modal con el carrusel de pasos para reciclar un material, abierto desde el
/// submenú "Cómo reciclar" del menú lateral (`MenuLateral`). Mismo patrón que
/// `DetalleNotificacionModal`: `Dialog` + `BotonCerrarHoja`, solo la X cierra.
class CarruselPasosModal extends StatefulWidget {
  const CarruselPasosModal({super.key, required this.material});

  final MaterialReciclable material;

  @override
  State<CarruselPasosModal> createState() => _CarruselPasosModalState();
}

class _CarruselPasosModalState extends State<CarruselPasosModal> {
  final _controller = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagenes = widget.material.imagenesPasos;
    final colores = Theme.of(context).colorScheme;
    final altoCarrusel = (MediaQuery.of(context).size.height * 0.55).clamp(
      _altoCarruselMinimo,
      _altoCarruselMaximo,
    );
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(espacioMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Cómo reciclar: ${widget.material.nombre}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: espacioSm),
            // Lista vacia es un estado valido (contenido pendiente) -- avisar
            // en vez de mostrar un PageView.builder con itemCount 0, que se
            // veria como un espacio en blanco sin explicacion.
            if (imagenes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: espacioLg),
                child: Text('Todavía no hay contenido para este material.'),
              )
            else ...[
              SizedBox(
                height: altoCarrusel,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: imagenes.length,
                  onPageChanged: (indice) => setState(() => _pagina = indice),
                  itemBuilder: (context, indice) =>
                      Image.asset(imagenes[indice], fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: espacioSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imagenes.length,
                  (indice) => Container(
                    key: ValueKey('punto-indicador-$indice'),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: indice == _pagina
                          ? colores.primary
                          : colores.outlineVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
