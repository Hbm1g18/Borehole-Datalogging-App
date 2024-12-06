import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/site.dart';
import '../models/borehole.dart';
import 'package:intl/intl.dart';

class BoreholeDataGraph extends StatefulWidget {
  @override
  _BoreholeDataGraphState createState() => _BoreholeDataGraphState();
}

class _BoreholeDataGraphState extends State<BoreholeDataGraph> {
  List<Site> _sites = [];
  List<Borehole> _boreholes = [];
  int? _selectedSiteId;
  int? _selectedBoreholeId;
  String? _selectedBoreholeName;
  DateTimeRange? _dateRange;
  List<FlSpot> _graphData = [];
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
    }
  }

  Future<void> _fetchBoreholeData(String boreholeName) async {
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
          _graphData = [];
        });

        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        var result = await connection.query(
          "SELECT MIN(datetime::date), MAX(datetime::date) FROM water_data WHERE borehole = @boreholeName",
          substitutionValues: {'boreholeName': boreholeName},
        );

        if (result.isNotEmpty) {
          DateTime startDate = DateTime.parse(result[0][0].toString());
          DateTime endDate = DateTime.parse(result[0][1].toString());

          setState(() {
            _dateRange = DateTimeRange(start: startDate, end: endDate);
          });

          await _fetchWaterData(boreholeName, _dateRange!);
        }

        await connection.close();
      } catch (e) {
        print('PostgreSQL borehole data fetch failed: $e');
        setState(() {
          _status = 'PostgreSQL borehole data fetch failed: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<List<dynamic>> _filterDynamicSpikes(List<List<dynamic>> waterData, double spikeThreshold) {
    if (waterData.length < 3) return waterData;

    List<List<dynamic>> filteredData = [];

    for (int i = 1; i < waterData.length - 1; i++) {
      double previousWaterLevel = waterData[i - 1][1];
      double currentWaterLevel = waterData[i][1];
      double nextWaterLevel = waterData[i + 1][1];
      bool isSpike = (currentWaterLevel - previousWaterLevel).abs() > spikeThreshold &&
                    (currentWaterLevel - nextWaterLevel).abs() > spikeThreshold;

      if (!isSpike) {
        filteredData.add(waterData[i]); 
      }
    }

    filteredData.insert(0, waterData.first);
    filteredData.add(waterData.last);

    return filteredData;
  }

  Future<void> _fetchWaterData(String boreholeName, DateTimeRange dateRange) async {
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
          _graphData = [];
        });

        PostgreSQLConnection connection = PostgreSQLConnection(
          host,
          int.tryParse(port) ?? 5432,
          database,
          username: username,
          password: password,
        );
        await connection.open();

        // Ensure startDate has 00:00:00 and endDate has 23:59:59
        String formattedStartDate = DateFormat('yyyy-MM-dd').format(dateRange.start) + ' 00:00:00';
        String formattedEndDate = DateFormat('yyyy-MM-dd').format(dateRange.end) + ' 23:59:59';

        List<List<dynamic>> waterData = await connection.query(
          '''
          SELECT datetime, water_level 
          FROM water_data 
          WHERE borehole = @boreholeName 
          AND datetime BETWEEN @startDate AND @endDate 
          ORDER BY datetime
          ''',
          substitutionValues: {
            'boreholeName': boreholeName,  
            'startDate': formattedStartDate, 
            'endDate': formattedEndDate,
          },
        );

        double spikeThreshold = 2;
        List<List<dynamic>> filteredData = _filterDynamicSpikes(waterData, spikeThreshold);

        List<FlSpot> graphPoints = filteredData.map((row) {
          DateTime date = row[0];
          double waterLevel = row[1];
          return FlSpot(date.millisecondsSinceEpoch.toDouble(), waterLevel);
        }).toList();

        setState(() {
          _graphData = _filterOutliers(graphPoints);
          _status = 'Water data loaded, filtered, and graph plotted.';
        });

        await connection.close();
      } catch (e) {
        print('PostgreSQL water data fetch failed: $e');
        setState(() {
          _status = 'PostgreSQL water data fetch failed: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<FlSpot> _filterOutliers(List<FlSpot> graphData) {
    if (graphData.isEmpty) return graphData;
    
    List<FlSpot> filteredData = [];
    double threshold = 2.0;

    for (int i = 0; i < graphData.length; i++) {
      if (i == 0 || i == graphData.length - 1) {
        filteredData.add(graphData[i]);
      } else {
        double current = graphData[i].y;
        double previous = graphData[i - 1].y;
        double next = graphData[i + 1].y;
        double deviationFromNeighbors = (current - previous).abs() + (current - next).abs();

        if (deviationFromNeighbors <= threshold) {
          filteredData.add(graphData[i]);
        } else {
          print('Filtered out spike at ${graphData[i].x} with value ${graphData[i].y}');
        }
      }
    }

    return filteredData;
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

  // Dropdown for borehole selection
  Widget _boreholeDropdown() {
    return DropdownButtonFormField<int>(
      hint: Text('Select Borehole'),
      value: _selectedBoreholeId,
      onChanged: (int? newValue) {
        setState(() {
          _selectedBoreholeId = newValue;
          if (newValue != null) {
            _selectedBoreholeName = _boreholes.firstWhere((borehole) => borehole.id == newValue).name;
            _fetchBoreholeData(_selectedBoreholeName!);
          }
        });
      },
      items: _boreholes.map((Borehole borehole) {
        return DropdownMenuItem<int>(
          value: borehole.id,
          child: Text(borehole.name),
        );
      }).toList(),
    );
  }

  Widget _dateRangePicker() {
    return ElevatedButton(
      onPressed: () async {
        DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          initialDateRange: _dateRange,
        );
        if (picked != null && picked != _dateRange) {
          setState(() {
            _dateRange = picked;
          });

          if (_selectedBoreholeName != null) {
            await _fetchWaterData(_selectedBoreholeName!, picked);
          }
        }
      },
      child: Text(
        _dateRange == null
            ? 'Pick Date Range'
            : '${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}',
      ),
    );
  }

  Widget _buildLineChart(BuildContext context) {
    if (_graphData.isEmpty) {
      return Center(child: Text('No data to display'));
    }

    double minX = _graphData.first.x;
    double maxX = _graphData.last.x;
    Duration timeRange = DateTime.fromMillisecondsSinceEpoch(maxX.toInt())
        .difference(DateTime.fromMillisecondsSinceEpoch(minX.toInt()));

    double screenWidth = MediaQuery.of(context).size.width;
    double chartWidth = screenWidth * 0.95;

    return Center(
      child: SizedBox(
        width: chartWidth,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: _graphData,
                isCurved: true,
                color: Colors.blue,
                barWidth: 1, 
                dotData: FlDotData(
                  show: true, 
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 2,
                      color: Colors.blue,
                      strokeWidth: 0.2,  
                      strokeColor: Colors.blue, 
                    );
                  },
                ),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: _calculateXInterval(timeRange), 
                  getTitlesWidget: (value, meta) {
                    DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());

                    String formattedLabel;
                    if (timeRange.inDays > 30) {
                      formattedLabel = DateFormat('yyyy-MM').format(date); 
                    } else if (timeRange.inDays > 1) {
                      formattedLabel = DateFormat('MM-dd').format(date); 
                    } else {
                      formattedLabel = DateFormat('HH:mm').format(date); 
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0), 
                      child: Transform.rotate(
                        angle: -0.5, 
                        child: Text(formattedLabel),
                      ),
                    );
                  },
                  reservedSize: 40, 
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, 
                  reservedSize: 50,  
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false), 
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false), 
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true, 
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey,
                  strokeWidth: 1,     
                );
              },
              drawHorizontalLine: true, 
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey,
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                color: Colors.black,
                width: 1,
              ),
            ),
            minX: minX,
            maxX: maxX,
            minY: _graphData.map((e) => e.y).reduce((a, b) => a < b ? a : b), 
            maxY: _graphData.map((e) => e.y).reduce((a, b) => a > b ? a : b), 
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (FlSpot spot) => Colors.white,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);
                    return LineTooltipItem(
                      'Water Level: ${spot.y.toStringAsFixed(2)}\nDate: $formattedDate',
                      TextStyle(color: Colors.black),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateXInterval(Duration timeRange) {
    if (timeRange.inDays > 30) {
      return 30 * 24 * 60 * 60 * 1000.0;
    } else if (timeRange.inDays > 1) {
      return 24 * 60 * 60 * 1000.0; 
    } else {
      return 60 * 60 * 1000.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Borehole Water Level Graph'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _siteDropdown(),
                  SizedBox(height: 20),
                  _boreholeDropdown(),
                  SizedBox(height: 20),
                  _dateRangePicker(),
                  SizedBox(height: 20),
                  Expanded(child: _graphData.isEmpty ? Center(child: Text('No data to display')) : _buildLineChart(context)),
                  Text(_status),
                ],
              ),
            ),
    );
  }
}

