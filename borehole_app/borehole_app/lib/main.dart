import 'package:borehole_app/screens/view_boreholes_list.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io'; 

import 'database_helper.dart';
import 'screens/home_page.dart';
import 'screens/add_site.dart';
import 'screens/add_borehole.dart';
import 'screens/upload_csv.dart';
import 'screens/postgres_config_page.dart';
import 'screens/view_postgres_boreholes.dart';
import 'screens/borehole_water_level_graph.dart'; 
import 'screens/MapScreen.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; 
  }

  runApp(BoreholeApp());
}

class BoreholeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Borehole Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/addSite': (context) => AddSite(),
        '/addBorehole': (context) => AddBorehole(),
        '/uploadCsv': (context) => UploadCsv(),
        '/viewList': (context) => ViewBoreholesList(),
        '/postgresConfig': (context) => PostgresConfigPage(), 
        '/viewPostgresBoreholes': (context) => ViewPostgresBoreholes(), 
        '/waterLevelGraph': (context) => BoreholeDataGraph(),  
        '/viewMap': (context) => MapScreen(),
      },
    );
  }
}
