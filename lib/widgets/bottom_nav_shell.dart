import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/routes.dart';

BottomNavigationBar buildBottomNavBar(BuildContext context, {int currentIndex = 0}) {
  return BottomNavigationBar(
    currentIndex: currentIndex,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppTheme.primaryColor,
    unselectedItemColor: AppTheme.textSecondary,
    onTap: (index) {
      switch (index) {
        case 0:
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
          break;
        case 1:
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.planning, (_) => false);
          break;
        case 2:
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.workout, (_) => false);
          break;
        case 3:
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.nutrition, (_) => false);
          break;
        case 4:
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.profile, (_) => false);
          break;
      }
    },
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Planning'),
      BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workout'),
      BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'Diet'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ],
  );
}
