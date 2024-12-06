import 'package:flutter/material.dart';

class NavigationDrawerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Borehole Manager',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Start Page'),
            onTap: () {
              Navigator.pushNamed(context, '/');
            },
          ),
          ListTile(
            leading: Icon(Icons.add_location_alt),
            title: Text('Add Site'),
            onTap: () {
              Navigator.pushNamed(context, '/addSite');
            },
          ),
          ListTile(
            leading: Icon(Icons.add_circle),
            title: Text('Add Borehole'),
            onTap: () {
              Navigator.pushNamed(context, '/addBorehole');
            },
          ),
          ListTile(
            leading: Icon(Icons.list),
            title: Text('View Boreholes List'),
            onTap: () {
              Navigator.pushNamed(context, '/viewList');
            },
          ),
          ListTile(
            leading: Icon(Icons.upload_file),
            title: Text('Process Data'),
            onTap: () {
              Navigator.pushNamed(context, '/uploadCsv');
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Postgres Config'),
            onTap: () {
              Navigator.pushNamed(context, '/postgresConfig'); 
            },
          ),
          ListTile(
            leading: Icon(Icons.storage),
            title: Text('View PostgreSQL Boreholes'),
            onTap: () {
              Navigator.pushNamed(context, '/viewPostgresBoreholes'); 
            },
          ),
          ListTile(
            leading: Icon(Icons.map),
            title: Text('View Map'),
            onTap: () {
              Navigator.pushNamed(context, '/viewMap'); 
            },
          ),
          ListTile(
            leading: Icon(Icons.show_chart),
            title: Text('Water Level Graph'), 
            onTap: () {
              Navigator.pushNamed(context, '/waterLevelGraph');
            },
          ),
        ],
      ),
    );
  }
}
