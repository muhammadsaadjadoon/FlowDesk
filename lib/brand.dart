import 'package:flutter/material.dart';

/// Shows the original central brand tile without its outer white canvas.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Flow Desk logo',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .23),
      child: SizedBox.square(
        dimension: size,
        child: OverflowBox(
          alignment: Alignment.center,
          minWidth: size * 2.16,
          maxWidth: size * 2.16,
          minHeight: size * 2.16,
          maxHeight: size * 2.16,
          child: Image.asset('assets/logo.png', fit: BoxFit.fill),
        ),
      ),
    ),
  );
}
