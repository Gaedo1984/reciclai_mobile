/// Material con instrucciones de reciclaje, mostrado en el submenú "Cómo
/// reciclar" del menú lateral. `imagenesPasos` vacío es un estado válido --
/// el modal del carrusel (`CarruselPasosModal`) lo muestra como "todavía no
/// hay contenido" en vez de romper, para poder armar la estructura antes de
/// tener las imágenes reales de cada paso.
class MaterialReciclable {
  const MaterialReciclable({
    required this.codigo,
    required this.nombre,
    required this.emoji,
    required this.imagenesPasos,
  });

  final String codigo;
  final String nombre;
  final String emoji;
  final List<String> imagenesPasos;
}

const materialesReciclables = <MaterialReciclable>[
  MaterialReciclable(
    codigo: 'vidrio',
    nombre: 'Vidrio',
    emoji: '🫙',
    imagenesPasos: [],
  ),
  MaterialReciclable(
    codigo: 'aluminio',
    nombre: 'Aluminio (latas de bebida)',
    emoji: '🥫',
    imagenesPasos: [],
  ),
  MaterialReciclable(
    codigo: 'botellas_plastico',
    nombre: 'Botellas de plástico',
    emoji: '🧴',
    imagenesPasos: [],
  ),
];
