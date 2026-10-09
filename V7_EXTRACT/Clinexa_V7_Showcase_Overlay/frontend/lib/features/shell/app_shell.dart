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
      _Destination('overview', _homeLabel, Icons.space_dashboard_rounded, _homePage, visible: true, group: 'Workspace'),
      _Destination('patient360', 'Patient 360°', Icons.blur_circular_rounded, const Patient360Page(), visible: _hasAny(_clinicalRoles), group: 'Care'),
      _Destination('medicines', 'Medicine Centre', Icons.medication_rounded, const MedicineCentrePage(), visible: _hasAny(_clinicalRoles.union(_pharmacyRoles)), group: 'Care'),
      _Destination('patients', 'Patients', Icons.group_rounded, const PatientsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('appointments', 'Appointments', Icons.calendar_month_rounded, const AppointmentsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('doctors', 'Doctors', Icons.medical_services_rounded, const DoctorsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('records', 'Clinical records', Icons.folder_copy_rounded, const RecordsPage(), visible: _hasAny(_clinicalRoles), group: 'Clinical'),
      _Destination('documents', 'Documents & OCR', Icons.document_scanner_rounded, const DocumentsPage(), visible: _hasAny(_clinicalRoles.union(_labRoles)), group: 'Clinical'),
      _Destination('pharmacy', 'Pharmacy', Icons.local_pharmacy_rounded, const PharmacyWorkspacePage(), visible: _hasAny(_pharmacyRoles), group: 'Operations'),
      _Destination('operations', 'Hospital operations', Icons.domain_rounded, const OperationsPage(), visible: _isAdmin || _hasAny(_frontDeskRoles.union(_pharmacyRoles).union(_billingRoles)), group: 'Operations'),
      _Destination('advanced', 'Care operations', Icons.monitor_heart_rounded, const AdvancedHubPage(), visible: _isAdmin || _hasAny(_labRoles), group: 'Operations'),
      _Destination('ai', 'Clinexa AI', Icons.auto_awesome_rounded, const AiPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles)), group: 'Tools'),
      _Destination('messages', 'Messages', Icons.chat_bubble_rounded, const MessagesPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles)), group: 'Tools'),
      _Destination('search', 'Search & command', Icons.manage_search_rounded, const GlobalSearchPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles).union(_billingRoles)), group: 'Tools'),
      _Destination('emergency', 'Emergency Hub', Icons.health_and_safety_rounded, const EmergencyPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Tools', danger: true),
      _Destination('settings', 'Security & settings', Icons.tune_rounded, const AdvancedSettingsPage(), visible: _isAdmin || _hasAny(_supportRoles), group: 'System'),
    ];
    return all.where((x) => x.visible).toList();
  }

  Future<void> _refreshProfile() async {
    setState(() => profileLoading = true);
    try {
      await Api.loadProfile();
      if (!mounted) return;
      setState(() {
        profileLoading = false;
        if (index >= destinations.length) index = 0;
      });
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
    final wanted = ['overview', 'patient360', 'medicines', 'appointments'];
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 11),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('More Clinexa', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), Text('Role-aware tools and workflows', style: TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
            ]),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final width = (constraints.maxWidth - 20) / 3;
              return Wrap(spacing: 10, runSpacing: 10, children: more.map((item) => SizedBox(width: width, child: _MoreTile(item: item))).toList());
            }),
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
      drawer: desktop ? null : Drawer(width: 306, backgroundColor: ClinexaTheme.navy, child: _navigation(expanded: true, closeDrawer: true)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF7F9FD), Color(0xFFF3F7F8), Color(0xFFF7F6FC)]),
        ),
        child: SafeArea(
          bottom: false,
          child: profileLoading && Api.currentUser == null
              ? const Center(child: CircularProgressIndicator())
              : Row(children: [
                  if (desktop) SizedBox(width: 276, child: _navigation(expanded: true)),
                  if (tablet) SizedBox(width: 78, child: _navigation(expanded: false)),
                  Expanded(
                    child: Column(children: [
                      _TopBar(
                        destination: visible[index],
                        onSearch: () {
                          final i = _indexForKey('search');
                          if (i != null) selectPage(i);
                        },
                        onAi: () {
                          final i = _indexForKey('ai');
                          if (i != null) selectPage(i);
                        },
                        onLogout: logout,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: Tween(begin: const Offset(.012, .006), end: Offset.zero).animate(animation), child: child),
                          ),
                          child: KeyedSubtree(key: ValueKey(visible[index].key), child: visible[index].page),
                        ),
                      ),
                    ]),
                  ),
                ]),
        ),
      ),
      bottomNavigationBar: desktop || tablet
          ? null
          : _PremiumMobileDock(
              items: primary,
              selectedIndex: mobileSelectedIndex,
              onSelected: (value) {
                if (value < primary.length) {
                  final selectedIndex = _indexForKey(primary[value].key);
                  if (selectedIndex != null) selectPage(selectedIndex);
                } else {
                  showMoreSheet();
                }
              },
            ),
    );
  }

  Widget _navigation({required bool expanded, bool closeDrawer = false}) {
    final name = Api.currentUser?['full_name']?.toString() ?? 'Clinexa user';
    final roleLabel = Api.roles.isEmpty ? 'Workspace' : Api.roles.join(' • ');
    final groups = <String, List<_Destination>>{};
    for (final item in destinations) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF111A30), Color(0xFF0F1B2D), Color(0xFF0B2630)])),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(expanded ? 18 : 10, 18, expanded ? 14 : 10, 14),
          child: Row(mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            const _BrandMark(),
            if (expanded) ...[
              const SizedBox(width: 11),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clinexa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.75, color: Colors.white)),
                Text('CONNECTED CARE OS', style: TextStyle(color: Color(0xFF88AAB1), fontSize: 8.2, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              ])),
            ],
          ]),
        ),
        Container(height: 1, color: Colors.white.withValues(alpha: .07)),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(expanded ? 10 : 9, 10, expanded ? 10 : 9, 10),
            children: [
              for (final entry in groups.entries) ...[
                if (expanded) Padding(padding: const EdgeInsets.fromLTRB(10, 12, 10, 6), child: Text(entry.key.toUpperCase(), style: const TextStyle(color: Color(0xFF708A96), fontSize: 8.1, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                ...entry.value.map((item) {
                  final i = destinations.indexWhere((x) => x.key == item.key);
                  final selected = i == index;
                  final tone = item.danger ? const Color(0xFFFF8794) : const Color(0xFF65E0D5);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Tooltip(
                      message: expanded ? '' : item.label,
                      child: Material(
                        color: selected ? Colors.white.withValues(alpha: .095) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            selectPage(i);
                            if (closeDrawer && Navigator.canPop(context)) Navigator.pop(context);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: expanded ? 11 : 0, vertical: 10),
                            child: Row(mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                              Icon(item.icon, size: 19, color: selected ? tone : const Color(0xFF92A3B2)),
                              if (expanded) ...[
                                const SizedBox(width: 11),
                                Expanded(child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.6, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? Colors.white : const Color(0xFFB8C3CF)))),
                                if (selected) Container(width: 5, height: 5, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
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
          padding: EdgeInsets.all(expanded ? 10 : 8),
          child: Container(
            padding: EdgeInsets.all(expanded ? 11 : 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .065), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .07))),
            child: expanded
                ? Row(children: [
                    _Avatar(name: name),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      Text(roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8EA4B0), fontSize: 9)),
                    ])),
                  ])
                : _Avatar(name: name),
          ),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final _Destination destination;
  final VoidCallback onSearch;
  final VoidCallback onAi;
  final VoidCallback onLogout;
  const _TopBar({required this.destination, required this.onSearch, required this.onAi, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final name = Api.currentUser?['full_name']?.toString() ?? 'Clinexa user';
    return Container(
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 20, 9, mobile ? 10 : 20, 9),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), border: const Border(bottom: BorderSide(color: ClinexaTheme.line))),
      child: Row(children: [
        if (mobile) Builder(builder: (ctx) => Container(width: 40, height: 40, decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(13), border: Border.all(color: ClinexaTheme.line)), child: IconButton(onPressed: () => Scaffold.of(ctx).openDrawer(), icon: const Icon(Icons.menu_rounded, size: 20)))),
        if (mobile) const SizedBox(width: 8),
        Container(width: 38, height: 38, decoration: BoxDecoration(color: destination.danger ? ClinexaTheme.rose : ClinexaTheme.mint, borderRadius: BorderRadius.circular(13)), child: Icon(destination.icon, size: 19, color: destination.danger ? ClinexaTheme.emergency : ClinexaTheme.primary)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: mobile ? 13.2 : 14.2, color: ClinexaTheme.ink, letterSpacing: -.25)),
          if (!mobile) Text(Api.roles.isEmpty ? 'Clinexa workspace' : Api.roles.first, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 9.5)),
        ])),
        if (!mobile) ...[
          SizedBox(
            width: 286,
            child: Material(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onSearch,
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 13, vertical: 10), child: Row(children: [Icon(Icons.search_rounded, size: 18, color: ClinexaTheme.muted), SizedBox(width: 8), Expanded(child: Text('Search patients, records, actions…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ClinexaTheme.muted, fontSize: 10.6))), Text('⌘K', style: TextStyle(color: Color(0xFF9DA7B5), fontSize: 9.5, fontWeight: FontWeight.w700))])),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(width: 40, height: 40, decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x1F0B776E), blurRadius: 16, offset: Offset(0, 6))]), child: IconButton(onPressed: onAi, tooltip: 'Clinexa AI', icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19))),
        const SizedBox(width: 7),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (value) {
            if (value == 'logout') onLogout();
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Sign out'), contentPadding: EdgeInsets.zero))],
          child: _Avatar(name: name, small: true, light: true),
        ),
      ]),
    );
  }
}

class _PremiumMobileDock extends StatelessWidget {
  final List<_Destination> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _PremiumMobileDock({required this.items, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final all = <_MobileDockItem>[
      ...items.map((item) => _MobileDockItem(label: _shortLabel(item), icon: item.icon)),
      const _MobileDockItem(label: 'More', icon: Icons.grid_view_rounded),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF121B2E),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x3510182B), blurRadius: 26, offset: Offset(0, 10))],
        ),
        child: Row(children: [
          for (var i = 0; i < all.length; i++)
            Expanded(
              child: _DockButton(
                item: all[i],
                selected: selectedIndex == i,
                onTap: () => onSelected(i),
              ),
            ),
        ]),
      ),
    );
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
}

