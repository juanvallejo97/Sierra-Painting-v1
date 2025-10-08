import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/screens/home.dart';
// import 'package:sierra_painting/mock_ui/screens/jobs_list_demo.dart';
import 'package:sierra_painting/mock_ui/screens/theme_lab_demo.dart';
import 'package:sierra_painting/mock_ui/screens/widget_zoo_demo.dart';
// Removed unused imports for missing demo screens

RouteFactory buildRouter() {
  return (settings) {
    Widget page = const Scaffold(body: Center(child: Text('Unknown route')));
    switch (settings.name) {
      case '/':
        page = const PlaygroundHome();
        break;
      // case '/jobs':
      //   page = const JobsListDemo();
      //   break;
      case '/jobs-board':
        //   page = const JobsKanbanDemo();
        break;
      case '/estimate':
        //   page = const EstimateEditorDemo();
        break;
      case '/invoice':
        //   page = const InvoicePreviewDemo();
        break;
      case '/time':
        //   page = const TimeTrackerDemo();
        break;
      case '/photos':
        //   page = const PhotosGalleryDemo();
        break;
      case '/theme':
        page = const ThemeLabDemo();
        break;
      case '/zoo':
        page = const WidgetZooDemo();
        break;
      default:
        page = const Scaffold(body: Center(child: Text('Unknown route')));
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  };
}
