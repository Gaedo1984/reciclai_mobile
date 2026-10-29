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
    imagenesPasos: [
      'assets/materiales_especiales/aceite_usado/paso_1.png',
      'assets/materiales_especiales/aceite_usado/paso_2.png',
      'assets/materiales_especiales/aceite_usado/paso_3.png',
      'assets/materiales_especiales/aceite_usado/paso_4.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'latas_conserva',
    nombre: 'Latas de conserva',
    emoji: '🥫',
    imagenesPasos: [
      'assets/materiales_especiales/latas_conserva/paso_1.png',
      'assets/materiales_especiales/latas_conserva/paso_2.png',
      'assets/materiales_especiales/latas_conserva/paso_3.png',
      'assets/materiales_especiales/latas_conserva/paso_4.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'filtros_jarro_agua',
    nombre: 'Filtros de jarro de agua',
    emoji: '💧',
    imagenesPasos: [
      'assets/materiales_especiales/filtros_jarro_agua/paso_1.png',
      'assets/materiales_especiales/filtros_jarro_agua/paso_2.png',
      'assets/materiales_especiales/filtros_jarro_agua/paso_3.png',
      'assets/materiales_especiales/filtros_jarro_agua/paso_4.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'envases_yogurt',
    nombre: 'Envases de yogurt',
    emoji: '🍶',
    imagenesPasos: [
      'assets/materiales_especiales/envases_yogurt/paso_1.png',
      'assets/materiales_especiales/envases_yogurt/paso_2.png',
      'assets/materiales_especiales/envases_yogurt/paso_3.png',
      'assets/materiales_especiales/envases_yogurt/paso_4.png',
    ],
  ),
  MaterialReciclable(
    codigo: 'envases_aerosol',
    nombre: 'Envases de aerosol',
    // No hay un emoji estándar que se lea como lata de aerosol (🧴 se lee
    // como loción/crema, no spray) -- icono real de Material Symbols
    // ("fragrance": envase con nube de rocío, visualmente representa un
    // aerosol), mismo criterio que vidrio/botellas_plastico. El paso 5 no es
    // un paso de manipulación -- es la
    // infografía que explica por qué cuesta encontrar dónde reciclarlos
    // (verificado con fuentes reales: lobarnechea.cl y municipalidadchillan.cl
    // dicen textualmente que NO aceptan aerosoles pese a aceptar chatarra/
    // metal, los tratan como residuo peligroso; la fuente oficial del
    // gobierno, 76% de los puntos del país, ni siquiera tiene esa categoría).
    // En la BD solo 9 puntos tienen confirmación real de fuente, filtrables
    // por "Envases de aerosol" en el mapa.
    iconoSvg: 'assets/icons_materiales/spray_aerosol.svg',
    imagenesPasos: [
      'assets/materiales_especiales/envases_aerosol/paso_1.png',
      'assets/materiales_especiales/envases_aerosol/paso_2.png',
      'assets/materiales_especiales/envases_aerosol/paso_3.png',
      'assets/materiales_especiales/envases_aerosol/paso_4.png',
      'assets/materiales_especiales/envases_aerosol/paso_5.png',
    ],
  ),
];
