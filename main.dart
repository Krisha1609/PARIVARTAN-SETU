import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'core/core.dart';

void main() => runApp(const ParivartanSetu());

class ParivartanSetu extends StatelessWidget {
  const ParivartanSetu({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: langNotifier,
        builder: (_, __, ___) => MaterialApp(
            title: 'Parivartan-Setu', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const SplashScreen()),
      );
}

void go(BuildContext c, Widget w, {bool replace = false}) {
  final r = PageRouteBuilder(
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child));
  replace ? Navigator.pushReplacement(c, r) : Navigator.push(c, r);
}

// ---------- REUSABLE WIDGETS ----------
class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  const SoftCard({super.key, required this.child, this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 1.5,
          shadowColor: C.forest.withOpacity(.15),
          child: InkWell(
              borderRadius: BorderRadius.circular(20), onTap: onTap,
              child: Padding(padding: const EdgeInsets.all(16), child: child)),
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)));
}

class SpeakerButton extends StatelessWidget {
  const SpeakerButton({super.key});
  // TODO: connect flutter_tts for Hindi/Marathi/English audio.
  @override
  Widget build(BuildContext context) => IconButton(icon: const Icon(Icons.volume_up_rounded), onPressed: () {});
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ConnectivityResult>>(
        stream: Connectivity().onConnectivityChanged,
        builder: (_, s) {
          final off = s.hasData && s.data!.contains(ConnectivityResult.none);
          return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: off
                  ? Container(
                      width: double.infinity, color: C.warn,
                      padding: const EdgeInsets.all(10),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cloud_off, color: Colors.white, size: 20), SizedBox(width: 8),
                        Text('OFFLINE MODE – data saved on phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ]))
                  : const SizedBox.shrink());
        },
      );
}

Widget stateView<T>(AsyncSnapshot<T> s, Widget Function(T) ok, {String empty = 'Nothing here yet'}) {
  if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: C.primary));
  if (s.hasError) return Center(child: Text('Could not load. Please retry.\n${s.error}', textAlign: TextAlign.center));
  return ok(s.data as T);
}

// ---------- SPLASH ----------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), () => mounted ? go(context, const LanguageScreen(), replace: true) : null);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RotationTransition(
                turns: _c,
                child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(color: C.card, shape: BoxShape.circle),
                    child: const Icon(Icons.recycling_rounded, size: 84, color: C.primary))),
            const SizedBox(height: 28),
            Text('PARIVARTAN-SETU', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text('From Informal Collection to Formal Recycling',
                    textAlign: TextAlign.center, style: TextStyle(color: C.earth, fontSize: 16))),
          ]),
        ),
      );
}

// ---------- LANGUAGE ----------
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 24),
              Text('भाषा चुनें / भाषा निवडा\nChoose Language', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              for (final l in [('hi', 'हिंदी'), ('mr', 'मराठी'), ('en', 'English')])
                SoftCard(
                    color: C.card,
                    onTap: () {
                      langNotifier.value = l.$1;
                      go(context, const LoginScreen());
                    },
                    child: Row(children: [
                      const Icon(Icons.translate, color: C.forest, size: 32), const SizedBox(width: 16),
                      Text(l.$2, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.forest)),
                      const Spacer(), const Icon(Icons.chevron_right, color: C.forest),
                    ])),
            ]),
          ),
        ),
      );
}

// ---------- OTP LOGIN ----------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final phone = TextEditingController(), otp = TextEditingController();
  bool sent = false, busy = false;

  // TODO: replace with FirebaseAuth.instance.verifyPhoneNumber(...) and PhoneAuthProvider.credential(...)
  Future<void> _send() async {
    if (phone.text.length != 10) return;
    setState(() => busy = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() { sent = true; busy = false; });
  }

  Future<void> _verify() async {
    if (otp.text.length != 6) return;
    setState(() => busy = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) go(context, const CollectorShell(), replace: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Login', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Enter your mobile number. We will send a 6-digit OTP.'),
            const SizedBox(height: 24),
            TextField(
                controller: phone, keyboardType: TextInputType.phone, maxLength: 10, style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(prefixText: '+91  ', prefixIcon: Icon(Icons.phone_android), hintText: 'Phone Number', counterText: '')),
            if (sent) ...[
              const SizedBox(height: 16),
              TextField(
                  controller: otp, keyboardType: TextInputType.number, maxLength: 6,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), hintText: 'OTP', counterText: '')),
            ],
            const SizedBox(height: 24),
            FilledButton(
                onPressed: busy ? null : (sent ? _verify : _send),
                child: busy ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : Text(sent ? 'Verify OTP' : 'Send OTP')),
          ]),
        ),
      );
}

