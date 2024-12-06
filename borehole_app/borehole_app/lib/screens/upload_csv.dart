import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting dates
import 'package:file_picker/file_picker.dart';  // Import for FilePicker
import 'package:path/path.dart';
import 'package:csv/csv.dart';
import '../database_helper.dart';
import '../models/borehole.dart';
import '../models/site.dart';
import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadCsv extends StatefulWidget {
  @override
  _UploadCsvState createState() => _UploadCsvState();
}

class _UploadCsvState extends State<UploadCsv> {
  List<List<dynamic>> _waterLoggerData = [];
  List<List<dynamic>> _baroLoggerData = [];
  List<List<dynamic>> _processedData = [];
  List<Borehole> boreholes = [];
  List<Site> sites = [];
  int? _selectedSiteId;
  int? _selectedBoreholeId;
  String _dataSource = 'local'; // Default to local
  String _selectedDataType = 'VuSitu'; // Default data type selection
  double dipValue = 0.0;
  double selectedMaoD = 0.0;
  bool _isProcessing = false;
  String _status = '';
  double _progressValue = 0.0; // Add progress tracking

  int rowsToSkipWater = 69;
  int rowsToSkipBaro = 63;

  @override
  void initState() {
    super.initState();
    _loadSites(); // Load local sites initially
  }

  // Function to load sites based on the selected data source
  Future<void> _loadSites() async {
    if (_dataSource == 'local') {
      await _loadLocalSites();
    } else if (_dataSource == 'postgres') {
      await _loadPostgresSites();
    }
  }

  // Load local sites
  Future<void> _loadLocalSites() async {
    final dbHelper = DatabaseHelper();
    List<Site> localSites = await dbHelper.getAllSites();
    setState(() {
      sites = localSites.map((site) => Site(
        id: site.id,
        name: site.name,
        location: site.location,
        isPostgres: false,
      )).toList();
      _status = 'Loaded local sites.';
    });
  }

  // Load PostgreSQL sites
  Future<void> _loadPostgresSites() async {
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

        // Fetch site data from PostgreSQL
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
          sites = postgresSiteList;
          _status = 'Loaded PostgreSQL sites.';
        });

        await connection.close();
      } catch (e) {
        print('PostgreSQL connection failed: $e');
        setState(() {
          _status = 'PostgreSQL connection failed: $e';
        });
      }
    } else {
      setState(() {
        _status = 'PostgreSQL configuration is missing.';
      });
    }
  }
  // Load boreholes based on the selected site
