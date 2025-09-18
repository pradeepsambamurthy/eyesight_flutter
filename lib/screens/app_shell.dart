// lib/screens/app_shell.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// App services (for future PDF/share, optional here)
import '../services/report_service.dart' show ReportService;

// Screens / widgets
import 'acuity_test_screen.dart';
import 'report_screen.dart'; // defines ReportBody (content-only)
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
        setState(() {}); // refresh header account state
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
          // 2) Soft wash for readability
          // NEW: darker scrim + subtle blur = much better contrast
          Positioned.fill(
            child: Stack(
              children: [
                // Very light blur to knock down sparkles behind text
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: const SizedBox(), // required child
                  ),
                ),
                // Dark gradient scrim
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
                const _TestContent(), // <- renders AcuityTestScreen
                const _ReportTab(), // <- shows your ReportBody
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
    // Scale a bit on larger screens
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
            fontWeight: FontWeight.w800,
            fontSize: titleSize, // ⬅️ bigger title
            letterSpacing: 0.3, // small polish
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
            // Hero title
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
              'Quickly screen visual acuity at **distance** and **near** — similar to a '
              'traditional eye chart. The app helps flag potential patterns like short-sight '
              '(myopia) and long-sight/presbyopia, and highlights large differences between eyes. '
              'This is a screening tool, not a diagnosis.',
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
                TextButton.icon(
                  icon: const Icon(
                    Icons.menu_book_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'How to Use',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () =>
                      DefaultTabController.of(context)?.animateTo(1),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Three feature cards
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _InfoCard(
                  icon: Icons.remove_red_eye_outlined,
                  title: 'Two test types',
                  body:
                      '• Distance (≈3 m / 10 ft): screens for short-sight (myopia)\n'
                      '• Near (≈40 cm / 16″): screens for long-sight/reading (hyperopia/presbyopia)',
                ),
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
                _Bullet(
                  'Pick **Distance** (~3 m / 10 ft) or **Near** (~40 cm / 16″).',
                ),
                _Bullet(
                  'Cover one eye without pressing on it; read 5 letters per line.',
                ),
                _Bullet(
                  'If ≥3/5 are correct, mark **Read**; otherwise **Can’t read**.',
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
                  q: 'Why do both Distance and Near?',
                  a:
                      'Distance helps screen short-sight (myopia). Near helps screen long-sight/presbyopia. '
                      'Doing both gives a clearer overall picture.',
                ),
                _FaqItem(
                  q: 'What does 20/20 mean?',
                  a:
                      'It’s a standard measure of clarity at 20 feet. 20/20 is “normal”. '
                      'Smaller denominators like 20/16 indicate better-than-average acuity.',
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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w800,
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
            fontWeight: FontWeight.w800,
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
          'Disclaimer: Screening only—not a diagnosis. If you have symptoms, eye strain, '
          'or concerns about your vision, please consult an eye-care professional.',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget step(int n, String title, String body) => Card(
      color: Colors.white.withOpacity(0.12),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.20),
          child: Text('$n', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        subtitle: Text(
          body,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'How to Use',
              style: text.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 12),
            step(
              1,
              'Prepare the space',
              'Choose a well-lit room. Reduce glare on the screen. Keep the device at eye level.',
            ),
            step(
              2,
              'Pick a test',
              'Distance (~3 m / 10 ft) screens short-sight (myopia). Near (~40 cm / 16″) screens long-sight/presbyopia.',
            ),
            step(
              3,
              'Cover one eye',
              'Cover the non-tested eye with your hand or a card. Avoid pressing on the eye.',
            ),
            step(
              4,
              'Read 5 letters per line',
              'If ≥3/5 are correct, choose “Read”. Otherwise select “Can’t read”. The app advances or stops accordingly.',
            ),
            step(
              5,
              'Switch eyes',
              'The app prompts you to test the other eye, then saves results for both eyes.',
            ),
            step(
              6,
              'View the report',
              'The Report tab shows your overall result, age-aware guidance, and hints. You can share/download it.',
            ),

            const SizedBox(height: 18),

            _Section(
              title: 'Do & Don’t',
              children: const [
                _Bullet(
                  'Do keep distance consistent (3 m for Distance, 40 cm for Near).',
                ),
                _Bullet('Do wear your usual glasses/contacts if used daily.'),
                _Bullet('Don’t squint or move closer to the screen mid-line.'),
                _Bullet('Don’t peek with the covered eye.'),
              ],
            ),

            _Section(
              title: 'Troubleshooting',
              children: const [
                _Bullet(
                  'Letters look too small immediately: confirm the correct test distance.',
                ),
                _Bullet(
                  'Glare or reflections: tilt or dim the screen slightly.',
                ),
                _Bullet(
                  'Helper unavailable: say letters aloud and self-record carefully.',
                ),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Go to Test'),
                onPressed: onGoTest,
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
    final text = Theme.of(context).textTheme;

    Widget info(String title, String body, IconData icon) => Card(
      color: Colors.white.withOpacity(0.18),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        subtitle: Text(
          body,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w600,
            fontSize: 20,
            height: 1.35,
          ),
        ),
      ),
    );

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
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 12),
            info(
              'What it is',
              'A self-administered **visual acuity screener** for distance and near. '
                  'It emulates a standard eye-chart experience with five letters per line and clear pass/fail rules.',
              Icons.visibility_outlined,
            ),
            info(
              'Who it’s for',
              'Anyone who wants a quick at-home screening: students, adults checking clarity with new glasses, '
                  'or caregivers monitoring changes. It is **not** a substitute for professional care.',
              Icons.people_outline,
            ),
            info(
              'What it does',
              '• Estimates acuity (e.g., 20/20, 20/40) for each eye\n'
                  '• Flags large differences between eyes\n'
                  '• Provides age-aware guidance and plain-language hints',
              Icons.rule,
            ),
            info(
              'What it does not do',
              'It does not diagnose disease, replace refraction by an optometrist, or assess eye health (pressure, retina, etc.).',
              Icons.block,
            ),
            info(
              'Methodology (simplified)',
              'You read five letters per line. If you read ≥3/5 correctly, you pass that line and try the next smaller line. '
                  'Your final line corresponds to a **logMAR/Snellen** label (e.g., 0.0 ➜ 20/20). '
                  'Near testing helps screen long-sight/presbyopia; distance helps screen short-sight/myopia.',
              Icons.science_outlined,
            ),
            info(
              'Privacy',
              'If you sign in, basic profile and results can be saved to your account so your report persists. '
                  'You can sign out anytime. No medical diagnosis is stored.',
              Icons.lock_outline,
            ),
            info(
              'When to seek care',
              'If your vision is worse than expected, if eyes differ a lot, or if you notice pain, flashes, floaters, or sudden changes—'
                  'please schedule a comprehensive eye exam.',
              Icons.local_hospital_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// TEST + REPORT TABS
// ======================================================================
class _TestContent extends StatelessWidget {
  const _TestContent();

  @override
  Widget build(BuildContext context) {
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

class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 20,
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
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Your Report', style: titleStyle),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: ReportBody(), // your existing content-only widget
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
