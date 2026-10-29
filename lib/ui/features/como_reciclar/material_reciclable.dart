/// Material con instrucciones de reciclaje, mostrado en el submenú "Cómo
/// reciclar" del menú lateral. `imagenesPasos` vacío es un estado válido --
/// el modal del carrusel (`CarruselPasosModal`) lo muestra como "todavía no
/// hay contenido" en vez de romper, para poder armar la estructura antes de
/// tener las imágenes reales de cada paso.
///
/// Exactamente uno de `emoji` o `iconoSvg` debe venir seteado -- `iconoSvg`
/// es para los pocos materiales donde no hay un emoji estándar que se vea
/// bien (ej. botellas de plástico: el emoji más cercano, 🧴, se lee como un
/// envase de crema, no una botella). Usa un ícono de Material Symbols
/// (Apache 2.0, fonts.google.com/icons) en vez de uno de un banco de íconos
/// con licencia de atribución, para no tener que mantener una pantalla de
/// créditos.
class MaterialReciclable {
  const MaterialReciclable({
    required this.codigo,
    required this.nombre,
    this.emoji,
    this.iconoSvg,
    required this.imagenesPasos,
  }) : assert(
         (emoji == null) != (iconoSvg == null),
         'MaterialReciclable necesita exactamente uno de emoji o iconoSvg',
       );

  final String codigo;
  final String nombre;
  final String? emoji;
  final String? iconoSvg;
  final List<String> imagenesPasos;
}

const materialesReciclables = <MaterialReciclable>[
  MaterialReciclable(
    codigo: 'vidrio',
    nombre: 'Vidrio',
    // El emoji de vaso/frasco (🫙) es Unicode 14 (2021) -- invisible en
    // Android 12 o anterior sin el emoji font del sistema actualizado (bug
    // real reportado: "el icono de vidrio no aparece" en Android). Mismo
    // criterio que botellas_plastico: icono real en vez de un emoji que no
    // se puede garantizar en todos los dispositivos.
    iconoSvg: 'assets/icons_materiales/vaso_vidrio.svg',
    imagenesPasos: [
      'assets/como_reciclar/vidrio/paso_1.jpg',
      'assets/como_reciclar/vidrio/paso_2.png',
      'assets/como_reciclar/vidrio/paso_3.png',
      'assets/como_reciclar/vidrio/paso_4.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'aluminio',
    nombre: 'Aluminio (latas de bebida)',
    emoji: '🥤',
    imagenesPasos: [
      'assets/como_reciclar/aluminio/paso_1.png',
      'assets/como_reciclar/aluminio/paso_2.jpg',
      'assets/como_reciclar/aluminio/paso_3.png',
      'assets/como_reciclar/aluminio/paso_4.jpg',
    ],
  ),
  MaterialReciclable(
    codigo: 'botellas_plastico',
    nombre: 'Botellas de plástico',
    iconoSvg: 'assets/icons_materiales/botella_agua.svg',
    imagenesPasos: [
      'assets/como_reciclar/botellas_plastico/paso_1.jpg',
      'assets/como_reciclar/botellas_plastico/paso_2.png',
      'assets/como_reciclar/botellas_plastico/paso_3.png',
      'assets/como_reciclar/botellas_plastico/paso_4.png',
      'assets/como_reciclar/botellas_plastico/paso_5.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'carton_papeles',
    nombre: 'Cartón y papeles',
    emoji: '📦',
    imagenesPasos: [
      'assets/como_reciclar/carton_papeles/paso_1.jpg',
      'assets/como_reciclar/carton_papeles/paso_2.jpg',
      'assets/como_reciclar/carton_papeles/paso_3.jpg',
      'assets/como_reciclar/carton_papeles/paso_4.jpg',
      'assets/como_reciclar/carton_papeles/paso_5.jpg',
      'assets/como_reciclar/carton_papeles/paso_6.jpg',
      'assets/como_reciclar/carton_papeles/paso_7.jpg',
    ],
  ),
  MaterialReciclable(
    codigo: 'tetrapak',
    nombre: 'Tetrapak',
    // 🧃 (beverage box, Unicode 11 / 2018) representa bien un envase de
    // cartón para bebidas -- a diferencia de 🫙 en vidrio, esta edad de
    // emoji ya tiene soporte amplio, no hace falta iconoSvg.
    // Pasos reales (fuente oficial, guía conjunta Fundación Basura + Tetra
    // Pak Chile, "Guía de clasificación envases cartón para bebidas"):
    // 1) Limpiar: desplegar las aletas, enjuagar con un poco de agua
    // (tapar, agitar, vaciar -- repetir si es lácteo), dejar secar boca
    // abajo. No hace falta recortar el envase.
    // 2) Aplastar: una vez seco, sacar el aire y aplastarlo bien. Volver a
    // poner la tapa o insertar la bombilla en el envase ya sin aire.
    // 3) Clasificar y llevar a un punto limpio/verde con categoría
    // "cartón para bebidas" separada (no se mezcla con cartón normal).
    emoji: '🧃',
    imagenesPasos: [
      'assets/como_reciclar/tetrapak/paso_1.png',
      'assets/como_reciclar/tetrapak/paso_2.png',
      'assets/como_reciclar/tetrapak/paso_3.png',
    ],
  ),
];
