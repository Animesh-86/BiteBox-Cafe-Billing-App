import 'package:flutter/material.dart';

class ResponsiveLayout {
  // Viewport breakpoints for standard Android device dimensions
  static const double mobileLimit = 600.0;
  static const double tabletLimit = 900.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileLimit;
  }

  static bool isTablet(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    return width >= mobileLimit && width < tabletLimit;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletLimit;
  }

  /// Calculates a global text scaler ratio that dynamically adjusts
  /// based on device width to ensure legibility on larger displays.
  static double textScaleFactor(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < mobileLimit) {
      return 1.0; // Standard Mobile Size
    } else if (width < tabletLimit) {
      return 1.15; // +15% Boost on Tablets for legibility at arm's length POS
    } else {
      return 1.25; // +25% Boost on Desktop
    }
  }
}
