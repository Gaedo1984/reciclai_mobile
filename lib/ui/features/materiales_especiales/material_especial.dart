import '../como_reciclar/material_reciclable.dart';

/// Materiales mostrados en el submenú "Materiales especiales" del menú
/// lateral -- mismo tipo y mismo modal de carrusel (`CarruselPasosModal`)
/// que "Cómo reciclar" (`materialesReciclables`), solo que agrupados aparte
/// porque son materiales más difíciles de encontrar dónde reciclar (pilas,
/// aceite usado, latas de conserva, filtros de jarro de agua) en vez de los
/// reciclables cotidianos. `imagenesPasos` vacío es un estado válido --
/// armamos la estructura antes de tener las imágenes reales de cada paso.
const materialesEspeciales = <MaterialReciclable>[
  MaterialReciclable(
    codigo: 'pilas',
    nombre: 'Pilas',
    emoji: '🔋',
    imagenesPasos: [
      'assets/materiales_especiales/pilas/paso_1.png',
      'assets/materiales_especiales/pilas/paso_2.png',
      'assets/materiales_especiales/pilas/paso_3.png',
      'assets/materiales_especiales/pilas/paso_4.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'aceite_usado',
    nombre: 'Aceite usado',
    emoji: '🛢️',
    imagenesPasos: [],
  ),
  MaterialReciclable(
    codigo: 'latas_conserva',
    nombre: 'Latas de conserva',
    emoji: '🫘',
    imagenesPasos: [],
  ),
  MaterialReciclable(
    codigo: 'filtros_jarro_agua',
    nombre: 'Filtros de jarro de agua',
    emoji: '💧',
    imagenesPasos: [],
  ),
];
