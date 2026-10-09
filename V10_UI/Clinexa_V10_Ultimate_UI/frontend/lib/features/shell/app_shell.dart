import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../../core/theme/preferences.dart';
import '../care/care_tasks_page.dart';
import '../workspace/account_page.dart';
import '../workspace/audit_page.dart';
import '../workspace/caregiver_page.dart';
import '../workspace/clinical_notes_page.dart';
import '../workspace/lab_workspace_page.dart';
import '../notifications/notifications_page.dart';

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

  static final _adminRoles = {'super administrator', 'hospital administrator'};
  static final _clinicalRoles = {'doctor', 'nurse'};
  static final _frontDeskRoles = {'receptionist'};
  static final _labRoles = {'lab technician'};
  static final _pharmacyRoles = {'pharmacist'};
  static final _billingRoles = {'billing staff'};
  static final _supportRoles = {'support staff'};

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Set<String> get _roles => Api.roles.map((x) => x.toLowerCase()).toSet();
  bool get _isAdmin => _roles.any(_adminRoles.contains);
  bool _hasAny(Set<String> group) => _isAdmin || _roles.any(group.contains);

  Widget get _homePage {
    if (_roles.contains('caregiver')) return CaregiverPage();
    if (_roles.contains('doctor')) return DoctorDashboardPage();
    if (_roles.contains('pharmacist')) return PharmacyWorkspacePage();
    if (_isAdmin) return DashboardPage(onNavigate: navigate);
    return RoleHomePage(onNavigate: navigate);
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
      _Destination('patient360', 'Patient 360°', Icons.blur_circular_rounded, Patient360Page(), visible: _hasAny(_clinicalRoles), group: 'Care'),
      _Destination('medicines', 'Medicine Centre', Icons.medication_rounded, MedicineCentrePage(), visible: Api.can('patient.clinical.read'), group: 'Care'),
      _Destination('patients', 'Patients', Icons.group_rounded, PatientsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('appointments', 'Appointments', Icons.calendar_month_rounded, AppointmentsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('doctors', 'Doctors', Icons.medical_services_rounded, DoctorsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Care'),
      _Destination('records', 'Clinical records', Icons.folder_copy_rounded, RecordsPage(), visible: _hasAny(_clinicalRoles), group: 'Clinical'),
      _Destination('documents', 'Documents & OCR', Icons.document_scanner_rounded, DocumentsPage(), visible: _hasAny(_clinicalRoles.union(_labRoles)), group: 'Clinical'),
      _Destination('pharmacy', 'Pharmacy', Icons.local_pharmacy_rounded, PharmacyWorkspacePage(), visible: _hasAny(_pharmacyRoles), group: 'Operations'),
      _Destination('operations', 'Hospital operations', Icons.domain_rounded, OperationsPage(), visible: _isAdmin || _hasAny(_frontDeskRoles.union(_pharmacyRoles).union(_billingRoles)), group: 'Operations'),
      _Destination('advanced', 'Care operations', Icons.monitor_heart_rounded, AdvancedHubPage(), visible: _isAdmin || _hasAny(_labRoles), group: 'Operations'),
      _Destination('ai', 'Clinexa AI', Icons.auto_awesome_rounded, AiPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles)), group: 'Tools'),
      _Destination('messages', 'Messages', Icons.chat_bubble_rounded, MessagesPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles)), group: 'Tools'),
      _Destination('search', 'Search & command', Icons.manage_search_rounded, GlobalSearchPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles).union(_billingRoles)), group: 'Tools'),
      _Destination('emergency', 'Emergency Hub', Icons.health_and_safety_rounded, EmergencyPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles)), group: 'Tools', danger: true),
      _Destination('clinical_notes', 'Clinical notes', Icons.edit_note_rounded, ClinicalNotesPage(), visible: Api.can('patient.clinical.read'), group: 'Clinical'),
      _Destination('lab_workspace', 'Lab workspace', Icons.science_outlined, LabWorkspacePage(), visible: Api.can('lab.orders.read'), group: 'Clinical'),
      _Destination('care_tasks', 'Care task board', Icons.checklist_rounded, CareTasksPage(), visible: Api.can('patient.clinical.read'), group: 'Care'),
      _Destination('notifications', 'Notifications', Icons.notifications_none_rounded, NotificationsPage(), visible: true, group: 'Workspace'),
      _Destination('audit', 'Audit centre', Icons.policy_outlined, AuditPage(), visible: Api.can('audit.read'), group: 'System'),
      _Destination('account', 'Appearance & account', Icons.palette_outlined, AccountPage(), visible: true, group: 'System'),
      _Destination('settings', 'Security & settings', Icons.tune_rounded, AdvancedSettingsPage(), visible: _isAdmin || _hasAny(_supportRoles), group: 'System'),
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
    if (AppPreferences.beforeNavigate != null && !await AppPreferences.beforeNavigate!()) return;
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginPage()), (_) => false);
  }

  void navigate(String key) {
    final next = _indexForKey(key);
    if (next != null) selectPage(next);
  }

  Future<void> showCommands() async {
    final key = await showDialog<String>(context: context, builder: (ctx) => _CommandDialog(items: destinations));
    if (key != null && mounted) navigate(key);
  }

  Future<void> selectPage(int newIndex) async {
    if (newIndex == index) return;
    if (AppPreferences.beforeNavigate != null && !await AppPreferences.beforeNavigate!()) return;
    if (!mounted) return;
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(13)), child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 20)),
              SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('More Clinexa', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), Text('Role-aware tools and workflows', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
            ]),
            SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 2 : 3;
              final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
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
    if (visible.isEmpty) return Scaffold(body: Center(child: Text('No workspace destinations available.')));
    if (index >= visible.length) index = 0;
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1120;
    final tablet = width >= 760 && !desktop;
    final primary = _mobilePrimary;

    return CallbackShortcuts(bindings: {
      SingleActivator(LogicalKeyboardKey.keyK, control: true): showCommands,
      SingleActivator(LogicalKeyboardKey.keyK, meta: true): showCommands,
    }, child: Focus(autofocus: true, child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: desktop ? null : Drawer(width: 306, backgroundColor: ClinexaTheme.navy, child: _navigation(expanded: true, closeDrawer: true)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Theme.of(context).scaffoldBackgroundColor, Theme.of(context).brightness == Brightness.dark ? const Color(0xFF132226) : const Color(0xFFF1F7F7), Theme.of(context).scaffoldBackgroundColor]),
        ),
        child: SafeArea(
          bottom: false,
          child: profileLoading && Api.currentUser == null
              ? Center(child: CircularProgressIndicator())
              : Row(children: [
                  if (desktop) SizedBox(width: 276, child: _navigation(expanded: true)),
                  if (tablet) SizedBox(width: 78, child: _navigation(expanded: false)),
                  Expanded(
                    child: Column(children: [
                      _TopBar(
                        destination: visible[index],
                        onSearch: showCommands,
                        onInbox: () => navigate('notifications'),
                        showAi: _indexForKey('ai') != null,
                        onAi: () {
                          final i = _indexForKey('ai');
                          if (i != null) selectPage(i);
                        },
                        onLogout: logout,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 1600),
                            child: SizedBox(
                              width: double.infinity,
                              child: AnimatedSwitcher(
                                duration: AppPreferences.reducedMotion.value ? Duration.zero : Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(position: Tween(begin: Offset(.012, .006), end: Offset.zero).animate(animation), child: child),
                                ),
                                child: KeyedSubtree(key: ValueKey(visible[index].key), child: visible[index].page),
                              ),
                            ),
                          ),
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
    )));
  }

  Widget _navigation({required bool expanded, bool closeDrawer = false}) {
    final name = Api.currentUser?['full_name']?.toString() ?? 'Clinexa user';
    final roleLabel = Api.roles.isEmpty ? 'Workspace' : Api.roles.join(' • ');
    final groups = <String, List<_Destination>>{};
    for (final item in destinations) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }

    const shellTop = Color(0xFF11272C);
    const shellBottom = Color(0xFF142D35);
    const navText = Color(0xFFB9C9CE);
    const navMuted = Color(0xFF789097);
    const selectedFill = Color(0xFF21474A);
    const selectedAccent = Color(0xFF63D6CA);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [shellTop, shellBottom]),
      ),
      child: SafeArea(
        right: false,
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(expanded ? 18 : 10, 17, expanded ? 14 : 10, 14),
            child: Row(mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
              const _BrandMark(dark: true),
              if (expanded) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('Clinexa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.75, color: Colors.white)),
                    SizedBox(height: 1),
                    Text('CONNECTED CARE OS', style: TextStyle(color: Color(0xFF87A3AA), fontSize: 8.2, fontWeight: FontWeight.w800, letterSpacing: 1.05)),
                  ]),
                ),
              ],
            ]),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: .07)),
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: EdgeInsets.fromLTRB(expanded ? 10 : 9, 9, expanded ? 10 : 9, 10),
                children: [
                  for (final entry in groups.entries) ...[
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 13, 10, 6),
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(color: navMuted, fontSize: 9.2, fontWeight: FontWeight.w800, letterSpacing: 1.15),
                        ),
                      ),
                    ...entry.value.map((item) {
                      final i = destinations.indexWhere((x) => x.key == item.key);
                      final selected = i == index;
                      final danger = item.danger;
                      final selectedColor = danger ? const Color(0xFFFF8B99) : selectedAccent;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Tooltip(
                          message: expanded ? '' : item.label,
                          child: Material(
                            color: selected ? selectedFill : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                selectPage(i);
                                if (closeDrawer && Navigator.canPop(context)) Navigator.pop(context);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.symmetric(horizontal: expanded ? 11 : 0, vertical: 10),
                                child: Row(mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: selected ? selectedColor.withValues(alpha: .12) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(item.icon, size: 18, color: selected ? selectedColor : navText),
                                  ),
                                  if (expanded) ...[
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.4,
                                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                          color: selected ? Colors.white : navText,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Container(width: 5, height: 5, decoration: BoxDecoration(color: selectedColor, shape: BoxShape.circle)),
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
          ),
          Padding(
            padding: EdgeInsets.all(expanded ? 10 : 8),
            child: Container(
              padding: EdgeInsets.all(expanded ? 10 : 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: expanded
                  ? Row(children: [
                      _Avatar(name: name, light: false),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(roleLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: navMuted, fontSize: 9)),
                        ]),
                      ),
                    ])
                  : _Avatar(name: name, light: false),
            ),
          ),
        ]),
      ),
    );
  }

}

