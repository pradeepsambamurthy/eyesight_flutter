// lib/screens/app_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/report_service.dart';
import 'acuity_test_screen.dart';
import 'report_screen.dart';
import 'login_screen.dart';

enum AppSection { home, howto, about, test, report }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab});
  final AppSection? initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  late final TabController _tab;
  bool _showLogin = false;
  int? _pendingTabAfterLogin;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    if (widget.initialTab != null) _tab.index = widget.initialTab!.index;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null && _showLogin) {
        setState(() => _showLogin = false);
        if (_pendingTabAfterLogin != null) {
          _tab.animateTo(_pendingTabAfterLogin!);
          _pendingTabAfterLogin = null;
        }
      } else {
        setState(() {}); // refresh account icon
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _goHome() => _tab.animateTo(0);
  void _openLoginInline({int? goToTabAfter}) {
    setState(() {
      _pendingTabAfterLogin = goToTabAfter;
      _showLogin = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: const Color(0xFF1E60E6),
        foregroundColor: Colors.white,
        title: const _BrandTitle(),
        actions: [
          if (user == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => _openLoginInline(),
                icon: const Icon(Icons.login),
                label: const Text('Sign in'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                tooltip: user.email ?? 'Account',
                icon: const Icon(Icons.account_circle, color: Colors.white),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'email',
                    enabled: false,
                    child: Text(user.email ?? 'Signed in'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'signout',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.logout),
                      title: Text('Sign out'),
                    ),
                  ),
                ],
                onSelected: (v) async {
                  if (v == 'signout') {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Signed out')));
                    _goHome();
                  }
                },
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF2F7AF7),
            child: TabBar(
              controller: _tab,
              onTap: (i) {
                if (i == 3 && FirebaseAuth.instance.currentUser == null) {
                  _openLoginInline(goToTabAfter: 3);
                  _tab.animateTo(_tab.index);
                } else {
                  _tab.animateTo(i);
                }
              },
              indicator: BoxDecoration(
                color: const Color(0xFF1E60E6),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.92),
              tabs: const [
                Tab(icon: Icon(Icons.home_outlined), text: 'Home'),
                Tab(icon: Icon(Icons.menu_book_outlined), text: 'How to Use'),
                Tab(icon: Icon(Icons.info_outline), text: 'About'),
                Tab(icon: Icon(Icons.visibility_outlined), text: 'Test'),
                Tab(icon: Icon(Icons.description_outlined), text: 'Report'),
              ],
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/eye_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.18),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: TabBarView(
              controller: _tab,
              physics: FirebaseAuth.instance.currentUser == null
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: const [
                _HomeContent(),
                _HowToContent(),
                _AboutContent(),
                _TestContent(), // <— renders AcuityTestScreen (new UI)
                _ReportTab(),
              ],
            ),
          ),

          if (_showLogin) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showLogin = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(color: Colors.black.withOpacity(0.20)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Sign in / Sign up',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () =>
                                    setState(() => _showLogin = false),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          LoginFormEmbedded(
                            onSuccess: () {
                              setState(() => _showLogin = false);
                              if (_pendingTabAfterLogin != null) {
                                _tab.animateTo(_pendingTabAfterLogin!);
                                _pendingTabAfterLogin = null;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signed in successfully'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),

      bottomNavigationBar: Container(
        color: const Color(0xFF1E60E6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '© Vision Screener',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Text('v1.0.0', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Small widgets ----------
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.visibility, color: Colors.white),
        SizedBox(width: 10),
        Text(
          'Vision Screener',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Welcome',
              style: t.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Use this app to quickly screen visual acuity at distance and near.',
              style: t.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToContent extends StatelessWidget {
  const _HowToContent();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget dot(String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.white)),
          Expanded(
            child: Text(
              s,
              style: text.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'How to Use This Test',
              style: text.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            dot(
              'Distance test: stand ~3 m (10 ft). Near test: hold ~40 cm (16″).',
            ),
            dot('Test one eye at a time; cover the other without pressure.'),
            dot(
              'Read the 5 letters on each line; ≥3/5 counts as passing a line.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'About the App',
              style: text.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white.withOpacity(0.18),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: const ListTile(
                leading: Icon(Icons.rule, color: Colors.white),
                title: Text(
                  'Age-Adjusted Hints',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'We compare distance and near results to age norms to hint at myopia/presbyopia.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestContent extends StatelessWidget {
  const _TestContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            color: Colors.white.withOpacity(0.12),
            elevation: 0,
            margin: const EdgeInsets.all(8),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: AcuityTestScreen(), // NEW screen
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: Colors.white.withOpacity(0.12),
            elevation: 0,
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(padding: EdgeInsets.all(12), child: ReportBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