// ---------- SHELL / NAVIGATION ----------
class CollectorShell extends StatefulWidget {
  const CollectorShell({super.key});
  @override
  State<CollectorShell> createState() => _ShellState();
}

class _ShellState extends State<CollectorShell> {
  int i = 0;
  final pages = const [HomeScreen(), LotsScreen(), PricesScreen(), EarningsScreen()];

  Widget _nav(IconData icon, String label, int idx) => Expanded(
        child: InkWell(
          onTap: () => setState(() => i = idx),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 28, color: i == idx ? C.forest : C.earth),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400, color: i == idx ? C.forest : C.earth)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Column(children: [const OfflineBanner(), Expanded(child: pages[i])])),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: FloatingActionButton.large(
            backgroundColor: C.forest, foregroundColor: Colors.white, shape: const CircleBorder(),
            onPressed: () => go(context, const AddEwasteScreen()), child: const Icon(Icons.add_a_photo_rounded, size: 34)),
        bottomNavigationBar: BottomAppBar(
          color: Colors.white, shape: const CircularNotchedRectangle(), notchMargin: 8,
          child: Row(children: [
            _nav(Icons.home_rounded, 'Home', 0), _nav(Icons.inventory_2_rounded, 'Lots', 1),
            const Spacer(),
            _nav(Icons.sell_rounded, 'Prices', 2), _nav(Icons.account_balance_wallet_rounded, 'Earnings', 3),
          ]),
        ),
      );
}

// ---------- HOME ----------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([lotStore, langNotifier]),
        builder: (_, __) {
          final active = lotStore.lots.where((l) => l.status != LotStatus.completed).length;
          final done = lotStore.lots.where((l) => l.status == LotStatus.completed).length;
          return ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tr('hello')} 👋', style: const TextStyle(color: C.earth, fontSize: 16)),
                Text('Collector', style: Theme.of(context).textTheme.headlineMedium),
              ])),
              const SpeakerButton(),
              PopupMenuButton<String>(
                  icon: const Icon(Icons.translate), onSelected: (v) => langNotifier.value = v,
                  itemBuilder: (_) => const [
                        PopupMenuItem(value: 'hi', child: Text('हिंदी')),
                        PopupMenuItem(value: 'mr', child: Text('मराठी')),
                        PopupMenuItem(value: 'en', child: Text('English'))]),
              const CircleAvatar(backgroundColor: C.card, child: Icon(Icons.person, color: C.forest)),
            ]),
            const SizedBox(height: 16),
            SoftCard(
                color: C.forest,
                onTap: () => go(context, const AddEwasteScreen()),
                child: Row(children: [
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 40), const SizedBox(width: 16),
                  Text('+ ${tr('add')}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                ])),
            const SizedBox(height: 8),
            Row(children: [
              _quick(context, Icons.sell_rounded, tr('prices'), const PricesScreen(standalone: true)),
              _quick(context, Icons.inventory_2_rounded, tr('lots'), const LotsScreen(standalone: true)),
              _quick(context, Icons.account_balance_wallet_rounded, tr('earn'), const EarningsScreen(standalone: true)),
              _quick(context, Icons.health_and_safety_rounded, 'Safety', const SafetyScreen()),
            ]),
            const SizedBox(height: 16),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5, mainAxisSpacing: 12, crossAxisSpacing: 12, children: [
              _stat('Active Lots', '$active', Icons.inventory_2_outlined),
              _stat('Completed', '$done', Icons.check_circle_outline),
              _stat('Total Earnings', '₹0', Icons.currency_rupee),
              _stat('Pending Payments', '₹0', Icons.hourglass_bottom),
            ]),
          ]);
        },
      );

  Widget _quick(BuildContext c, IconData ic, String label, Widget page) => Expanded(
        child: InkWell(
          onTap: () => go(c, page),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: [
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18)), child: Icon(ic, color: C.forest, size: 28)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Widget _stat(String l, String v, IconData ic) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(ic, color: C.primary),
        Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: C.forest)),
        Text(l, style: const TextStyle(color: C.earth)),
      ]));
}

// ---------- ADD E-WASTE + PRICE ESTIMATE + LOT ----------
class AddEwasteScreen extends StatefulWidget {
  const AddEwasteScreen({super.key});
  @override
  State<AddEwasteScreen> createState() => _AddState();
}

