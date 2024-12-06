import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'dart:io'; 
import '../services/db_service.dart';
import '../models/site.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DBService dbService = DBService();
  List<Site> _sites = [];
  int? _selectedSiteId;
  String? _selectedSiteName; 
  List<Map<String, dynamic>> _positions = [];
  LatLng? _mapCenter;
  MapController _mapController = MapController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPostgresSites();
  }

  Future<void> _loadPostgresSites() async {
    try {
      setState(() {
        _isLoading = true;
      });
      List<Site> sites = await dbService.loadPostgresSites();
      setState(() {
        _sites = sites;
        _isLoading = false;
      });
    } catch (e) {
      print('Failed to load sites: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBoreholePositions(int siteId, String siteName) async {
    try {
      setState(() {
        _positions = [];
        _mapCenter = null; 
        _selectedSiteName = siteName;
        _isLoading = true;
      });

      List<Map<String, dynamic>> positions = await dbService.fetchXYPositionsForSite(siteId);

      if (positions.isNotEmpty) {
        _mapCenter = LatLng(positions[0]['latitude'], positions[0]['longitude']);
      }

      setState(() {
        _positions = positions;
        _isLoading = false;
      });
    } catch (e) {
      print('Failed to load borehole positions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _siteDropdown() {
    return DropdownButtonFormField<int>(
      hint: Text('Select Site'),
      value: _selectedSiteId,
      onChanged: (int? newValue) {
        setState(() {
          _selectedSiteId = newValue;
          if (newValue != null) {
            final selectedSite = _sites.firstWhere((site) => site.id == newValue);
            _fetchBoreholePositions(newValue, selectedSite.name); 
          }
        });
      },
      items: _sites.map((Site site) {
        return DropdownMenuItem<int>(
          value: site.id,
          child: Text('${site.name} (${site.location})'),
        );
      }).toList(),
    );
  }

  void _centerMapOnBorehole(LatLng boreholePosition) {
    _mapController.move(boreholePosition, 18.0);
  }

  Future<void> _launchNavigation(double latitude, double longitude) async {
    String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    if (Platform.isAndroid || Platform.isIOS) {
      String googleMapsAppUrl = 'geo:$latitude,$longitude?q=$latitude,$longitude';
      if (await canLaunch(googleMapsAppUrl)) {
        await launch(googleMapsAppUrl);
      } else {
        await launch(googleMapsUrl);
      }
    } else {
      if (await canLaunch(googleMapsUrl)) {
        await launch(googleMapsUrl);
      } else {
        throw 'Could not launch $googleMapsUrl';
      }
    }
  }

  Future<void> _exportKML() async {
    if (_positions.isEmpty || _selectedSiteName == null) {
      print('No boreholes available for export.');
      return;
    }

    String? outputFilePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: '${_selectedSiteName}_boreholes.kml',
      type: FileType.custom,
      allowedExtensions: ['kml'],
    );

    if (outputFilePath != null) {
      String kmlContent = '''
  <?xml version="1.0" encoding="UTF-8"?>
  <kml xmlns="http://www.opengis.net/kml/2.2">
    <Document>
      <name>${_selectedSiteName} Boreholes</name>
      ${_positions.map((pos) => '''
      <Placemark>
        <name>${pos['reference']}</name>
        <description>Casing (mAOD): ${pos['casing']}</description>
        <Point>
          <coordinates>${pos['longitude']},${pos['latitude']},0</coordinates>
        </Point>
      </Placemark>
      ''').join('')}
    </Document>
  </kml>
  '''.trim();  

      File(outputFilePath).writeAsStringSync(kmlContent);
      print('KML file saved: $outputFilePath');
    } else {
      print('KML export cancelled.');
    }
  }

  Widget _boreholeButtonsList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _positions.length,
        itemBuilder: (context, index) {
          final borehole = _positions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ElevatedButton(
              onPressed: () {
                LatLng boreholePosition = LatLng(borehole['latitude'], borehole['longitude']);
                _centerMapOnBorehole(boreholePosition);
              },
              child: Text(borehole['reference']),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Borehole Map View'),
      ),
      body: Column(
        children: [
          _siteDropdown(), 
          SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 200, 
                  child: Column(
                    children: [
                      // Borehole buttons list
                      _positions.isNotEmpty
                          ? _boreholeButtonsList()
                          : Center(child: Text('No boreholes available')),

                      Divider(),
                      ElevatedButton(
                        onPressed: _exportKML,
                        child: Text('Export KML'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: _mapCenter ?? LatLng(0, 0), 
                            zoom: 10.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: ['a', 'b', 'c'],
                            ),
                            MarkerLayer(
                              markers: _positions.map((pos) {
                                return Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: LatLng(pos['latitude'], pos['longitude']),
                                  builder: (ctx) => GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: ctx,
                                        builder: (context) {
                                          return AlertDialog(
                                                                                       title: Text('Borehole Information'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Reference: ${pos['reference']}'),
                                                Text('Casing (mAOD): ${pos['casing']}'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Close'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  _launchNavigation(pos['latitude'], pos['longitude']);
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Navigate to'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40.0,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