class _TopBar extends StatelessWidget {
  final _Destination destination;
  final VoidCallback onSearch;
  final bool showAi;
  final VoidCallback onInbox;
  final VoidCallback onAi;
  final VoidCallback onLogout;
  const _TopBar({required this.showAi, required this.destination, required this.onSearch, required this.onInbox, required this.onAi, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 760;
    final veryCompact = width < 390;
    final name = Api.currentUser?['full_name']?.toString() ?? 'Clinexa user';
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.fromLTRB(mobile ? 10 : 16, mobile ? 8 : 12, mobile ? 10 : 16, 0),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .9)),
        boxShadow: const [BoxShadow(color: Color(0x0B10232D), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Row(children: [
        if (mobile)
          Builder(
            builder: (ctx) => _TopIconButton(
              tooltip: 'Open navigation',
              icon: Icons.menu_rounded,
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        if (mobile) const SizedBox(width: 7),
        Container(
          width: mobile ? 36 : 39,
          height: mobile ? 36 : 39,
          decoration: BoxDecoration(
            color: destination.danger ? ClinexaTheme.rose : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(destination.icon, size: 18, color: destination.danger ? ClinexaTheme.emergency : scheme.primary),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: mobile ? 12.8 : 14.0, color: scheme.onSurface, letterSpacing: -.25),
            ),
            if (!mobile)
              Text(
                Api.roles.isEmpty ? 'Clinexa workspace' : Api.roles.first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9.2),
              ),
          ]),
        ),
        if (!mobile) ...[
          SizedBox(
            width: width >= 1320 ? 320 : 250,
            child: Material(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: onSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 17, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Search patients, records, actions…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10.4))),
                    const Text('Ctrl K', style: TextStyle(color: Color(0xFF9DA7AD), fontSize: 9.2, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (!veryCompact)
          _TopIconButton(
            tooltip: 'Switch appearance',
            icon: Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            onPressed: AppPreferences.toggleTheme,
          ),
        _TopIconButton(tooltip: 'Notifications', icon: Icons.notifications_none_rounded, onPressed: onInbox),
        if (showAi && width >= 430)
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              gradient: ClinexaTheme.accentGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x1C159A8F), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: IconButton(onPressed: onAi, tooltip: 'Clinexa AI', icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18)),
          ),
        const SizedBox(width: 5),
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

class _TopIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  const _TopIconButton({required this.tooltip, required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
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
      _MobileDockItem(label: 'More', icon: Icons.grid_view_rounded),
    ];
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: .94),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: .92)),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x2610232D), blurRadius: 28, offset: Offset(0, 12))],
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
        ),
      ),
    );
  }

  String _shortLabel(_Destination item) {
    switch (item.key) {
      case 'patient360':
        return '360°';
      case 'medicines':
        return 'Meds';
      case 'appointments':
        return 'Visits';
      case 'overview':
        return 'Home';
      case 'ai':
        return 'AI';
      default:
        return item.label.split(' ').first;
    }
  }
}