class _AddState extends State<AddEwasteScreen> {
  String? path, material;
  double? confidence;
  bool analyzing = false, pricing = false;
  PriceQuote? quote;
  String? error;
  final weight = TextEditingController();
  static const location = 'Panvel'; // TODO: geolocator

  Future<void> _pick(ImageSource s) async {
    final f = await ImagePicker().pickImage(source: s, imageQuality: 70);
    if (f == null) return;
    setState(() { path = f.path; analyzing = true; error = null; quote = null; });
    try {
      final r = await Services.classifier.classify(f.path);
      setState(() { material = r.material; confidence = r.confidence; });
    } catch (e) {
      setState(() => error = 'Could not analyze photo. Choose the material yourself.');
    }
    setState(() => analyzing = false);
  }

  Future<void> _estimate() async {
    final kg = double.tryParse(weight.text);
    if (material == null || kg == null || kg <= 0) return;
    setState(() { pricing = true; error = null; });
    try {
      quote = await Services.pricing.estimate(material!, kg, location);
    } catch (e) {
      error = 'Price not available right now.';
    }
    setState(() => pricing = false);
  }

  void _createLot() {
    final lot = Lot(id: LotStore.newId(), material: material!, weight: double.parse(weight.text), location: location, photoPath: path, quote: quote);
    lotStore.add(lot); // TODO: write to SQLite, then SyncManager pushes to FastAPI
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lot created: ${lot.id}')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('add'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            height: 200, clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(24)),
            child: path == null
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_camera_outlined, size: 64, color: C.primary), SizedBox(height: 8), Text('Take a photo of your material')])
                : Image.file(File(path!), fit: BoxFit.cover, width: double.infinity),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Take Photo'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)), onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Gallery'))),
          ]),
          const SizedBox(height: 16),
          if (analyzing) const SoftCard(child: Row(children: [CircularProgressIndicator(color: C.primary), SizedBox(width: 16), Text('Analyzing Material…', style: TextStyle(fontSize: 18))])),
          if (confidence != null)
            SoftCard(color: C.card, child: Row(children: [
              const Icon(Icons.auto_awesome, color: C.forest), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(material!, style: Theme.of(context).textTheme.titleMedium),
                Text('${(confidence! * 100).round()}% confidence · AI suggestion, you can change it', style: const TextStyle(color: C.earth)),
              ])),
            ])),
          if (error != null) SoftCard(color: const Color(0xFFFBEBD6), child: Text(error!)),
          Text('Material', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in materials)
              ChoiceChip(
                  label: Text(m, style: const TextStyle(fontSize: 15)), selected: material == m,
                  selectedColor: C.primary.withOpacity(.4), padding: const EdgeInsets.all(8),
                  onSelected: (_) => setState(() { material = m; quote = null; })),
          ]),
          const SizedBox(height: 16),
          TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 22),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.scale), suffixText: 'kg', hintText: 'Approximate Weight')),
          const SizedBox(height: 16),
          if (quote == null)
            FilledButton(onPressed: pricing ? null : _estimate, child: pricing ? const CircularProgressIndicator(color: Colors.white) : const Text('Get Estimated Price'))
          else ...[
            SoftCard(color: C.card, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$material · ${weight.text} kg', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Estimated Value', style: TextStyle(color: C.earth)),
              Text(quote!.range, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: C.forest)),
              const SizedBox(height: 8),
              Text('${quote!.band} · ${quote!.location}', style: const TextStyle(color: C.earth)),
            ])),
            FilledButton(onPressed: _createLot, child: const Text('Create Digital Lot')),
          ],
        ]),
      );
}

// ---------- LOTS ----------
class LotsScreen extends StatelessWidget {
  final bool standalone;
  const LotsScreen({super.key, this.standalone = false});

  static const _label = {
    LotStatus.available: ('Available', C.primary),
    LotStatus.offerReceived: ('Offer Received', C.warn),
    LotStatus.handoverPending: ('Handover Pending', C.earth),
    LotStatus.completed: ('Completed', C.forest),
  };

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: lotStore,
      builder: (_, __) => lotStore.lots.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inventory_2_outlined, size: 72, color: C.primary), SizedBox(height: 12),
              Text('No lots yet. Tap the camera button to add your first e-waste.', textAlign: TextAlign.center)])))
          : ListView(padding: const EdgeInsets.all(20), children: [
              for (final l in lotStore.lots)
                SoftCard(child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14),
                      child: l.photoPath != null ? Image.file(File(l.photoPath!), width: 64, height: 64, fit: BoxFit.cover)
                          : const Icon(Icons.recycling, size: 48, color: C.primary)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.id, style: const TextStyle(fontWeight: FontWeight.w700, color: C.forest)),
                    Text('${l.material} · ${l.weight} kg'),
                    Text(l.quote?.range ?? '—', style: const TextStyle(color: C.earth)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      StatusChip(_label[l.status]!.$1, _label[l.status]!.$2),
                      if (!l.synced) const StatusChip('Saved on phone', C.warn),
                    ]),
                  ])),
                ])),
            ]),
    );
    return standalone ? Scaffold(appBar: AppBar(title: Text(tr('lots'))), body: body) : Column(children: [_title(context, tr('lots')), Expanded(child: body)]);
  }
}

