import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/site.dart';
import '../widgets/navigation_drawer.dart';

class AddSite extends StatefulWidget {
  @override
  _AddSiteState createState() => _AddSiteState();
}

class _AddSiteState extends State<AddSite> {
  final DatabaseHelper dbHelper = DatabaseHelper();

  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _siteLocationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawerWidget(),
      appBar: AppBar(
        title: Text('Add Site'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _siteNameController,
              decoration: InputDecoration(labelText: 'Site Name'),
            ),
            TextField(
              controller: _siteLocationController,
              decoration: InputDecoration(labelText: 'Site Location'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addSite,
              child: Text('Add Site'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSite() async {
    String siteName = _siteNameController.text.trim();
    String siteLocation = _siteLocationController.text.trim();

    if (siteName.isEmpty || siteLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    Site newSite = Site(name: siteName, location: siteLocation);
    await dbHelper.insertSite(newSite);

    setState(() {
      _siteNameController.clear();
      _siteLocationController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Site added successfully')),
    );
  }
}
