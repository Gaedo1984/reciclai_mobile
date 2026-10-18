/// Material de reciclaje "especial" -- a diferencia de `MaterialReciclable`
/// (que muestra un carrusel de fotos paso a paso), estos son materiales que
/// no tienen un proceso casero de varios pasos: lo que el usuario necesita
/// es texto -- qué es, cómo prepararlo y dónde se recibe en Chile. Mostrado
/// en el submenú "Materiales especiales" del menú lateral.
class MaterialEspecial {
  const MaterialEspecial({
    required this.codigo,
    required this.nombre,
    required this.emoji,
    required this.descripcion,
    required this.comoPrepararlo,
    required this.dondeReciclar,
  });

  final String codigo;
  final String nombre;
  final String emoji;
  final String descripcion;
  final String comoPrepararlo;
  final String dondeReciclar;
}

const materialesEspeciales = <MaterialEspecial>[
  MaterialEspecial(
    codigo: 'pilas',
    nombre: 'Pilas',
    emoji: '🔋',
    descripcion: 'Pilas y baterías pequeñas (AA, AAA, botón, etc.). Contienen metales '
        'pesados: no deben ir en la basura normal ni mezclarse con otros reciclables.',
    comoPrepararlo: 'No necesitan preparación especial. Guárdalas en un recipiente '
        'aparte hasta llevarlas a un punto de recepción.',
    dondeReciclar: 'Muchas municipalidades reciben pilas en sus puntos limpios o '
        'verdes (por ejemplo Las Condes, Providencia, Vitacura, Colina y Huechuraba). '
        'Busca el más cercano en santiagorecicla.mma.gob.cl o dondereciclo.cl.',
  ),
  MaterialEspecial(
    codigo: 'aceite_usado',
    nombre: 'Aceite usado',
    emoji: '🛢️',
    descripcion: 'Aceite vegetal usado para freír. Nunca debe botarse por el desagüe '
        'o el inodoro: contamina el agua.',
    comoPrepararlo: 'Déjalo enfriar, fíltralo si tiene restos de comida y viértelo en '
        'una botella plástica con tapa rosca.',
    dondeReciclar: 'Hay más de 50 puntos limpios en el país que reciben aceite usado. '
        'Ubica el más cercano en rendering.cl o consulta en el punto limpio de tu comuna.',
  ),
  MaterialEspecial(
    codigo: 'latas_conserva',
    nombre: 'Latas de conserva',
    emoji: '🫘',
    descripcion: 'Latas de conservas de alimentos -- distintas de las latas de '
        'aluminio de bebidas, que se reciclan aparte.',
    comoPrepararlo: 'Lávalas bien para evitar olores y, si puedes, aplástalas para '
        'que ocupen menos espacio.',
    dondeReciclar: 'Los puntos limpios y verdes que reciben chatarra y metales '
        'ferrosos aceptan latas de conserva. Solo en la Región Metropolitana hay '
        'cerca de 2000 puntos verdes -- revisa chilerecicla.gob.cl o santiagorecicla.cl/mapa.',
  ),
  MaterialEspecial(
    codigo: 'filtros_jarro_agua',
    nombre: 'Filtros de jarro de agua',
    emoji: '💧',
    descripcion: 'Cartuchos filtrantes de jarras purificadoras de agua (tipo Brita y '
        'similares).',
    comoPrepararlo: 'Déjalos secar antes de desecharlos.',
    dondeReciclar: 'En Chile todavía no existe un canal formal establecido para este '
        'residuo, a diferencia de otros países donde la marca trabaja con TerraCycle. '
        'Lo más recomendable es consultar directamente con el fabricante o la tienda '
        'donde compraste el jarro.',
  ),
];
