import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/borehole.dart';
import '../models/site.dart'; // Ensure the correct import of the Site model
import '../widgets/navigation_drawer.dart';

class AddBorehole extends StatefulWidget {
  @override
  _AddBoreholeState createState() => _AddBoreholeState();
}

class _AddBoreholeState extends State<AddBorehole> {
  final DatabaseHelper dbHelper = DatabaseHelper();

  final TextEditingController _boreholeNameController = TextEditingController();
  final TextEditingController _boreholePositionController = TextEditingController();
  final TextEditingController _boreholeMaoDController = TextEditingController();

  int? _selectedSiteId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawerWidget(),
      appBar: AppBar(
        title: Text('Add Borehole'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            FutureBuilder<List<DropdownMenuItem<int>>>(
              future: _siteDropdownItems(),
              builder: (BuildContext context, AsyncSnapshot<List<DropdownMenuItem<int>>> snapshot) {
                if (!snapshot.hasData) {
                  return CircularProgressIndicator();
                }

                return DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: 'Select Site'),
                  value: _selectedSiteId,
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedSiteId = newValue;
                    });
                  },
                  items: snapshot.data,
                  validator: (value) => value == null ? 'Please select a site' : null,
                );
              },
            ),
            TextField(
              controller: _boreholeNameController,
              decoration: InputDecoration(labelText: 'Borehole Name'),
            ),
            TextField(
              controller: _boreholePositionController,
              decoration: InputDecoration(labelText: 'Borehole Position (XY)'),
            ),
            TextField(
              controller: _boreholeMaoDController,
              decoration: InputDecoration(labelText: 'mAOD'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addBorehole,
              child: Text('Add Borehole'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBorehole() async {
    if (_selectedSiteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a site')),
      );
      return;
    }

    String boreholeName = _boreholeNameController.text.trim();
    String boreholePosition = _boreholePositionController.text.trim();
    String maoDText = _boreholeMaoDController.text.trim();

    if (boreholeName.isEmpty || boreholePosition.isEmpty || maoDText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    double mAOD;
    try {
      mAOD = double.parse(maoDText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid mAOD value')),
      );
      return;
    }

    Borehole newBorehole = Borehole(
      siteId: _selectedSiteId!,
      name: boreholeName,
      xyPosition: boreholePosition,
      mAOD: mAOD,
    );

    await dbHelper.insertBorehole(newBorehole);

    setState(() {
      _boreholeNameController.clear();
      _boreholePositionController.clear();
      _boreholeMaoDController.clear();
      _selectedSiteId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Borehole added successfully')),
    );
  }

  Future<List<DropdownMenuItem<int>>> _siteDropdownItems() async {
    List<Site> sites = await dbHelper.getAllSites();
    return sites.map((site) {
      return DropdownMenuItem<int>(
        value: site.id,
        child: Text(site.name),
      );
    }).toList();
  }
}
