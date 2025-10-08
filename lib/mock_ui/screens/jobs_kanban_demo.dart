import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';
import '../fakers.dart';

class JobsKanbanDemo extends StatelessWidget {
  const JobsKanbanDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final jobs = fakeJobs(24);
    final by = <String, List<Job>>{
      'Open': jobs.where((j) => j.status == 'open').toList(),
      'In progress': jobs.where((j) => j.status == 'in_progress').toList(),
      'Done': jobs.where((j) => j.status == 'done').toList(),
    };
    return AppScaffold(
      title: 'Jobs Board',
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: by.entries.map((e) => _Column(title: e.key, jobs: e.value)).toList(),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final String title; final List<Job> jobs;
  const _Column({required this.title, required this.jobs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final j in jobs)
          Card(
            child: ListTile(
              title: Text(j.title),
              subtitle: Text('${j.city} · ${j.assignee}'),
            ),
          )
      ]),
    );
  }
}
