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
    emoji: '🥫',
    imagenesPasos: [
      'assets/como_reciclar/aluminio/paso_1.png',
      'assets/como_reciclar/aluminio/paso_2.png',
      'assets/como_reciclar/aluminio/paso_3.png',
      'assets/como_reciclar/aluminio/paso_4.jpg',
    ],
  ),
  MaterialReciclable(
    codigo: 'botellas_plastico',
    nombre: 'Botellas de plástico',
    emoji: '🧴',
    imagenesPasos: [
      'assets/como_reciclar/botellas_plastico/paso_1.jpg',
      'assets/como_reciclar/botellas_plastico/paso_2.png',
      'assets/como_reciclar/botellas_plastico/paso_3.png',
      'assets/como_reciclar/botellas_plastico/paso_4.png',
      'assets/como_reciclar/botellas_plastico/paso_5.png',
    ],
  ),
];
