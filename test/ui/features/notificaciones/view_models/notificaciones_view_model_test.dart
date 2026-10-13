import 'package:flutter_test/flutter_test.dart';
import 'package:reciclai_mobile/data/models/notificacion.dart';
import 'package:reciclai_mobile/data/reciclai_api_exception.dart';
import 'package:reciclai_mobile/ui/features/notificaciones/view_models/notificaciones_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../../../fakes.dart';

Notificacion _n(String id) => Notificacion(
  id: id,
  titulo: 'Aviso $id',
  texto: 'Cuerpo',
  creadaEn: DateTime(2026, 10, 12),
);

/// Reemplaza el almacen de SharedPreferences por uno que siempre falla --
/// para probar que un fallo de la plataforma (poco probable, pero posible)
/// no se escapa como un error async sin capturar (Minor diferido en la
/// revision final).
class _AlmacenQueFalla extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async =>
      throw Exception('fallo simulado de SharedPreferences');

  @override
  Future<Map<String, Object>> getAll() async =>
      throw Exception('fallo simulado de SharedPreferences');

  @override
  Future<bool> remove(String key) async =>
      throw Exception('fallo simulado de SharedPreferences');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('fallo simulado de SharedPreferences');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hayNoLeidas es false antes de cargar (lista vacia)', () {
    final viewModel = NotificacionesViewModel(apiClient: ApiClientFalso());

    expect(viewModel.hayNoLeidas, isFalse);
    expect(viewModel.notificaciones, isEmpty);
  });

  test(
    'tras cargar con notificaciones nuevas y nada leido, hayNoLeidas es true',
    () async {
      final viewModel = NotificacionesViewModel(
        apiClient: ApiClientFalso(notificaciones: [_n('n1')]),
      );

      await viewModel.cargar();

      expect(viewModel.hayNoLeidas, isTrue);
      expect(viewModel.notificaciones, hasLength(1));
    },
  );

  test('marcarLeida saca la notificacion de "no leidas"; con todas leidas, hayNoLeidas es false', () async {
    final viewModel = NotificacionesViewModel(
      apiClient: ApiClientFalso(notificaciones: [_n('n1')]),
    );
    await viewModel.cargar();
    expect(viewModel.hayNoLeidas, isTrue);

    await viewModel.marcarLeida('n1');

    expect(viewModel.estaLeida('n1'), isTrue);
    expect(viewModel.hayNoLeidas, isFalse);
  });

  test('marcarLeida persiste entre instancias distintas del ViewModel (Review Focus)', () async {
    final apiClient = ApiClientFalso(notificaciones: [_n('n1')]);
    final viewModel1 = NotificacionesViewModel(apiClient: apiClient);
    await viewModel1.cargar();
    await viewModel1.marcarLeida('n1');

    final viewModel2 = NotificacionesViewModel(apiClient: apiClient);
    await viewModel2.cargar();

    expect(viewModel2.estaLeida('n1'), isTrue);
    expect(viewModel2.hayNoLeidas, isFalse);
  });

  test('marcarLeida en una notificacion ya leida no falla ni la duplica (Review Focus)', () async {
    final viewModel = NotificacionesViewModel(
      apiClient: ApiClientFalso(notificaciones: [_n('n1')]),
    );
    await viewModel.cargar();
    await viewModel.marcarLeida('n1');

    await viewModel.marcarLeida('n1');

    expect(viewModel.estaLeida('n1'), isTrue);
    expect(viewModel.hayNoLeidas, isFalse);
  });

  test('un fallo de obtenerNotificaciones en una carga posterior no lanza y mantiene lo que ya '
      'habia (Review Focus)', () async {
    final apiClient = ApiClientFalso(
      notificacionesPorLlamada: (numeroDeLlamada) {
        if (numeroDeLlamada == 1) return [_n('n1')];
        throw const ReciclaiApiException('fallo simulado');
      },
    );
    final viewModel = NotificacionesViewModel(apiClient: apiClient);
    await viewModel.cargar();
    expect(viewModel.notificaciones, hasLength(1));
    expect(viewModel.hayNoLeidas, isTrue);

    await viewModel.cargar();

    expect(viewModel.notificaciones, hasLength(1));
    expect(viewModel.hayNoLeidas, isTrue);
  });

  test('un fallo de SharedPreferences al leer lo leido no se escapa de cargar() (Minor diferido)', () async {
    final original = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _AlmacenQueFalla();
    addTearDown(() => SharedPreferencesStorePlatform.instance = original);
    final viewModel = NotificacionesViewModel(
      apiClient: ApiClientFalso(notificaciones: [_n('n1')]),
    );

    await viewModel.cargar();

    // obtenerNotificaciones() si funciona (el fallo es solo en
    // SharedPreferences) -- lo que prueba este test es que cargar() no
    // propago la excepcion de SharedPreferences sin capturar, no que haya
    // dejado de cargar notificaciones.
    expect(viewModel.notificaciones, hasLength(1));
  });

  test('un fallo de SharedPreferences al guardar lo leido no se escapa de marcarLeida '
      '(Minor diferido)', () async {
    final original = SharedPreferencesStorePlatform.instance;
    addTearDown(() => SharedPreferencesStorePlatform.instance = original);
    final viewModel = NotificacionesViewModel(
      apiClient: ApiClientFalso(notificaciones: [_n('n1')]),
    );
    await viewModel.cargar();
    SharedPreferencesStorePlatform.instance = _AlmacenQueFalla();

    await viewModel.marcarLeida('n1');

    // El estado en memoria se actualiza igual (la UI ya lo mostro como
    // leido) aunque la persistencia haya fallado -- lo que prueba este
    // test es que marcarLeida() no propago la excepcion sin capturar.
    expect(viewModel.estaLeida('n1'), isTrue);
  });
}
