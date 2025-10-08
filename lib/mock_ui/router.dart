import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/jobs_list_demo.dart';
import 'screens/jobs_kanban_demo.dart';
import 'screens/estimate_editor_demo.dart';
import 'screens/invoice_preview_demo.dart';
import 'screens/time_tracker_demo.dart';
import 'screens/photos_gallery_demo.dart';
import 'screens/theme_lab_demo.dart';
import 'screens/widget_zoo_demo.dart';

RouteFactory buildRouter() {
  return (settings) {
    Widget page;
    switch (settings.name) {
      case '/': page = const PlaygroundHome(); break;
      case '/jobs': page = const JobsListDemo(); break;
      case '/jobs-board': page = const JobsKanbanDemo(); break;
      case '/estimate': page = const EstimateEditorDemo(); break;
      case '/invoice': page = const InvoicePreviewDemo(); break;
      case '/time': page = const TimeTrackerDemo(); break;
      case '/photos': page = const PhotosGalleryDemo(); break;
      case '/theme': page = const ThemeLabDemo(); break;
      case '/zoo': page = const WidgetZooDemo(); break;
      default: page = const Scaffold(body: Center(child: Text('Unknown route')));
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  };
}
