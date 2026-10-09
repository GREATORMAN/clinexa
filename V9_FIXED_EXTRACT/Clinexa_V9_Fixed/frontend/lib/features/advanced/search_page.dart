import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final q = TextEditingController();
  Map<String, dynamic>? data;
  bool loading = false;
  String? error;

  Future<void> search() async {
    if (q.text.trim().length < 2) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Api.dio.get(
        '/api/v1/advanced/search',
        queryParameters: {'q': q.text.trim()},
      );
      if (mounted) {
        setState(() => data = Map<String, dynamic>.from(response.data));
      }
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ['patients', 'doctors', 'appointments', 'documents'];
    return SectionPage(
      title: 'Command Search',
      subtitle: 'Search patients, clinicians, appointments and documents from one place',
      child: ListView(
        padding: EdgeInsets.all(18),
        children: [
          TextField(
            controller: q,
            autofocus: true,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: 'Try a patient name, specialty or document...',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: search,
                icon: Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          if (loading) ...[
            SizedBox(height: 12),
            LinearProgressIndicator(),
          ],
          if (error != null) ...[
            SizedBox(height: 12),
            ErrorCard(error!),
          ],
          SizedBox(height: 14),
          if (data != null)
            ...groups.map(
              (key) => _ResultGroup(
                title: key[0].toUpperCase() + key.substring(1),
                items: List<dynamic>.from(data![key] as List? ?? []),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultGroup extends StatelessWidget {
  final String title;
  final List<dynamic> items;

  const _ResultGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              SizedBox(height: 8),
              if (items.isEmpty)
                Text('No matches.')
              else
                ...items.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.search_rounded),
                    title: Text(item['label']?.toString() ?? ''),
                    subtitle: Text(item['meta']?.toString() ?? ''),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
