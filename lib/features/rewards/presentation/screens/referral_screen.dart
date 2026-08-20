import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../rewards_providers.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Refer & Earn')),
    body: ref
        .watch(referralSummaryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Unable to load referrals: $e')),
          data: (summary) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Your referral code'),
                  subtitle: Text(
                    summary.code,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Copy referral link',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'https://bookmyspace.app/register?ref=${summary.code}',
                        ),
                      );
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Referral link copied')),
                        );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Referral history',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _ClaimReferralField(ref: ref),
              if (summary.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text('No referrals yet.'),
                ),
              ...summary.items.map(
                (item) => ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: Text(
                    (item['status'] as String? ?? 'pending').toUpperCase(),
                  ),
                  subtitle: Text(item['created_at'] as String? ?? ''),
                ),
              ),
            ],
          ),
        ),
  );
}

class _ClaimReferralField extends StatefulWidget {
  const _ClaimReferralField({required this.ref});
  final WidgetRef ref;
  @override
  State<_ClaimReferralField> createState() => _ClaimReferralFieldState();
}

class _ClaimReferralFieldState extends State<_ClaimReferralField> {
  final _controller = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Have a referral code?'),
        ),
      ),
      IconButton(
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(),
              )
            : const Icon(Icons.check),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.ref
                      .read(rewardsRepositoryProvider)
                      .claimReferral(_controller.text);
                  widget.ref.invalidate(referralSummaryProvider);
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral attributed')),
                    );
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
                if (mounted) setState(() => _busy = false);
              },
      ),
    ],
  );
}
