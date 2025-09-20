// lib/screens/app_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens / widgets
import 'acuity_test_screen.dart';
import 'report_screen.dart'; // must export ReportBody (content-only)
import 'login_screen.dart'; // must export LoginFormEmbedded

enum AppSection { home, howto, about, test, report }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab});
  final AppSection? initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  late final TabController _tab;

  bool _showLogin = false; // inline overlay visibility
  int? _pendingTabAfterLogin; // where to go after successful login

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    if (widget.initialTab != null) _tab.index = widget.initialTab!.index;

    // Close login overlay and continue to requested tab after sign in
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null && _showLogin) {
        setState(() => _showLogin = false);
        if (_pendingTabAfterLogin != null) {
          _tab.animateTo(_pendingTabAfterLogin!);
          _pendingTabAfterLogin = null;
        }
      } else {
        // Refresh account display state (avatar menu vs Sign in)
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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
      // ================== HEADER ==================
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: const Color(0xFF1E60E6),
        foregroundColor: Colors.white,
        elevation: 0,
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
                    _tab.animateTo(0);
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
                // Gate the Test tab (index 3) behind login
                if (i == 3 && FirebaseAuth.instance.currentUser == null) {
                  _openLoginInline(goToTabAfter: 3);
                  _tab.animateTo(_tab.index); // stay on current tab
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

      // ================== BODY ==================
      body: Stack(
        children: [
          // 1) Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/eye_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // 2) Soft wash for readability (subtle blur + darker scrim)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: const SizedBox(),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.38),
                          Colors.black.withOpacity(0.62),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3) Pages
          Positioned.fill(
            child: TabBarView(
              controller: _tab,
              physics: FirebaseAuth.instance.currentUser == null
                  ? const NeverScrollableScrollPhysics()
                  : null,
              children: [
                _HomeContent(
                  onStartTest: () {
                    if (FirebaseAuth.instance.currentUser == null) {
                      _openLoginInline(goToTabAfter: 3);
                    } else {
                      _tab.animateTo(3);
                    }
                  },
                ),
                _HowToContent(
                  onGoTest: () {
                    if (FirebaseAuth.instance.currentUser == null) {
                      _openLoginInline(goToTabAfter: 3);
                    } else {
                      _tab.animateTo(3);
                    }
                  },
                ),
                const _AboutContent(),
                TestContent(
                  onRequestLogin: () => _openLoginInline(goToTabAfter: 3),
                ),
                const _ReportTab(), // ✅ now implemented below
              ],
            ),
          ),

          // 4) Login overlay under header
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
                                    fontSize: 20,
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

      // ================== FOOTER ==================
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

// ================== Small widgets ==================
class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final titleSize = w >= 1200
        ? 24.0
        : w >= 800
        ? 22.0
        : 20.0;
    final iconSize = w >= 1200
        ? 26.0
        : w >= 800
        ? 24.0
        : 22.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility, color: Colors.white, size: iconSize),
        const SizedBox(width: 10),
        Text(
          'Vision Screener',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: titleSize,
            letterSpacing: 0.3,
            height: 1.1,
            shadows: [
              Shadow(
                blurRadius: 3,
                color: Colors.black.withOpacity(0.35),
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================
// HOME
// ======================================================================
class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.onStartTest});
  final VoidCallback onStartTest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Welcome',
              style: text.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quickly screen visual acuity at distance and near — similar to a traditional eye chart. '
              'The app helps flag potential patterns like short-sight (myopia) and long-sight/presbyopia, '
              'and highlights large differences between eyes. This is a screening tool, not a diagnosis.',
              style: text.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.97),
                fontWeight: FontWeight.w600,
                fontSize: 20,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // Quick actions
            Row(
              children: [
                SizedBox(
                  width: 240,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Test'),
                    onPressed: onStartTest,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),

            const SizedBox(height: 24),

            // Feature cards
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _TwoTestsCard(),
                _InfoCard(
                  icon: Icons.rule,
                  title: 'Age-aware guidance',
                  body:
                      'We compare your results with age norms and provide plain-language hints.',
                ),
                _InfoCard(
                  icon: Icons.compare_arrows,
                  title: 'Inter-eye difference',
                  body:
                      'Large gaps between right and left vision are flagged for follow-up.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _Section(
              title: 'What you’ll need',
              children: const [
                _Bullet('A quiet, well-lit room.'),
                _Bullet('A phone, tablet, or laptop with this page open.'),
                _Bullet(
                  'A helper if possible (records answers and watches distance).',
                ),
                _Bullet(
                  'Your usual glasses/contacts if you normally use them.',
                ),
              ],
            ),

            _Section(
              title: 'How it works',
              children: const [
                _Bullet('Pick Distance (~3 m / 10 ft) or Near (~40 cm / 16″).'),
                _Bullet(
                  'Cover one eye without pressing on it; read 5 letters per line.',
                ),
                _Bullet(
                  'If you can read the line, tap “I can Read”; otherwise tap “I Can’t read”.',
                ),
                _Bullet(
                  'The app switches eyes automatically and saves results.',
                ),
                _Bullet('A shareable report is generated in the Report tab.'),
              ],
            ),

            _Section(
              title: 'Tips for accurate results',
              children: const [
                _Bullet(
                  'Keep the required distance steady; avoid screen glare.',
                ),
                _Bullet('Hold the device at eye level.'),
                _Bullet('Wear your regular correction if used daily.'),
                _Bullet(
                  'If letters look doubled or distorted, consider a full exam.',
                ),
              ],
            ),

            _Section(
              title: 'FAQ',
              children: const [
                _FaqItem(
                  q: 'Is this a diagnosis?',
                  a: 'No—this is a screening. If you have symptoms or concerns, see an eye-care professional.',
                ),
                _FaqItem(
                  q: 'What is short-sight (myopia)?',
                  a: 'Far objects can look blurry while near objects are clearer. The Distance test (~3 m / 10 ft) helps screen for this.',
                ),
                _FaqItem(
                  q: 'What is long-sight (hyperopia/presbyopia)?',
                  a: 'Far is usually clear but reading up close can be tiring or blurry. The Near test (~40 cm / 16″) helps screen for this.',
                ),
                _FaqItem(
                  q: 'What does “20/20” mean?',
                  a: 'It’s a standard measure at 20 feet. 20/20 is “normal”; 20/40 means letters must be twice as large; 20/16 is better than average.',
                ),
              ],
            ),

            const SizedBox(height: 12),
            const _DisclaimerCard(),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Card(
        color: Colors.white.withOpacity(0.24),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 8),
              const Text(
                'Age-aware guidance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.20),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.white)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w600,
                fontSize: 20,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.q, required this.a});
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.white24),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        textColor: Colors.white,
        collapsedTextColor: Colors.white,
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        title: Text(
          q,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                a,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.16),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Disclaimer: Screening only — not a diagnosis. If you have symptoms, eye strain, '
          'or concerns about your vision, please consult an eye-care professional.',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TwoTestsCard extends StatelessWidget {
  const _TwoTestsCard();

  @override
  Widget build(BuildContext context) {
    final bodyColor = Colors.white.withOpacity(0.95);
    const titleStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 20,
    );

    TextSpan bulletLine({
      required String lead,
      required String mid,
      required Color midColor,
      required String tail,
    }) {
      return TextSpan(
        children: [
          const TextSpan(
            text: '•  ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          TextSpan(
            text: lead,
            style: TextStyle(
              color: bodyColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: mid,
            style: TextStyle(
              color: midColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: tail,
            style: TextStyle(
              color: bodyColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: '\n\n'),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
      child: Card(
        color: Colors.white.withOpacity(0.24),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
              const SizedBox(height: 8),
              const Text('Two test types', style: titleStyle),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: bodyColor, height: 1.35),
                  children: [
                    bulletLine(
                      lead: 'Distance test (≈3 m / 10 ft): screens for ',
                      mid: 'short-sight',
                      midColor: const Color(0xFF64B5F6),
                      tail:
                          ' (myopia). Near things (books/phone) look clear; far things (signs) can be blurry.',
                    ),
                    bulletLine(
                      lead: 'Near test (≈40 cm / 16″): screens for ',
                      mid: 'long-sight',
                      midColor: const Color(0xFFFFCC80),
                      tail:
                          ' (hyperopia/presbyopia). Far is clear; up-close reading can be tiring or blurry.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// HOW TO USE
// ======================================================================
class _HowToContent extends StatelessWidget {
  const _HowToContent({required this.onGoTest});
  final VoidCallback onGoTest;

  Widget step({required int n, required String title, required String body}) {
    return Card(
      color: Colors.white.withOpacity(0.16),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.22),
          foregroundColor: Colors.white,
          child: Text(
            '$n',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: Colors.white)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: 20,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 220,
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Go to Test'),
                  onPressed: onGoTest,
                ),
              ),
            ),
            const SizedBox(height: 12),

            step(
              n: 1,
              title: 'Prepare the space',
              body:
                  'Choose a well-lit room. Reduce glare on the screen and keep the device at eye level.',
            ),
            step(
              n: 2,
              title: 'Pick a test',
              body:
                  'Distance (~3 m / 10 ft) screens short-sight (myopia). Near (~40 cm / 16″) screens long-sight/reading (hyperopia/presbyopia).',
            ),
            step(
              n: 3,
              title: 'For Distance, use a helper if you can',
              body:
                  'A helper can measure ~3 m (10 ft), hold the device steady, and record your answers. This makes the test easier and more accurate.',
            ),
            step(
              n: 4,
              title: 'Cover the opposite eye',
              body:
                  'When testing the RIGHT eye, cover your LEFT eye. When testing the LEFT eye, cover your RIGHT eye. Avoid pressing on the covered eye.',
            ),
            step(
              n: 5,
              title: 'Read 5 letters per line',
              body:
                  'Say the letters out loud. Tap “I Can Read” to move to the next (smaller) line. Tap “I Can’t Read” — the test will switch to the other eye, or if both eyes are done, it will generate your report and take you to the Report page automatically.',
            ),
            step(
              n: 6,
              title: 'You’re done',
              body:
                  'After both eyes are tested, your report is generated automatically and you will be taken to the Report page.',
            ),
            const SizedBox(height: 10),

            Card(
              color: Colors.white.withOpacity(0.12),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Do & Don’t',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    bullet(
                      'Do keep distance consistent (3 m for Distance, 40 cm for Near).',
                    ),
                    bullet(
                      'Do wear your usual glasses/contacts if you normally use them.',
                    ),
                    bullet(
                      'Don’t squint or lean forward while reading the letters.',
                    ),
                    bullet(
                      'Stop if you experience eye strain or double vision and consider a full exam.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// ABOUT
// ======================================================================
class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget section(String title, List<Widget> children) => Card(
      color: Colors.white.withOpacity(0.12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );

    Widget bullet(String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•  ',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          Expanded(
            child: Text(
              s,
              style: textTheme.bodyLarge?.copyWith(
                color: Colors.white.withOpacity(0.95),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.35,
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
            section("Our Approach", [
              bullet(
                "Unlike most apps that focus only on prescription renewals, our app takes the doctor’s approach to testing vision.",
              ),
              bullet(
                "We simulate the step-by-step process of a real eye exam, showing letter lines like a Snellen chart.",
              ),
              bullet(
                "We keep things simple and user-friendly with larger text options and clear guides.",
              ),
              bullet(
                "We provide reports and educational insights so users understand their results.",
              ),
              bullet("Our app is available on iOS, Android, and the web."),
            ]),
            section("The Future", [
              bullet(
                "Integrate AI to help detect signs of common eye conditions like diabetic retinopathy or glaucoma.",
              ),
              bullet(
                "Offer community screening tools for schools, NGOs, and rural clinics.",
              ),
              bullet(
                "Create a gamified experience for children to make screening fun.",
              ),
              bullet(
                "Partner with healthcare providers to bridge screening and professional care.",
              ),
            ]),
            Card(
              color: Colors.white.withOpacity(0.14),
              margin: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "✨ In short, we’re not just building an app — we’re building a future where eye health is accessible, proactive, and preventive.",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== TEST + REPORT TABS ==================
class TestContent extends StatelessWidget {
  const TestContent({required this.onRequestLogin});
  final VoidCallback onRequestLogin;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Not signed in → block access and show a sign-in card
    if (user == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            color: Colors.white.withOpacity(0.12),
            elevation: 0,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign in required',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please sign in to run the vision test.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onRequestLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in / Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Signed in → show the real test UI
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            color: Colors.white.withOpacity(0.12),
            elevation: 0,
            margin: const EdgeInsets.all(8),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: AcuityTestScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== REPORT TAB ==================
// This was missing before and would cause a compile error.
// It uses ReportBody from report_screen.dart.
class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Card(
            color: Colors.white.withOpacity(0.12),
            elevation: 0,
            margin: const EdgeInsets.all(8),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: ReportBody(),
            ),
          ),
        ),
      ),
    );
  }
}
