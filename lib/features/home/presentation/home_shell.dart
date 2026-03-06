import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../shared/widgets/layout/bottom_nav_bar.dart';
import '../../analysis/presentation/screens/analysis_screen.dart';
import 'screens/home_screen.dart';
import 'screens/news_screen.dart';
import 'widgets/app_drawer.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.initialIndex});
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomeScreen(),
    AnalysisScreen(),
    SizedBox.shrink(), // AI Chat navigates to separate screen
    NewsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    
    // Navigate to AI Chat as separate screen
    if (index == 2) {
      Navigator.of(context).pushNamed(AppRoutes.aiChat);
      return;
    }

    // For tabs within IndexedStack, just update the index
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _pages),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