class _DockButton extends StatelessWidget {
  final _MobileDockItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DockButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
            decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: .11) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(item.icon, size: 20, color: selected ? const Color(0xFF73E3D9) : const Color(0xFF8E9AAA)),
              const SizedBox(height: 3),
              Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : const Color(0xFF95A1B0), fontSize: 8.7, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _MobileDockItem {
  final String label;
  final IconData icon;
  const _MobileDockItem({required this.label, required this.icon});
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x300B776E), blurRadius: 18, offset: Offset(0, 7))]),
        child: Stack(alignment: Alignment.center, children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          Positioned(right: 7, top: 7, child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF9FEFE8), shape: BoxShape.circle))),
        ]),
      );
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool small;
  final bool light;
  const _Avatar({required this.name, this.small = false, this.light = false});
  @override
  Widget build(BuildContext context) => Container(
        width: small ? 36 : 38,
        height: small ? 36 : 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: light ? const LinearGradient(colors: [Color(0xFFE8F8F5), Color(0xFFEFF1FF)]) : const LinearGradient(colors: [Color(0xFF25324A), Color(0xFF1B4B53)]),
          shape: BoxShape.circle,
          border: Border.all(color: light ? ClinexaTheme.line : Colors.white.withValues(alpha: .08)),
        ),
        child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(color: light ? ClinexaTheme.primary : Colors.white, fontWeight: FontWeight.w800, fontSize: small ? 11 : 12)),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pop(context, item.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: tone.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: tone, size: 20)),
            const SizedBox(height: 7),
            Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.7, fontWeight: FontWeight.w800, height: 1.25)),
          ]),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
