import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookmyspace/features/auth/presentation/auth_providers.dart';
import '../observability_providers.dart';
import '../../domain/observability.dart';

class AdminHelpCenterScreen extends ConsumerStatefulWidget {
  const AdminHelpCenterScreen({super.key});

  @override
  ConsumerState<AdminHelpCenterScreen> createState() => _AdminHelpCenterScreenState();
}

class _AdminHelpCenterScreenState extends ConsumerState<AdminHelpCenterScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(helpArticlesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center'), actions: [IconButton(onPressed: () => _edit(context), icon: const Icon(Icons.add), tooltip: 'Add article')]),
      body: articles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Help content unavailable: $error')),
        data: (items) {
          final filtered = items.where((article) {
            final haystack = '${article.title} ${article.summary} ${article.category}'.toLowerCase();
            return haystack.contains(query.toLowerCase());
          }).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search help'),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              ...filtered.map((article) => Card(
                child: ExpansionTile(
                  onExpansionChanged: (_) {},
                  title: Text(article.title),
                  subtitle: Text('${article.category} · ${article.language}'),
                  trailing: PopupMenuButton<String>(onSelected: (value) async {
                    final repo = HelpArticleAdminRepository(ref.read(supabaseProvider));
                    if (value == 'toggle') await repo.setEnabled(article.id, !article.enabled);
                    if (value == 'archive') await repo.archive(article.id);
                    if (value == 'edit') await _edit(context, article: article);
                    ref.invalidate(helpArticlesProvider);
                  }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'toggle', child: Text(article.enabled ? 'Disable' : 'Enable')), const PopupMenuItem(value: 'archive', child: Text('Archive'))]),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(article.summary.isEmpty ? article.content : article.summary),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, {HelpArticle? article}) async {
    final title = TextEditingController(text: article?.title ?? '');
    final summary = TextEditingController(text: article?.summary ?? '');
    final steps = TextEditingController(text: article?.content ?? '');
    final category = TextEditingController(text: article?.category ?? 'General');
    final language = TextEditingController(text: article?.language ?? 'en');
    final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(article == null ? 'Add article' : 'Edit article'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')), TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')), TextField(controller: language, decoration: const InputDecoration(labelText: 'Language')), TextField(controller: summary, decoration: const InputDecoration(labelText: 'Summary')), TextField(controller: steps, maxLines: 4, decoration: const InputDecoration(labelText: 'Steps'))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
    if (result != true || !mounted || title.text.trim().isEmpty) return;
    await HelpArticleAdminRepository(ref.read(supabaseProvider)).save(id: article?.id, category: category.text.trim(), language: language.text.trim().isEmpty ? 'en' : language.text.trim(), title: title.text.trim(), summary: summary.text.trim(), steps: steps.text.trim(), sortOrder: 0, enabled: true);
    ref.invalidate(helpArticlesProvider);
  }
}
