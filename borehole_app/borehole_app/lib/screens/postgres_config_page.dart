import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostgresConfigPage extends StatefulWidget {
  @override
  _PostgresConfigPageState createState() => _PostgresConfigPageState();
}

class _PostgresConfigPageState extends State<PostgresConfigPage> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _databaseController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isConfigSaved = false;
  bool _tablesExist = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString('postgres_host') ?? '';
    _portController.text = prefs.getString('postgres_port') ?? '';
    _databaseController.text = prefs.getString('postgres_db') ?? '';
    _usernameController.text = prefs.getString('postgres_user') ?? '';
    _passwordController.text = prefs.getString('postgres_pass') ?? '';

    setState(() {
      _isConfigSaved = _hostController.text.isNotEmpty &&
          _portController.text.isNotEmpty &&
          _databaseController.text.isNotEmpty &&
          _usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    });

    if (_isConfigSaved) {
      await _checkIfTablesExist();
    }
  }

  Future<void> _saveConfig() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('postgres_host', _hostController.text);
    await prefs.setString('postgres_port', _portController.text);
    await prefs.setString('postgres_db', _databaseController.text);
    await prefs.setString('postgres_user', _usernameController.text);
    await prefs.setString('postgres_pass', _passwordController.text);

    setState(() {
      _isConfigSaved = true;
      _status = 'Configuration saved';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Configuration saved')),
    );

    await _checkIfTablesExist();
  }

  Future<void> _checkIfTablesExist() async {
    try {
      PostgreSQLConnection connection = PostgreSQLConnection(
        _hostController.text,
        int.tryParse(_portController.text) ?? 5432,
        _databaseController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await connection.open();

      String checkTablesQuery = '''
        SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'sites') AS sites_exists,
               EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'boreholes') AS boreholes_exists,
               EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'water_data') AS water_data_exists;
      ''';

      List<List<dynamic>> result = await connection.query(checkTablesQuery);
      bool sitesExists = result[0][0] == true;
      bool boreholesExists = result[0][1] == true;
      bool waterDataExists = result[0][2] == true;

      setState(() {
        _tablesExist = sitesExists && boreholesExists && waterDataExists;
        _status = _tablesExist
            ? 'All necessary tables already exist.'
            : 'Tables need to be created.';
      });

      await connection.close();
    } catch (e) {
      setState(() {
        _status = 'Failed to check tables: $e';
      });
    }
  }

  Future<void> _createTables() async {
    if (!_isConfigSaved) {
      setState(() {
        _status = 'PostgreSQL configuration is not saved.';
      });
      return;
    }

    try {
      PostgreSQLConnection connection = PostgreSQLConnection(
        _hostController.text,
        int.tryParse(_portController.text) ?? 5432,
        _databaseController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      await connection.open();

      String createSitesTable = '''
        CREATE TABLE IF NOT EXISTS sites (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          location VARCHAR(255)
        );
      ''';
      await connection.query(createSitesTable);

      String createBoreholesTable = '''
        CREATE TABLE IF NOT EXISTS boreholes (
          id SERIAL PRIMARY KEY,
          reference VARCHAR(255) NOT NULL,
          xyPosition VARCHAR(255),
          casing DOUBLE PRECISION,
          type VARCHAR(255),
          site_id INT REFERENCES sites(id)
        );
      ''';
      await connection.query(createBoreholesTable);

      String createWaterDataTable = '''
        CREATE TABLE IF NOT EXISTS water_data (
          id SERIAL PRIMARY KEY,
          datetime TIMESTAMP NOT NULL,
          water_level DOUBLE PRECISION,
          borehole VARCHAR(255) NOT NULL,
          site VARCHAR(255) NOT NULL
        );
      ''';
      await connection.query(createWaterDataTable);

      await connection.close();

      setState(() {
        _status = 'Tables created successfully!';
        _tablesExist = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to create tables: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Postgres Configuration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _hostController,
              decoration: InputDecoration(labelText: 'Host'),
            ),
            TextField(
              controller: _portController,
              decoration: InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _databaseController,
              decoration: InputDecoration(labelText: 'Database Name'),
            ),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveConfig,
              child: Text('Save Configuration'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isConfigSaved && !_tablesExist ? _createTables : null,
              child: Text('Set Up Tables in PostgreSQL'),
            ),
            SizedBox(height: 20),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
