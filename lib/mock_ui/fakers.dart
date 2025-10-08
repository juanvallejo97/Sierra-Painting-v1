import 'dart:math';

final _rnd = Random();

String pick(List<String> xs) => xs[_rnd.nextInt(xs.length)];

const _names = ['Avery', 'Riley', 'Jordan', 'Parker', 'River', 'Rowan', 'Emerson', 'Quinn'];
const _streets = ['Maple', 'Cedar', 'Oak', 'Pine', 'Willow', 'Elm', 'Birch', 'Spruce'];
const _cities = ['Elk Grove', 'Fresno', 'Modesto', 'Tracy', 'Sacramento'];

class Job {
  final String id, title, address, city, assignee, status; // open|in_progress|done
  final DateTime createdAt, dueAt;
  Job({
    required this.id,
    required this.title,
    required this.address,
    required this.city,
    required this.assignee,
    required this.status,
    required this.createdAt,
    required this.dueAt,
  });
}

List<Job> fakeJobs(int n) => List.generate(n, (i) {
  final status = pick(['open','in_progress','done']);
  return Job(
    id: 'J${1000+i}',
    title: '${pick(['Exterior','Interior','Fence'])} ${pick(['Paint','Repaint'])}',
    address: '${100 + _rnd.nextInt(900)} ${pick(_streets)} St.',
    city: pick(_cities),
    assignee: pick(_names),
    status: status,
    createdAt: DateTime.now().subtract(Duration(days: _rnd.nextInt(10))),
    dueAt: DateTime.now().add(Duration(days: 1 + _rnd.nextInt(14))),
  );
});

class LineItem { String desc; int qty; double price;
  LineItem(this.desc,this.qty,this.price);
  double get total => qty * price;
}

List<LineItem> fakeLineItems() => [
  LineItem('Prep & Mask', 1, 250),
  LineItem('Walls (2 coats)', 1200, 0.85),
  LineItem('Trim (semi‑gloss)', 200, 1.20),
];
