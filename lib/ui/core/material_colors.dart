import 'package:flutter/material.dart';

const _colorPorPrefijo = {
  'plastico': Colors.blue,
  'vidrio': Colors.teal,
  'papel_carton': Colors.amber,
  'aluminio': Colors.blueGrey,
  'pilas': Colors.deepPurple,
  'electronicos': Colors.deepPurple,
  'aceite': Colors.brown,
  'organico': Colors.green,
};

const _colorDeRespaldo = Colors.blueGrey;

/// Color asociado a un código de material, para identificarlo visualmente en
/// los chips sin depender solo del texto. Códigos con sufijo (ej.
/// `papel_carton_grande`) heredan el color de su categoría base.
Color colorParaMaterial(String codigo) {
  for (final entrada in _colorPorPrefijo.entries) {
    if (codigo.startsWith(entrada.key)) return entrada.value;
  }
  return _colorDeRespaldo;
}
