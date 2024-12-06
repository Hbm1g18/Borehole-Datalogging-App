import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/borehole.dart';
import '../models/site.dart';

class ViewPostgresBoreholes extends StatefulWidget {
  @override
  _ViewPostgresBoreholesState createState() => _ViewPostgresBoreholesState();
}

class _ViewPostgresBoreholesState extends State<ViewPostgresBoreholes> {
  List<Borehole> _boreholes = [];
  List<Site> _sites = [];
  int? _selectedSiteId;
  bool _isLoading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadPostgresSites();
  }

  Future<void> _loadPostgresSites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('postgres_host');
    String? port = prefs.getString('postgres_port');
    String? database = prefs.getString('postgres_db');
    String? username = prefs.getString('postgres_user');
    String? password = prefs.getString('postgres_pass');

    if (host != null && port != null && database != null && username != null && password != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        List<List<dynamic>> postgresSites = await connection.query('SELECT id, name, location FROM sites');

        List<Site> postgresSiteList = postgresSites.map((row) {
          return Site(
            id: row[0],         
            name: row[1],       
            location: row[2],   
            isPostgres: true,  
          );
        }).toList();

        setState(() {
          _sites = postgresSiteList;
          _status = 'Loaded PostgreSQL sites.';
        });

        await connection.close();
      } catch (e) {
        print('PostgreSQL connection failed: $e');
        setState(() {
          _status = 'PostgreSQL connection failed: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _status = 'PostgreSQL configuration is missing.';
      });
    }
  }

  Future<void> _loadPostgresBoreholes(int siteId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('postgres_host');
    String? port = prefs.getString('postgres_port');
    String? database = prefs.getString('postgres_db');
    String? username = prefs.getString('postgres_user');
    String? password = prefs.getString('postgres_pass');

    if (host != null && port != null && database != null && username != null && password != null) {
      try {
        setState(() {
          _isLoading = true;
          _boreholes = [];
        });

        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        List<List<dynamic>> postgresBoreholes = await connection.query(
          'SELECT id, reference, xyPosition, casing FROM boreholes WHERE site_id = @siteId',
          substitutionValues: {'siteId': siteId},
        );

        List<Borehole> postgresBoreholeList = postgresBoreholes.map((row) {
          return Borehole(
            id: row[0],
            name: row[1], 
            xyPosition: row[2], 
            mAOD: row[3], 
            siteId: siteId,
          );
        }).toList();

        setState(() {
          _boreholes = postgresBoreholeList;
          _status = 'Loaded boreholes for selected site.';
        });

        await connection.close();
      } catch (e) {
        print('PostgreSQL borehole fetch failed: $e');
        setState(() {
          _status = 'PostgreSQL borehole fetch failed: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _status = 'PostgreSQL configuration is missing.';
      });
    }
  }

  Future<void> _addSite(String name, String location) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('postgres_host');
    String? port = prefs.getString('postgres_port');
    String? database = prefs.getString('postgres_db');
    String? username = prefs.getString('postgres_user');
    String? password = prefs.getString('postgres_pass');

    if (host != null && port != null && database != null && username != null && password != null) {
      try {
        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        await connection.query(
          'INSERT INTO sites (name, location) VALUES (@name, @location)',
          substitutionValues: {
            'name': name,
            'location': location,
          },
        );

        setState(() {
          _status = 'Site added successfully.';
        });

        await connection.close();

        await _loadPostgresSites();
      } catch (e) {
        print('Failed to add site: $e');
        setState(() {
          _status = 'Failed to add site: $e';
        });
      }
    } else {
      setState(() {
        _status = 'PostgreSQL configuration is missing.';
      });
    }
  }

  Future<void> _addBorehole(String reference, String xyPosition, double casing) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? host = prefs.getString('postgres_host');
    String? port = prefs.getString('postgres_port');
    String? database = prefs.getString('postgres_db');
    String? username = prefs.getString('postgres_user');
    String? password = prefs.getString('postgres_pass');

    if (host != null && port != null && database != null && username != null && password != null) {
      try {
        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        await connection.query(
          'INSERT INTO boreholes (reference, xyPosition, casing, site_id) VALUES (@reference, @xyPosition, @casing, @siteId)',
          substitutionValues: {
            'reference': reference,
            'xyPosition': xyPosition,
            'casing': casing,
            'siteId': _selectedSiteId,
          },
        );

        setState(() {
          _status = 'Borehole added successfully.';
        });

        await connection.close();

        if (_selectedSiteId != null) {
          await _loadPostgresBoreholes(_selectedSiteId!);
        }
      } catch (e) {
        print('Failed to add borehole: $e');
        setState(() {
          _status = 'Failed to add borehole: $e';
        });
      }
    } else {
      setState(() {
        _status = 'PostgreSQL configuration is missing.';
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
            _loadPostgresBoreholes(newValue);
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

  void _showAddSiteDialog() {
    String name = '';
    String location = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Site'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Site Name'),
                onChanged: (value) {
                  name = value;
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Location'),
                onChanged: (value) {
                  location = value;
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty && location.isNotEmpty) {
                  _addSite(name, location);
                  Navigator.of(context).pop();  // Close the dialog
                } else {
                  setState(() {
                    _status = 'Please fill all fields.';
                  });
                }
              },
              child: Text('Add Site'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PostgreSQL Boreholes'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _siteDropdown(),
                SizedBox(height: 20),
                if (_selectedSiteId != null) ...[
                  Expanded(
                    child: ListView.builder(
                      itemCount: _boreholes.length,
                      itemBuilder: (context, index) {
                        final borehole = _boreholes[index];
                        return ListTile(
                          title: Text(borehole.name),
                          subtitle: Text(
                            'XY: ${borehole.xyPosition}, Casing: ${borehole.mAOD}',
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showAddBoreholeDialog(),
                    child: Text('Add Borehole'),
                  ),
                  SizedBox(height: 20),
                ],
                ElevatedButton(
                  onPressed: () => _showAddSiteDialog(),
                  child: Text('Add Site'),
                ),
                Text(_status),
              ],
            ),
    );
  }

  void _showAddBoreholeDialog() {
    String reference = '';
    String xyPosition = '';
    double casing = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Borehole'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Reference'),
                onChanged: (value) {
                  reference = value;
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: 'XY Position'),
                onChanged: (value) {
                  xyPosition = value;
                },
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Casing (mAOD)'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  casing = double.tryParse(value) ?? 0.0;
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reference.isNotEmpty && xyPosition.isNotEmpty && casing > 0) {
                  _addBorehole(reference, xyPosition, casing);
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _status = 'Please fill all fields.';
                  });
                }
              },
              child: Text('Add Borehole'),
            ),
          ],
        );
      },
    );
  }
}
