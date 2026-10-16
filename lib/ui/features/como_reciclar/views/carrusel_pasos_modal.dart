import 'package:flutter/material.dart';

import '../../../core/floating_sheet_card.dart';
import '../../../core/spacing.dart';
import '../material_reciclable.dart';

// Mas alto que el valor inicial (320, luego 440) -- probado en celular real
// dos veces, el texto de las infografias se seguia leyendo chico (pedido
// real del usuario, 2026-10-15). Esta vuelta el pedido fue "mas grande la
// imagen, no el modal" -- el titulo y los margenes se achicaron (ver build())
// para que el espacio ganado se lo lleve la imagen, no el modal entero.
// Es un tope, no un valor fijo: en una pantalla baja (ej. celular en
// horizontal) se achica solo para no desbordar el Dialog (ver _altoCarrusel
// en build(), calculado contra MediaQuery).
const _altoCarruselMaximo = 520.0;
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
    final altoCarrusel = (MediaQuery.of(context).size.height * 0.62).clamp(
      _altoCarruselMinimo,
      _altoCarruselMaximo,
    );
    return Dialog(
      child: Padding(
        // espacioSm (no espacioMd) -- el margen se achico a proposito para
        // darle ese espacio a la imagen en vez de al modal entero.
        padding: const EdgeInsets.all(espacioSm),
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
                    // titleMedium + 1 linea (no titleLarge, que solia envolver
                    // a 2 lineas) -- mismo motivo que el padding: menos alto
                    // de titulo, mas alto disponible para la imagen.
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                BotonCerrarHoja(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: espacioXs),
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
              const SizedBox(height: espacioXs),
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
