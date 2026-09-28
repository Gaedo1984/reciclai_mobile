import 'package:flutter/material.dart';

import '../../../core/spacing.dart';

class TourTriggerButton extends StatefulWidget {
  const TourTriggerButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<TourTriggerButton> createState() => _TourTriggerButtonState();
}

class _TourTriggerButtonState extends State<TourTriggerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  late final Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _escala = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controlador, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _escala,
      child: Material(
        color: esquema.secondaryContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          key: const Key('tour-trigger-button'),
          onTap: widget.onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: espacioSm, vertical: espacioXs),
            child: Icon(Icons.tips_and_updates_outlined, color: esquema.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}
