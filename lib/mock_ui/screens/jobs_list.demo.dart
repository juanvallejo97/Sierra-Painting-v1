import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';
import '../components/states.dart';
import '../demo_state.dart';
import '../fakers.dart';

class JobsListDemo extends StatefulWidget {
  const JobsListDemo({super.key});
  @override State<JobsListDemo> createState() => _JobsListDemoState();
}

class _JobsListDemoState extends State<JobsListDemo> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final c = DemoScope.of(context);
    if (c.simulateLoading) return const AppScaffold(title: 'Jobs', body: LoadingView());
    if (c.simulateError) return AppScaffold(title: 'Jobs', body: ErrorView('Network error', onRetry: () => c.setError(false)));

    final jobs = fakeJobs(12).where((j) => filter == 'all' ? true : j.status == filter).toList();
    if (jobs.isEmpty) return const AppScaffold(title: 'Jobs', body: EmptyView('No jobs yet'));

    return AppScaffold(
      title: 'Jobs',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'open', label: Text('Open')),
                ButtonSegment(value: 'in_progress', label: Text('In progress')),
                ButtonSegment(value: 'done', label: Text('Done')),
              ],
              selected: {filter},
              onSelectionChanged: (s) => setState(() => filter = s.first),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (_, i) {
                final j = jobs[i];
                return Card(
                  child: ListTile(
                    title: Text(j.title),
                    subtitle: Text('${j.address}, ${j.city}\nAssigned to ${j.assignee}'),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(label: Text(j.status.replaceAll('_', ' '))),
                        const SizedBox(height: 4),
                        Text('Due ${j.dueAt.month}/${j.dueAt.day}')
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