class _DockButton extends StatelessWidget {
  final _MobileDockItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DockButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(
              scale: selected ? 1.04 : 1,
              duration: const Duration(milliseconds: 180),
              child: Icon(item.icon, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontSize: 8.7,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MobileDockItem {
  final String label;
  final IconData icon;
  _MobileDockItem({required this.label, required this.icon});
}

class _BrandMark extends StatelessWidget {
  final bool dark;
  const _BrandMark({this.dark = false});
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: ClinexaTheme.accentGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? Colors.white.withValues(alpha: .09) : Colors.transparent),
          boxShadow: const [BoxShadow(color: Color(0x24159A8F), blurRadius: 18, offset: Offset(0, 7))],
        ),
        child: Stack(alignment: Alignment.center, children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 27),
          Positioned(
            right: 7,
            top: 7,
            child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFFAEF4EA), shape: BoxShape.circle)),
          ),
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
          gradient: light ? LinearGradient(colors: [Color(0xFFE8F8F5), Color(0xFFEFF1FF)]) : LinearGradient(colors: [Color(0xFF25324A), Color(0xFF1B4B53)]),
          shape: BoxShape.circle,
          border: Border.all(color: light ? Theme.of(context).colorScheme.outlineVariant : Colors.white.withValues(alpha: .08)),
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
  _Destination(this.key, this.label, this.icon, this.page, {required this.visible, required this.group, this.danger = false});
}

