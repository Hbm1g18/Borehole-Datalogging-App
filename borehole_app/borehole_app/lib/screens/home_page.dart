import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Import for permissions
import '../widgets/navigation_drawer.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Request storage permissions when homepage loads
  }

  // Function to request storage permission
  Future<void> _requestPermissions() async {
    if (await Permission.storage.request().isGranted) {
      // Permission granted, proceed normally
      print('Storage permission granted');
    } else {
      // Handle the case when permission is denied
      setState(() {
        print('Storage permission denied');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawerWidget(),
      appBar: AppBar(
        title: Text('Borehole Data Manager'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centers the text vertically
          children: [
            Text(
              'WIP Data logger tool',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 0), // Adds some spacing between the texts
            Text(
              'A tool for compensating data with a barologger and exporting processed results.\nThis tool is also designed for use with PostgreSQL databases for live upload and reading of data',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center
            ),
            Divider(),
            SizedBox(height: 20), // Adds some spacing between the texts
            Text(
              'Get Started:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20), // Adds some spacing between the texts
            Row(
              mainAxisAlignment: MainAxisAlignment.center,  // Align buttons to the center horizontally
              children: [
                Text(
                  'Add a site to the local database - ',
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center
                ),
                SizedBox(width: 20),  // Add spacing between the buttons
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/addSite');  // Navigate to the /addsite route
                  },
                  child: Text('Add Site'),
                ),
              ],
            ),
            Text(
              'A site is required to add borehole information to if not using a PostgreSQL data source',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,  // Align buttons to the center horizontally
              children: [
                Text(
                  'Add a Borehole to the local database - ',
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center
                ),
                SizedBox(width: 20),  // Add spacing between the buttons
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/addBorehole');  // Navigate to the /addsite route
                  },
                  child: Text('Add Borehole'),
                ),
              ],
            ),
            Text(
              'Once a site is established, borehole information can be adde.',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,  // Align buttons to the center horizontally
              children: [
                Text(
                  'Process CSV data for boreholes - ',
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center
                ),
                SizedBox(width: 20),  // Add spacing between the buttons
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/uploadCsv');  // Navigate to the /addsite route
                  },
                  child: Text('Process Data'),
                ),
              ],
            ),
            Text(
              'With both site information and borehole information added, processing of data can be undertaken.\n If using PostgreSQL, this option is also available for pushing data to the database',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center
            ),
            Divider(),
            SizedBox(height: 20),
            Text(
              'Get Started:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20), // Adds some spacing between the texts
            Row(
              mainAxisAlignment: MainAxisAlignment.center,  // Align buttons to the center horizontally
              children: [
                Text(
                  'Configure PostgreSQL for use with the app - ',
                  style: TextStyle(fontSize: 20),
                  textAlign: TextAlign.center
                ),
                SizedBox(width: 20),  // Add spacing between the buttons
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/postgresConfig');  // Navigate to the /addsite route
                  },
                  child: Text('Configure PostgreSQL'),
                ),
              ],
            ),
            Text(
              'Configuration settings for PostgreSQL can be found here.\nThis page also allows for the generation of the required tables within your database.',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center
            ),
            SizedBox(height: 15,)

            
          ],
        ),
      ),
    );
  }
}