import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../advanced/advanced_hub_page.dart';
import '../advanced/patient_360_page.dart';
import '../advanced/search_page.dart';
import '../advanced/settings_page.dart';
import '../ai/ai_page.dart';
import '../appointments/appointments_page.dart';
import '../auth/login_page.dart';
import '../dashboard/dashboard_page.dart';
import '../doctors/doctors_page.dart';
import '../documents/documents_page.dart';
import '../doctor/doctor_dashboard_page.dart';
import '../emergency/emergency_page.dart';
import '../home/role_home_page.dart';
import '../medications/medicine_centre_page.dart';
import '../messages/messages_page.dart';
import '../operations/operations_page.dart';
import '../patients/patients_page.dart';
import '../pharmacy/pharmacy_workspace_page.dart';
import '../records/records_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  bool profileLoading = false;

  static const _adminRoles = {'super administrator', 'hospital administrator'};
  static const _clinicalRoles = {'doctor', 'nurse'};
  static const _frontDeskRoles = {'receptionist'};
  static const _labRoles = {'lab technician'};
  static const _pharmacyRoles = {'pharmacist'};
  static const _billingRoles = {'billing staff'};
  static const _supportRoles = {'support staff'};

  @override
  void initState() {
    super.initState();
    if (Api.currentUser == null) _refreshProfile();
  }

  Set<String> get _roles => Api.roles.map((x) => x.toLowerCase()).toSet();
  bool get _isAdmin => _roles.any(_adminRoles.contains);
  bool _hasAny(Set<String> group) => _isAdmin || _roles.any(group.contains);

  Widget get _homePage {
    if (_roles.contains('doctor')) return const DoctorDashboardPage();
    if (_roles.contains('pharmacist')) return const PharmacyWorkspacePage();
    if (_isAdmin) return const DashboardPage();
    return const RoleHomePage();
  }

  String get _homeLabel {
    if (_roles.contains('doctor')) return 'Doctor home';
    if (_roles.contains('pharmacist')) return 'Pharmacy home';
    if (_roles.contains('lab technician')) return 'Lab home';
    if (_roles.contains('receptionist')) return 'Front desk';
    if (_roles.contains('billing staff')) return 'Billing home';
    if (_roles.contains('nurse')) return 'Nurse home';
    return 'Overview';
  }

  List<_Destination> get destinations {
    final all = <_Destination>[
      _Destination('overview', _homeLabel, Icons.home_rounded, _homePage, visible: true, group: 'Workspace'),
      _Destination('patient360', 'Patient 360°', Icons.hub_outlined, const Patient360Page(), visible: _hasAny(_clinicalRoles), group: 'Care'),
      _Destination('medicines', 'Medicine Centre', Icons.medication_outlined, const MedicineCentrePage(), visible: _hasAny(_clinicalRoles.union(_pharmacyRoles)), group: 'Care'),
      _Destination('patients', 'Patients', Icons.people_alt_outlined, const PatientsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('appointments', 'Appointments', Icons.calendar_month_outlined, const AppointmentsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('doctors', 'Doctors', Icons.medical_services_outlined, const DoctorsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('records', 'Clinical records', Icons.folder_shared_outlined, const RecordsPage(), visible: _hasAny(_clinicalRoles), group: 'Clinical'),
      _Destination('documents', 'Documents & OCR', Icons.document_scanner_outlined, const DocumentsPage(), visible: _hasAny(_clinicalRoles.union(_labRoles)), group: 'Clinical'),
      _Destination('pharmacy', 'Pharmacy', Icons.local_pharmacy_outlined, const PharmacyWorkspacePage(), visible: _hasAny(_pharmacyRoles), group: 'Operations'),
      _Destination('operations', 'Hospital operations', Icons.apartment_outlined, const OperationsPage(), visible: _isAdmin || _hasAny(_frontDeskRoles.union(_pharmacyRoles).union(_billingRoles)), group: 'Operations'),
      _Destination('advanced', 'Care operations', Icons.monitor_heart_outlined, const AdvancedHubPage(), visible: _isAdmin || _hasAny(_labRoles), group: 'Operations'),
      _Destination('ai', 'Clinexa AI', Icons.auto_awesome_outlined, const AiPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles)), group: 'Tools'),
      _Destination('messages', 'Messages', Icons.forum_outlined, const MessagesPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles)), group: 'Tools'),
      _Destination('search', 'Search & command', Icons.search_rounded, const GlobalSearchPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles).union(_billingRoles)), group: 'Tools'),
      _Destination('emergency', 'Emergency Hub', Icons.health_and_safety_outlined, const EmergencyPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Tools', danger: true),
      _Destination('settings', 'Security & settings', Icons.settings_outlined, const AdvancedSettingsPage(), visible: _isAdmin || _hasAny(_supportRoles), group: 'System'),
    ];
    return all.where((x) => x.visible).toList();
  }

  Future<void> _refreshProfile() async {
    setState(() => profileLoading = true);
    try {
      await Api.loadProfile();
      if (!mounted) return;
      setState(() { profileLoading = false; if (index >= destinations.length) index = 0; });
    } catch (_) {
      if (mounted) setState(() => profileLoading = false);
    }
  }

  Future<void> logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void selectPage(int newIndex) {
    if (newIndex < 0 || newIndex >= destinations.length) return;
    setState(() => index = newIndex);
  }

  int? _indexForKey(String key) {
    final i = destinations.indexWhere((x) => x.key == key);
    return i < 0 ? null : i;
  }

  List<_Destination> get _mobilePrimary {
    final wanted = ['overview', 'patient360', 'medicines', 'appointments', 'ai'];
    final result = <_Destination>[];
    for (final key in wanted) {
      final item = destinations.where((x) => x.key == key).firstOrNull;
      if (item != null && result.length < 4) result.add(item);
    }
    for (final item in destinations) {
      if (result.length >= 4) break;
      if (!result.any((x) => x.key == item.key)) result.add(item);
    }
    return result;
  }

  Future<void> showMoreSheet() async {
    final primaryKeys = _mobilePrimary.map((x) => x.key).toSet();
    final more = destinations.where((x) => !primaryKeys.contains(x.key)).toList();
    if (more.isEmpty) return;
    final selectedKey = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 26),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('More Clinexa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Everything else, grouped away from your primary flow.', style: TextStyle(color: ClinexaTheme.muted, fontSize: 11.5)),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(ctx).width > 520 ? 4 : 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .95,
              children: more.map((item) => _MoreTile(item: item)).toList(),
            ),
          ]),
        ),
      ),
    );
    if (selectedKey != null) {
      final selectedIndex = _indexForKey(selectedKey);
      if (selectedIndex != null) selectPage(selectedIndex);
    }
  }

  int get mobileSelectedIndex {
    final currentKey = destinations[index].key;
    final i = _mobilePrimary.indexWhere((x) => x.key == currentKey);
    return i >= 0 ? i : _mobilePrimary.length;
  }

  @override
  Widget build(BuildContext context) {
    final visible = destinations;
    if (visible.isEmpty) return const Scaffold(body: Center(child: Text('No workspace destinations available.')));
    if (index >= visible.length) index = 0;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1120;
    final tablet = width >= 760 && !desktop;
    final primary = _mobilePrimary;

    return Scaffold(
      backgroundColor: ClinexaTheme.canvas,
      drawer: desktop ? null : Drawer(width: 306, backgroundColor: Colors.white, child: _navigation(expanded: true, closeDrawer: true)),
      body: SafeArea(
        child: profileLoading && Api.currentUser == null
            ? const Center(child: CircularProgressIndicator())
            : Row(children: [
                if (desktop) SizedBox(width: 286, child: _navigation(expanded: true)),
                if (tablet) SizedBox(width: 82, child: _navigation(expanded: false)),
                Expanded(
                  child: Column(children: [
                    _TopBar(
                      destination: visible[index],
                      onMenu: desktop || tablet ? null : () => Scaffold.of(context),
                      onSearch: () { final i = _indexForKey('search'); if (i != null) selectPage(i); },
                      onAi: () { final i = _indexForKey('ai'); if (i != null) selectPage(i); },
                      onLogout: logout,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween(begin: const Offset(.015, .01), end: Offset.zero).animate(animation), child: child)),
                        child: KeyedSubtree(key: ValueKey(visible[index].key), child: visible[index].page),
                      ),
                    ),
                  ]),
                ),
              ]),
      ),
      bottomNavigationBar: desktop || tablet
          ? null
          : NavigationBar(
              selectedIndex: mobileSelectedIndex,
              onDestinationSelected: (value) {
                if (value < primary.length) {
                  final selectedIndex = _indexForKey(primary[value].key);
                  if (selectedIndex != null) selectPage(selectedIndex);
                } else {
                  showMoreSheet();
                }
              },
              destinations: [
                ...primary.map((item) => NavigationDestination(selectedIcon: Icon(_selectedIcon(item)), icon: Icon(item.icon), label: _shortLabel(item))),
                const NavigationDestination(selectedIcon: Icon(Icons.grid_view_rounded), icon: Icon(Icons.grid_view_outlined), label: 'More'),
              ],
            ),
    );
  }

  IconData _selectedIcon(_Destination item) {
    switch (item.key) {
      case 'overview': return Icons.home_rounded;
      case 'appointments': return Icons.calendar_month_rounded;
      case 'medicines': return Icons.medication_rounded;
      case 'ai': return Icons.auto_awesome_rounded;
      default: return item.icon;
    }
  }

  String _shortLabel(_Destination item) {
    switch (item.key) {
      case 'patient360': return '360°';
      case 'medicines': return 'Meds';
      case 'appointments': return 'Visits';
      case 'overview': return 'Home';
      case 'ai': return 'AI';
      default: return item.label.split(' ').first;
    }
  }

  Widget _navigation({required bool expanded, bool closeDrawer = false}) {
    final name = Api.currentUser?['full_name']?.toString() ?? 'Clinexa user';
    final roleLabel = Api.roles.isEmpty ? 'Workspace' : Api.roles.join(' • ');
    final groups = <String, List<_Destination>>{};
    for (final item in destinations) { groups.putIfAbsent(item.group, () => []).add(item); }

    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: ClinexaTheme.line))),
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(expanded ? 20 : 13, 18, expanded ? 16 : 13, 13),
            child: Row(mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
              const _BrandMark(),
              if (expanded) ...[
                const SizedBox(width: 11),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Clinexa', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.7, color: ClinexaTheme.navy)),
                  Text('Healthcare OS', style: TextStyle(color: ClinexaTheme.muted, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
                ])),
              ],
            ]),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Divider()),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(expanded ? 12 : 10, 10, expanded ? 12 : 10, 10),
              children: [
                for (final entry in groups.entries) ...[
                  if (expanded) Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 5), child: Text(entry.key.toUpperCase(), style: const TextStyle(color: Color(0xFF9AA6B5), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.15))),
                  ...entry.value.map((item) {
                    final i = destinations.indexWhere((x) => x.key == item.key);
                    final selected = i == index;
                    final tone = item.danger ? ClinexaTheme.emergency : ClinexaTheme.primary;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tooltip(
                        message: expanded ? '' : item.label,
                        child: Material(
                          color: selected ? (item.danger ? ClinexaTheme.rose : ClinexaTheme.mint) : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              selectPage(i);
                              if (closeDrawer && Navigator.canPop(context)) Navigator.pop(context);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0, vertical: 11),
                              child: Row(mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                                Icon(item.icon, size: 20, color: selected ? tone : ClinexaTheme.muted),
                                if (expanded) ...[
                                  const SizedBox(width: 11),
                                  Expanded(child: Text(item.label, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w700, color: selected ? (item.danger ? const Color(0xFF9D2C39) : ClinexaTheme.ink) : const Color(0xFF4D5B6F)))),
                                  if (selected) Container(width: 6, height: 6, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
                                ],
                              ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(expanded ? 12 : 10),
            child: Container(
              padding: EdgeInsets.all(expanded ? 12 : 8),
              decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(17), border: Border.all(color: ClinexaTheme.line)),
              child: expanded
                  ? Row(children: [
                      _Avatar(name: name),
                      const SizedBox(width: 9),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                        Text(roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 9.5)),
                      ])),
                    ])
                  : _Avatar(name: name),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final _Destination destination;
  final VoidCallback? onMenu;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final VoidCallback onLogout;
  const _TopBar({required this.destination, this.onMenu, required this.onSearch, required this.onAi, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return Container(
      height: mobile ? 62 : 70,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 22),
      decoration: const BoxDecoration(color: Color(0xEEFFFFFF), border: Border(bottom: BorderSide(color: ClinexaTheme.line))),
      child: Row(children: [
        if (mobile) Builder(builder: (ctx) => IconButton(onPressed: () => Scaffold.of(ctx).openDrawer(), icon: const Icon(Icons.menu_rounded))),
        if (!mobile) ...[
          Icon(destination.icon, size: 19, color: destination.danger ? ClinexaTheme.emergency : ClinexaTheme.primary),
          const SizedBox(width: 9),
        ],
        Expanded(child: Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: mobile ? 14 : 15, color: ClinexaTheme.ink))),
        if (!mobile) ...[
          SizedBox(
            width: 250,
            height: 40,
            child: Material(
              color: ClinexaTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: onSearch,
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Icon(Icons.search_rounded, size: 18, color: ClinexaTheme.muted), SizedBox(width: 8), Expanded(child: Text('Search Clinexa…', style: TextStyle(color: ClinexaTheme.muted, fontSize: 11.5))), Text('⌘ K', style: TextStyle(color: Color(0xFF9AA7B8), fontSize: 10, fontWeight: FontWeight.w700))])),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(onPressed: onAi, tooltip: 'Clinexa AI', icon: const Icon(Icons.auto_awesome_outlined, color: ClinexaTheme.primary)),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (v) { if (v == 'logout') onLogout(); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Sign out'), contentPadding: EdgeInsets.zero))],
          child: Padding(padding: const EdgeInsets.all(5), child: _Avatar(name: Api.currentUser?['full_name']?.toString() ?? 'C', small: true)),
        ),
      ]),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00B8AD), Color(0xFF006D68)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x2600A79D), blurRadius: 16, offset: Offset(0, 7))],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      );
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool small;
  const _Avatar({required this.name, this.small = false});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: small ? 16 : 18,
        backgroundColor: ClinexaTheme.navy,
        child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: small ? 11 : 12)),
      );
}

class _Destination {
  final String key;
  final String label;
  final IconData icon;
  final Widget page;
  final bool visible;
  final String group;
  final bool danger;
  const _Destination(this.key, this.label, this.icon, this.page, {required this.visible, required this.group, this.danger = false});
}

class _MoreTile extends StatelessWidget {
  final _Destination item;
  const _MoreTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final tone = item.danger ? ClinexaTheme.emergency : ClinexaTheme.primary;
    return Material(
      color: item.danger ? ClinexaTheme.rose : ClinexaTheme.surfaceSoft,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => Navigator.pop(context, item.key),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: tone.withAlpha(16), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: tone, size: 21)),
            const SizedBox(height: 8),
            Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