class _MoreTile extends StatelessWidget {
  final _Destination item;
  const _MoreTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final tone = item.danger ? ClinexaTheme.emergency : ClinexaTheme.primary;
    return Material(
      color: item.danger ? ClinexaTheme.rose : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pop(context, item.key),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: tone.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(item.icon, color: tone, size: 20)),
            SizedBox(height: 7),
            Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.7, fontWeight: FontWeight.w800, height: 1.25)),
          ]),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _CommandDialog extends StatefulWidget {
  final List<_Destination> items;
  const _CommandDialog({required this.items});
  @override
  State<_CommandDialog> createState() => _CommandDialogState();
}
class _CommandDialogState extends State<_CommandDialog> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((x) => x.label.toLowerCase().contains(query.toLowerCase())).toList();
    return Dialog(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 540, maxHeight: MediaQuery.sizeOf(context).height * .75), child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(autofocus: true, onChanged: (v) => setState(() => query = v), onSubmitted: (_) { if (items.isNotEmpty) Navigator.pop(context, items.first.key); }, decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Jump to a workspace…')),
      SizedBox(height: 12),
      Flexible(child: ListView(shrinkWrap: true, children: [if (items.isEmpty) ListTile(title: Text('No matching workspaces')), ...items.map((x) => ListTile(leading: Icon(x.icon, color: ClinexaTheme.primary), title: Text(x.label), subtitle: Text(x.group), trailing: Icon(Icons.arrow_forward_rounded, size: 18), onTap: () => Navigator.pop(context, x.key)))])),
    ]))));
  }
}
