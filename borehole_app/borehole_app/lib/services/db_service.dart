import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/site.dart';

class DBService {
  PostgreSQLConnection? _connection;

  Future<void> connect() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? host = prefs.getString('postgres_host');
    String? port = prefs.getString('postgres_port');
    String? database = prefs.getString('postgres_db');
    String? username = prefs.getString('postgres_user');
    String? password = prefs.getString('postgres_pass');

    host ??= 'localhost';
    port ??= '5432';
    database ??= 'borehole_db';
    username ??= 'postgres';
    password ??= '';

    _connection = PostgreSQLConnection(
      host,
      int.parse(port),
      database,
      username: username,
      password: password,
    );

    await _connection!.open();
    print('Connected to PostgreSQL database.');
  }

  Future<PostgreSQLConnection> get connection async {
    if (_connection == null || _connection!.isClosed) {
      await connect();
    }
    return _connection!;
  }

  Future<List<Map<String, dynamic>>> fetchXYPositionsForSite(int siteId) async {
    var conn = await connection;

    List<List<dynamic>> results = await conn.query(
      "SELECT xyposition, casing, reference FROM boreholes WHERE site_id = @siteId",
      substitutionValues: {
        'siteId': siteId,
      },
    );

    List<Map<String, dynamic>> xyPositions = [];

    for (var row in results) {
      String xyString = row[0];
      List<String> xy = xyString.split(',');

      double latitude = double.parse(xy[1]); 
      double longitude = double.parse(xy[0]); 
      double casing = row[1]; 
      String reference = row[2]; 

      xyPositions.add({
        'latitude': latitude,
        'longitude': longitude,
        'casing': casing,
        'reference': reference,
      });
    }

    return xyPositions;
  }

  Future<List<Site>> loadPostgresSites() async {
    var conn = await connection;

    List<List<dynamic>> postgresSites = await conn.query('SELECT id, name, location FROM sites');

    List<Site> sites = postgresSites.map((row) {
      return Site(
        id: row[0], 
        name: row[1], 
        location: row[2],
        isPostgres: true,
      );
    }).toList();

    return sites;
  }

  Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      print('PostgreSQL connection closed.');
    }
  }
}
