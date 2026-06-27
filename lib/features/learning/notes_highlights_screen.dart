import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/note.dart';
import '../../models/highlight.dart';

class NotesAndHighlightsScreen extends StatefulWidget {
  const NotesAndHighlightsScreen({Key? key}) : super(key: key);

  @override
  State<NotesAndHighlightsScreen> createState() => _NotesAndHighlightsScreenState();
}

class _NotesAndHighlightsScreenState extends State<NotesAndHighlightsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Note> _notes = [];
  List<Highlight> _highlights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() async {
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      final notes = await AppLocator.db.fetchNotes(user.id);
      final hls = await AppLocator.db.fetchHighlights(user.id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _highlights = hls;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteNote(String id) async {
    await AppLocator.db.deleteNote(id);
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted.')));
  }

  void _deleteHighlight(String id) async {
    await AppLocator.db.deleteHighlight(id);
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Highlight deleted.')));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final isRtl = localizations.isRtl;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('notes_highlights')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: localizations.translate('my_notes')),
            Tab(text: localizations.translate('highlights')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Notes Tab
          _notes.isEmpty
              ? Center(child: Text(localizations.translate('no_notes_saved')))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    note.bookTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _deleteNote(note.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              note.noteText,
                              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          
          // Highlights Tab
          _highlights.isEmpty
              ? Center(child: Text(localizations.translate('no_highlights_saved')))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _highlights.length,
                  itemBuilder: (context, index) {
                    final hl = _highlights[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    hl.bookTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => _deleteHighlight(hl.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Color(hl.colorValue).withOpacity(0.2),
                                border: Border(
                                  left: isRtl
                                      ? BorderSide.none
                                      : BorderSide(color: Color(hl.colorValue), width: 4),
                                  right: isRtl
                                      ? BorderSide(color: Color(hl.colorValue), width: 4)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Text(
                                hl.text,
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