Future<void> _loadBoreholesForSite(int siteId) async {
  final dbHelper = DatabaseHelper();

  // Check if the selected site is from PostgreSQL
  bool isPostgres = sites.any((site) => site.id == siteId && site.isPostgres);

  if (isPostgres) {
    // Fetch boreholes from PostgreSQL
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

        // Fetch borehole data from PostgreSQL
        List<List<dynamic>> postgresBoreholes = await connection.query(
          'SELECT id, reference, xyPosition, casing FROM boreholes WHERE site_id = @siteId',
          substitutionValues: {'siteId': siteId},
        );

        List<Borehole> postgresBoreholeList = postgresBoreholes.map((row) {
          return Borehole(
            id: row[0], // Borehole ID
            name: row[1], // Reference name
            xyPosition: row[2], // XY position
            mAOD: row[3], // Casing/mAOD value
            siteId: siteId,
          );
        }).toList();

        setState(() {
          boreholes = postgresBoreholeList;
        });

        await connection.close();
      } catch (e) {
        print('PostgreSQL boreholes fetch failed: $e');
        setState(() {
          _status = 'PostgreSQL boreholes fetch failed: $e';
        });
      }
    }
  } else {
    // Fetch boreholes from local SQLite database
    List<Borehole> boreholesForSite = await dbHelper.getBoreholesForSite(siteId);
    setState(() {
      boreholes = boreholesForSite;
    });
  }
}


  // Function to pick and parse the CSV file
  Future<List<List<dynamic>>> pickCsvFile(int rowsToSkip) async {
    try {
      // Use FilePicker to let the user select a CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        // If a file is selected, read the file
        File file = File(result.files.single.path!);
        String fileContent = await file.readAsString();

        // Parse the CSV file
        List<List<dynamic>> csvTable = const CsvToListConverter().convert(fileContent);

        // Skip the defined number of rows
        if (csvTable.length > rowsToSkip) {
          return csvTable.sublist(rowsToSkip);  // Skip rows and return actual data
        } else {
          return [];
        }
      } else {
        // If the user cancels the file picker
        return [];
      }
    } catch (e) {
      print('Error picking or reading CSV file: $e');
      return [];
    }
  }

  // Function to upload water logger CSV (only load the data)
  Future<void> _uploadWaterLoggerCsv() async {
    setState(() {
      _isProcessing = true;
      _status = 'Uploading Water Logger CSV...';
    });

    List<List<dynamic>> waterLoggerData = await pickCsvFile(rowsToSkipWater);

    setState(() {
      _waterLoggerData = waterLoggerData;
      _status = 'Water Logger CSV uploaded successfully.';
      _isProcessing = false;
    });
  }

  // Function to upload baro logger CSV (only load the data)
  Future<void> _uploadBaroLoggerCsv() async {
    setState(() {
      _isProcessing = true;
      _status = 'Uploading Baro Logger CSV...';
    });

    List<List<dynamic>> baroLoggerData = await pickCsvFile(rowsToSkipBaro);

    setState(() {
      _baroLoggerData = baroLoggerData;
      _status = 'Baro Logger CSV uploaded successfully.';
      _isProcessing = false;
    });
  }

  // Function to change row skipping logic based on selected data type
  void _updateRowSkipping() {
    if (_selectedDataType == 'VuSitu') {
      rowsToSkipWater = 69;
      rowsToSkipBaro = 63;
    } else if (_selectedDataType == 'WinSitu') {
      rowsToSkipWater = 68;
      rowsToSkipBaro = 69;
    }
  }


  // Export CSV (Process data at this point)
  Future<void> _exportCsv() async {
    if (_waterLoggerData.isNotEmpty && _baroLoggerData.isNotEmpty && _selectedBoreholeId != null) {
      // Process the data before exporting
      List<List<dynamic>> processedData = _processData();  // Process the data, includes applying dip

      if (processedData.isEmpty) {
        setState(() {
          _status = 'No matching timestamps found for processing.';
        });
        return;
      }

      // Ensure dip is applied and data is recalculated
      _applyDipAndCalculateMAOD(processedData);

      // Prepare the CSV data, but include only the required columns
      List<List<dynamic>> finalCsvData = processedData.map((row) {
        return [row[0], row[2], row[3], row[4]];  // Keep only datetime, mAOD_depth, borehole, site
      }).toList();

      // Format the current date
      String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Get the borehole name
      Borehole selectedBorehole = boreholes.firstWhere((b) => b.id == _selectedBoreholeId);
      String boreholeName = selectedBorehole.name;

      // Generate the filename
      String fileName = '${boreholeName}_${formattedDate}_processed.csv';

      // Let user pick the destination folder
      String? outputDirectory = await FilePicker.platform.getDirectoryPath();

      if (outputDirectory != null) {
        String filePath = join(outputDirectory, fileName);

        // Convert the selected data to CSV
        String csv = const ListToCsvConverter().convert(finalCsvData);

        // Save file to the selected location
        final file = File(filePath);
        await file.writeAsString(csv);  // Write CSV content to file

        setState(() {
          _waterLoggerData = [];
          _baroLoggerData = [];
          _processedData = [];
          _status = 'Data exported to $filePath and cleared. Ready for next upload.';
        });
      } else {
        setState(() {
          _status = 'Export cancelled by user.';
        });
      }
    } else {
      setState(() {
        _status = 'No data to export or borehole not selected.';
      });
    }
  }


  Future<void> _pushDataToPostgres() async {
    if (_waterLoggerData.isNotEmpty && _baroLoggerData.isNotEmpty && _selectedBoreholeId != null) {
      // Process the data (same as Export CSV)
      List<List<dynamic>> processedData = _processData();

      if (processedData.isEmpty) {
        setState(() {
          _status = 'No matching timestamps found for processing.';
        });
        return;
      }

      // Apply the dip value and calculate mAOD depths
      _applyDipAndCalculateMAOD(processedData);

      // Extract the start and end dates from the processed data
      String startDateString = processedData[1][0]; // First valid data row
      String endDateString = processedData.last[0]; // Last row

      // Parse start and end dates
      final inputFormat = DateFormat('dd/MM/yyyy HH:mm');
      DateTime startDate = inputFormat.parse(startDateString);
      DateTime endDate = inputFormat.parse(endDateString);

      // Remove the header row before pushing to PostgreSQL
      List<List<dynamic>> dataToPush = processedData.skip(1).toList(); // Skip header row

      // Retrieve PostgreSQL connection details from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? host = prefs.getString('postgres_host');
      String? port = prefs.getString('postgres_port');
      String? database = prefs.getString('postgres_db');
      String? username = prefs.getString('postgres_user');
      String? password = prefs.getString('postgres_pass');

      // Ensure PostgreSQL credentials are present
      if (host == null || port == null || database == null || username == null || password == null) {
        setState(() {
          _status = 'PostgreSQL configuration is incomplete.';
        });
        return;
      }

      try {
        // Open the PostgreSQL connection
        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        // Get borehole and site details from the first row
        String borehole = dataToPush.first[3]; // Borehole column
        String site = dataToPush.first[4];     // Site column

        // Step 1: Check if data exists for the borehole and site within the given date range
        List<List<dynamic>> existingData = await connection.query(
          'SELECT datetime FROM water_data WHERE borehole = @borehole AND site = @site AND datetime BETWEEN @startDate AND @endDate',
          substitutionValues: {
            'borehole': borehole,
            'site': site,
            'startDate': startDate,
            'endDate': endDate,
          },
        );

        // Step 2: If data exists, delete the old data in that range
        if (existingData.isNotEmpty) {
          await connection.query(
            'DELETE FROM water_data WHERE borehole = @borehole AND site = @site AND datetime BETWEEN @startDate AND @endDate',
            substitutionValues: {
              'borehole': borehole,
              'site': site,
              'startDate': startDate,
              'endDate': endDate,
            },
          );
          print('Old data in range deleted successfully.');
        }

        // **Batch Insertion** (insert multiple rows at once)
        const int batchSize = 500;  // Adjust the batch size based on performance
        int totalRows = dataToPush.length;
        int processedRows = 0;

        for (int i = 0; i < totalRows; i += batchSize) {
          // Get the batch of rows to insert
          List<List<dynamic>> batch = dataToPush.sublist(i, i + batchSize > totalRows ? totalRows : i + batchSize);

          // Prepare values for batch insert
          String query = 'INSERT INTO water_data (datetime, water_level, borehole, site) VALUES ';
          List<String> values = [];
          Map<String, dynamic> substitutionValues = {};

          // Create a bulk insert query with substitution values
          for (int j = 0; j < batch.length; j++) {
            String datetimeString = batch[j][0];
            DateTime parsedDatetime = inputFormat.parse(datetimeString);
            double maodDepth = batch[j][2];
            String borehole = batch[j][3];
            String site = batch[j][4];

            values.add('(@datetime$j, @water_level$j, @borehole$j, @site$j)');
            substitutionValues['datetime$j'] = parsedDatetime;
            substitutionValues['water_level$j'] = maodDepth;
            substitutionValues['borehole$j'] = borehole;
            substitutionValues['site$j'] = site;
          }

          // Final query for batch insertion
          query += values.join(', ');

          // Execute the query with substitution values as a named parameter
          await connection.query(query, substitutionValues: substitutionValues);

          // Update progress
          processedRows += batch.length;
          setState(() {
            _progressValue = processedRows / totalRows; // Update progress percentage
          });
        }

        // Close PostgreSQL connection
        await connection.close();

        setState(() {
          _status = 'Data successfully pushed to PostgreSQL!';
          _waterLoggerData = [];
          _baroLoggerData = [];
          _processedData = [];
          _progressValue = 0.0; // Reset progress after completion
        });
      } catch (e) {
        setState(() {
          _status = 'Failed to push data to PostgreSQL: $e';
          _progressValue = 0.0; // Reset progress in case of error
        });
      }
    }
  }




  // Dropdown for selecting data source (local or postgres)
  Widget _dataSourceDropdown() {
    return DropdownButtonFormField<String>(
      value: _dataSource,
      onChanged: (String? newValue) {
        setState(() {
          _dataSource = newValue!;
          _selectedSiteId = null; // Reset selected site when data source changes
          sites = [];
          _loadSites(); // Load sites based on the selected data source
        });
      },
      items: [
        DropdownMenuItem(
          value: 'local',
          child: Text('Use Local Database'),
        ),
        DropdownMenuItem(
          value: 'postgres',
          child: Text('Use PostgreSQL'),
        ),
      ],
    );
  }

  // Dropdown for selecting data type (VuSitu or WinSitu)
  Widget _dataTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDataType,
      onChanged: (String? newValue) {
        setState(() {
          _selectedDataType = newValue!;
          _updateRowSkipping();  
        });
      },
      items: [
        DropdownMenuItem(
          value: 'VuSitu',
          child: Text('VuSitu'),
        ),
        DropdownMenuItem(
          value: 'WinSitu',
          child: Text('WinSitu'),
        ),
      ],
    );
  }

  Widget _siteDropdown() {
    return DropdownButtonFormField<int>(
      hint: Text('Select Site'),
      value: _selectedSiteId,
      onChanged: (int? newValue) {
        setState(() {
          _selectedSiteId = newValue;
          _selectedBoreholeId = null; 
          boreholes = [];
          if (newValue != null) {
            _loadBoreholesForSite(newValue);
          }
        });
      },
      items: sites.map((Site site) {
        return DropdownMenuItem<int>(
          value: site.id,
          child: Text('${site.name} (${site.location})'),
        );
      }).toList(),
    );
  }

  Widget _boreholeDropdown() {
    return DropdownButtonFormField<int>(
      hint: Text('Select Borehole'),
      value: _selectedBoreholeId,
      onChanged: (int? newValue) {
        setState(() {
          _selectedBoreholeId = newValue;
          if (newValue != null) {
            selectedMaoD = boreholes.firstWhere((borehole) => borehole.id == newValue).mAOD;
          }
        });
      },
      items: boreholes.map((Borehole borehole) {
        return DropdownMenuItem<int>(
          value: borehole.id,
          child: Text(borehole.name),
        );
      }).toList(),
    );
  }

  List<List<dynamic>> _processData() {
    List<List<dynamic>> processedData = [];
    processedData.add(['datetime', 'compensated_depth', 'mAOD_depth', 'borehole', 'site']);  

    Map<String, double> baroPressureMap = _getBaroPressureMap(_baroLoggerData);
    Borehole selectedBorehole = boreholes.firstWhere((b) => b.id == _selectedBoreholeId);
    String siteName = sites.firstWhere((s) => s.id == _selectedSiteId).name;
    String boreholeName = selectedBorehole.name;

    for (int i = 1; i < _waterLoggerData.length; i++) {
      String timestamp = _waterLoggerData[i][0]; 
      double waterPressure = _parseToDouble(_waterLoggerData[i][2]); 
      double waterDepth = _parseToDouble(_waterLoggerData[i][3]); 

      if (baroPressureMap.containsKey(timestamp)) {
        double baroPressure = baroPressureMap[timestamp]!;  
        double compensatedPressure = waterPressure - baroPressure;

        if (waterPressure != 0) {
          double compensatedDepth = (waterDepth / waterPressure) * compensatedPressure;

          processedData.add([timestamp, compensatedDepth, 0.0, boreholeName, siteName]);
        }
      }
    }

    _applyDipAndCalculateMAOD(processedData);

    return processedData;
  }



  void _applyDipAndCalculateMAOD(List<List<dynamic>> processedData) {
    if (processedData.length <= 1) {
      return; 
    }

    double bottom_mAOD = selectedMaoD - dipValue; 

    double finalCompensatedDepth = _parseToDouble(processedData.last[1]);  

    processedData.last[2] = bottom_mAOD; 

    for (int i = processedData.length - 2; i >= 1; i--) { 
      double currentCompensatedDepth = _parseToDouble(processedData[i][1]); 

      processedData[i][2] = bottom_mAOD - (finalCompensatedDepth - currentCompensatedDepth);
    }
  }




  Map<String, double> _getBaroPressureMap(List<List<dynamic>> baroData) {
    Map<String, double> baroPressureMap = {};

    for (int i = 1; i < baroData.length; i++) {
      String timestamp = baroData[i][0]; 
      double baroPressure = _parseToDouble(baroData[i][2]); 
      baroPressureMap[timestamp] = baroPressure;
    }

    return baroPressureMap;
  }

  double _parseToDouble(dynamic value) {
    try {
      if (value is String) {
        return double.parse(value.replaceAll(",", "").trim());
      } else if (value is double) {
        return value;
      }
    } catch (e) {
      print('Error parsing value: $value');
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload CSV'),
      ),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(), 
                  SizedBox(height: 20),
                  Text(_status),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FractionallySizedBox(
                      widthFactor: 0.2, 
                      child: _dataSourceDropdown(),
                    ),
                    SizedBox(height: 20),

                    FractionallySizedBox(
                      widthFactor: 0.5, 
                      child: _dataTypeDropdown(), 
                    ),
                    SizedBox(height: 20),
                    
                    FractionallySizedBox(
                      widthFactor: 0.5, 
                      child: _siteDropdown(),
                    ),
                    SizedBox(height: 20),
                    
                    FractionallySizedBox(
                      widthFactor: 0.5,
                      child: _boreholeDropdown(),
                    ),
                    SizedBox(height: 20),
                    
                    FractionallySizedBox(
                      widthFactor: 0.2, // 30% width
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Enter Dip value'),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          dipValue = double.tryParse(value) ?? 0.0;
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    // ElevatedButton(
                    //   onPressed: _uploadWaterLoggerCsv,
                    //   child: Text('Upload Water Logger CSV'),
                    // ),
                    // SizedBox(height: 20),
                    // ElevatedButton(
                    //   onPressed: _uploadBaroLoggerCsv,
                    //   child: Text('Upload Baro Logger CSV'),
                    // ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        ElevatedButton(
                          onPressed: _uploadWaterLoggerCsv,
                          child: Text('Upload Water Logger CSV'),
                        ),
                        SizedBox(width: 20), 
                        ElevatedButton(
                          onPressed: _uploadBaroLoggerCsv,  
                          child: Text('Upload Baro Logger CSV'),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),
                    // ElevatedButton(
                    //   onPressed: _exportCsv,
                    //   child: Text('Export Processed Data to CSV'),
                    // ),
                    // SizedBox(height: 20),
                    // // Add the new "Push to PostgreSQL" button here
                    // ElevatedButton(
                    //   onPressed: _dataSource == 'postgres' ? _pushDataToPostgres : null,
                    //   child: Text('Push Data to PostgreSQL'),
                    // ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _exportCsv,
                          child: Text('Export Processed Data to CSV'),
                        ),
                        SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: _dataSource == 'postgres' ? _pushDataToPostgres : null,
                          child: Text('Push Data to PostgreSQL'),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    if (_progressValue > 0)
                      Column(
                        children: [
                          LinearProgressIndicator(value: _progressValue), // Progress bar
                          Text('${(_progressValue * 100).toStringAsFixed(0)}% pushed'),
                        ],
                      ),
                    SizedBox(height: 20),
                    Text(_status),
                  ],
                ),
              ),
      ),
    );
  }
}