import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/site.dart';
import '../models/borehole.dart';
import '../widgets/navigation_drawer.dart';

class ViewBoreholesList extends StatefulWidget {
  @override
  _ViewBoreholesListState createState() => _ViewBoreholesListState();
}

class _ViewBoreholesListState extends State<ViewBoreholesList> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<Borehole> boreholes = [];
  List<Site> sites = [];
  int? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  // Load all sites to display in the dropdown
  Future<void> _loadSites() async {
    List<Site> allSites = await dbHelper.getAllSites();
    setState(() {
      sites = allSites;
    });
  }

  // Load boreholes based on the selected site
  Future<void> _loadBoreholesForSite(int siteId) async {
    List<Borehole> boreholesForSite = await dbHelper.getBoreholesForSite(siteId);
    setState(() {
      boreholes = boreholesForSite;
    });
  }

  // Delete a borehole
  Future<void> _deleteBorehole(Borehole borehole) async {
    await dbHelper.deleteBorehole(borehole.id!);
    _loadBoreholesForSite(_selectedSiteId!); // Refresh borehole list after deletion
  }

  // Edit a borehole
  Future<void> _editBorehole(Borehole borehole) async {
    TextEditingController nameController = TextEditingController(text: borehole.name);
    TextEditingController xyPositionController = TextEditingController(text: borehole.xyPosition);
    TextEditingController mAODController = TextEditingController(text: borehole.mAOD.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Borehole'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Borehole Name'),
                ),
                TextField(
                  controller: xyPositionController,
                  decoration: InputDecoration(labelText: 'XY Position'),
                ),
                TextField(
                  controller: mAODController,
                  decoration: InputDecoration(labelText: 'mAOD'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Create a new Borehole object with updated values
                Borehole updatedBorehole = Borehole(
                  id: borehole.id,
                  siteId: borehole.siteId,
                  name: nameController.text.trim(),
                  xyPosition: xyPositionController.text.trim(),
                  mAOD: double.parse(mAODController.text.trim()),
                );

                await dbHelper.updateBorehole(updatedBorehole);
                Navigator.pop(context);
                _loadBoreholesForSite(_selectedSiteId!); // Refresh borehole list
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Show options to Edit or Delete
  Future<void> _showBoreholeOptions(Borehole borehole) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Borehole'),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                _editBorehole(borehole); // Open edit dialog
              },
            ),
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete Borehole'),
              onTap: () async {
                Navigator.pop(context); // Close the bottom sheet
                bool confirm = await _confirmDeleteBorehole(borehole);
                if (confirm) {
                  _deleteBorehole(borehole); // Delete borehole if confirmed
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Confirm deletion of a borehole
  Future<bool> _confirmDeleteBorehole(Borehole borehole) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Borehole'),
          content: Text('Are you sure you want to delete this borehole?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawerWidget(),
      appBar: AppBar(
        title: Text('Boreholes List View'),
      ),
      body: Column(
        children: [
          // Dropdown for selecting the site
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: 'Select Site'),
              value: _selectedSiteId,
              onChanged: (int? newValue) {
                setState(() {
                  _selectedSiteId = newValue;
                });
                if (newValue != null) {
                  _loadBoreholesForSite(newValue);
                }
              },
              items: sites.map((Site site) {
                return DropdownMenuItem<int>(
                  value: site.id,
                  child: Text(site.name),
                );
              }).toList(),
            ),
          ),

          // Boreholes list based on the selected site
          Expanded(
            child: boreholes.isEmpty
                ? Center(child: Text('No boreholes available for the selected site'))
                : ListView.builder(
                    itemCount: boreholes.length,
                    itemBuilder: (context, index) {
                      Borehole borehole = boreholes[index];
                      return ListTile(
                        title: Text(borehole.name),
                        subtitle: Text('Position: ${borehole.xyPosition}\nmAOD: ${borehole.mAOD}'),
                        onTap: () => _showBoreholeOptions(borehole), // Show options on tap
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
