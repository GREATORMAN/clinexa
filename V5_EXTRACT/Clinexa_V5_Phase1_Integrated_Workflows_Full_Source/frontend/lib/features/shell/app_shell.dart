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
import '../medications/medicine_centre_page.dart';
import '../messages/messages_page.dart';
import '../operations/operations_page.dart';
import '../patients/patients_page.dart';
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

  List<_Destination> get destinations {
    final all = <_Destination>[
      _Destination(
        'overview',
        _roles.contains('doctor') ? 'Doctor workspace' : 'Overview',
        Icons.space_dashboard_outlined,
        _roles.contains('doctor') ? const DoctorDashboardPage() : const DashboardPage(),
        visible: _isAdmin || _roles.contains('doctor'),
      ),
      _Destination('patient360', 'Patient 360°', Icons.hub_outlined, const Patient360Page(), visible: _hasAny(_clinicalRoles)),
      _Destination('medicines', 'Medicine Centre', Icons.medication_outlined, const MedicineCentrePage(), visible: _hasAny(_clinicalRoles.union(_pharmacyRoles))),
      _Destination('patients', 'Patient Directory', Icons.people_alt_outlined, const PatientsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles))),
      _Destination('doctors', 'Doctors', Icons.medical_services_outlined, const DoctorsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles))),
      _Destination('appointments', 'Appointments', Icons.calendar_month_outlined, const AppointmentsPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles))),
      _Destination('records', 'Clinical records', Icons.folder_shared_outlined, const RecordsPage(), visible: _hasAny(_clinicalRoles)),
      _Destination('documents', 'Documents & OCR', Icons.document_scanner_outlined, const DocumentsPage(), visible: _hasAny(_clinicalRoles.union(_labRoles))),
      _Destination('ai', 'AI Copilot', Icons.auto_awesome_outlined, const AiPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles))),
      _Destination('messages', 'Messages', Icons.chat_bubble_outline_rounded, const MessagesPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles))),
      _Destination('emergency', 'Emergency Hub', Icons.health_and_safety_outlined, const EmergencyPage(), visible: _hasAny(_clinicalRoles.union(_frontDeskRoles))),
      _Destination('advanced', 'Advanced Ops', Icons.monitor_heart_outlined, const AdvancedHubPage(), visible: _isAdmin || _hasAny(_labRoles)),
      _Destination('operations', 'Hospital Ops', Icons.apartment_outlined, const OperationsPage(), visible: _isAdmin || _hasAny(_frontDeskRoles.union(_pharmacyRoles).union(_billingRoles))),
      _Destination('search', 'Command Search', Icons.manage_search_rounded, const GlobalSearchPage(), visible: _isAdmin || _hasAny(_clinicalRoles.union(_frontDeskRoles).union(_labRoles).union(_pharmacyRoles).union(_billingRoles))),
      _Destination('settings', 'Security & Settings', Icons.admin_panel_settings_outlined, const AdvancedSettingsPage(), visible: _isAdmin || _hasAny(_supportRoles)),
    ];

    // Legacy admin accounts created before role-aware navigation may only carry
    // Super Administrator, while unconfigured dev accounts may have no roles.
    if (_roles.isEmpty) {
      return all.where((x) => ['appointments', 'ai'].contains(x.key)).toList();
    }
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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void selectPage(int newIndex) {
    final visible = destinations;
    if (newIndex < 0 || newIndex >= visible.length) return;
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('More Clinexa', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.sizeOf(ctx).width > 520 ? 4 : 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: more.map((item) => _MoreTile(item: item, emergency: item.key == 'emergency')).toList(),
              ),
            ],
          ),
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
    final primary = _mobilePrimary;
    final i = primary.indexWhere((x) => x.key == currentKey);
    return i >= 0 ? i : primary.length;
  }

  @override
  Widget build(BuildContext context) {
    final visible = destinations;
    if (index >= visible.length) index = 0;
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    final primary = _mobilePrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: desktop ? null : Drawer(width: 296, backgroundColor: Colors.white, child: _desktopNavigation(compact: true)),
      body: SafeArea(
        child: profileLoading && Api.currentUser == null
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  if (desktop)
                    Container(
                      width: 284,
                      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Color(0xFFE5EAF0)))),
                      child: _desktopNavigation(),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(key: ValueKey(visible[index].key), child: visible[index].page),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: desktop
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
                ...primary.map((item) => NavigationDestination(icon: Icon(item.icon), label: _shortLabel(item))),
                const NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'More'),
              ],
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

  Widget _desktopNavigation({bool compact = false}) {
    final visible = destinations;
    final user = Api.currentUser;
    final name = user?['full_name']?.toString() ?? 'Clinexa user';
    final roleLabel = Api.roles.isEmpty ? 'Role not configured' : Api.roles.join(' • ');

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 18 : 22, 20, compact ? 12 : 14, 14),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE2F2F1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.health_and_safety_rounded, color: ClinexaTheme.primary)),
              const SizedBox(width: 11),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clinexa', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.6)),
                Text('Clinical workspace', style: TextStyle(color: Color(0xFF8290A3), fontSize: 10.5, fontWeight: FontWeight.w600)),
              ])),
              IconButton(tooltip: 'Sign out', onPressed: logout, icon: const Icon(Icons.logout_rounded, size: 20)),
            ]),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider()),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final item = visible[i];
                final selected = i == index;
                final emergency = item.key == 'emergency';
                return Material(
                  color: selected ? (emergency ? const Color(0xFFFFEDEE) : const Color(0xFFE9F5F4)) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      selectPage(i);
                      if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(children: [
                        Icon(item.icon, size: 21, color: selected ? (emergency ? ClinexaTheme.emergency : ClinexaTheme.primary) : const Color(0xFF6A778A)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(item.label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? (emergency ? const Color(0xFFA52F39) : const Color(0xFF164E4C)) : const Color(0xFF425166)))),
                        if (emergency) Container(width: 7, height: 7, decoration: const BoxDecoration(color: ClinexaTheme.emergency, shape: BoxShape.circle)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF6F8FB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5EAF0))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: const Color(0xFF132238), child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(roleLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7B8798))),
              ])),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Destination {
  final String key;
  final String label;
  final IconData icon;
  final Widget page;
  final bool visible;
  const _Destination(this.key, this.label, this.icon, this.page, {required this.visible});
}

class _MoreTile extends StatelessWidget {
  final _Destination item;
  final bool emergency;
  const _MoreTile({required this.item, this.emergency = false});

  @override
  Widget build(BuildContext context) => Material(
        color: emergency ? const Color(0xFFFFF1F2) : const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.pop(context, item.key),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(item.icon, color: emergency ? ClinexaTheme.emergency : ClinexaTheme.primary, size: 26),
              const SizedBox(height: 8),
              Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
