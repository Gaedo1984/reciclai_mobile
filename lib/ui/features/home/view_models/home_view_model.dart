import 'package:flutter/foundation.dart';

/// ViewModel: holds UI state for the Home screen and exposes it to the View.
class HomeViewModel extends ChangeNotifier {
  String get greeting => '¡Hola mundo!';
}