Widget _title(BuildContext c, String t) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Align(alignment: Alignment.centerLeft, child: Text(t, style: Theme.of(c).textTheme.headlineMedium)));

// ---------- PRICE BOARD ----------
class PricesScreen extends StatefulWidget {
  final bool standalone;
  const PricesScreen({super.key, this.standalone = false});
  @override
  State<PricesScreen> createState() => _PricesState();
}

class _PricesState extends State<PricesScreen> {
  late Future<List<PriceRow>> f = Services.priceBoard.prices();
  String q = '';
  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: TextField(onChanged: (v) => setState(() => q = v.toLowerCase()), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search material'))),
      Expanded(child: FutureBuilder<List<PriceRow>>(future: f, builder: (_, s) => stateView<List<PriceRow>>(s, (rows) {
        final r = rows.where((e) => e.material.toLowerCase().contains(q)).toList();
        if (r.isEmpty) return const Center(child: Text('No prices found'));
        return ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
          for (final p in r)
            SoftCard(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.material, style: Theme.of(context).textTheme.titleMedium),
                Text('Range ₹${p.min.round()} – ₹${p.max.round()} · ${p.location}', style: const TextStyle(color: C.earth)),
                Text('Updated: ${p.updated}', style: const TextStyle(fontSize: 12, color: C.earth)),
              ])),
              Column(children: [Text('₹${p.rate.round()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.forest)), const Text('per kg', style: TextStyle(fontSize: 12))]),
              const SpeakerButton(),
            ])),
        ]);
      }))),
    ]);
    return widget.standalone ? Scaffold(appBar: AppBar(title: Text(tr('prices'))), body: body) : Column(children: [_title(context, 'Price Board'), Expanded(child: body)]);
  }
}

// ---------- EARNINGS ----------
class EarningsScreen extends StatelessWidget {
  final bool standalone;
  const EarningsScreen({super.key, this.standalone = false});
  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<Earning>>(future: Services.earnings.earnings(), builder: (_, s) => stateView<List<Earning>>(s, (rows) => ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Expanded(child: _box('Paid', '₹0', C.card)), const SizedBox(width: 12), Expanded(child: _box('Pending', '₹0', const Color(0xFFF3ECDD))),
      ]),
      const SizedBox(height: 20),
      if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Column(children: [Icon(Icons.account_balance_wallet_outlined, size: 64, color: C.primary), SizedBox(height: 8), Text('Completed handovers will show here.')])),
      for (final e in rows) SoftCard(child: Row(children: [Expanded(child: Text('${e.material} · ${e.recycler}')), Text('₹${e.amount.round()}')])),
    ])));
    return standalone ? Scaffold(appBar: AppBar(title: Text(tr('earn'))), body: body) : Column(children: [_title(context, tr('earn')), Expanded(child: body)]);
  }

  Widget _box(String l, String v, Color c) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: C.earth)), Text(v, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: C.forest))]));
}

// ---------- SAFETY ----------
class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.battery_alert, 'Battery Safety', 'Keep batteries dry and away from heat. Do not puncture or crush.'),
      (Icons.tv, 'CRT Safety', 'Handle screens gently. Glass can break and hold harmful dust.'),
      (Icons.local_fire_department, 'No Open-Air Burning', 'Never burn wires or boards. The smoke is toxic.'),
      (Icons.science, 'No Acid Leaching', 'Do not use acid to extract metals. It harms you and the water.'),
      (Icons.pan_tool, 'Safe Handling', 'Wear gloves and wash hands after handling e-waste.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        for (final i in items)
          SoftCard(color: C.card, child: Row(children: [
            Icon(i.$1, size: 40, color: C.forest), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i.$2, style: Theme.of(context).textTheme.titleMedium), Text(i.$3)])),
            const SpeakerButton(),
          ])),
      ]),
    );
  }
}
