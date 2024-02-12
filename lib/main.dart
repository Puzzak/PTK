import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(MyApp());

Future<String?> getSettings(key) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(key)) {
    return prefs.getString(key);
  } else {
    return "";
  }
}

Future setSettings(key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString(key, value);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(),
      darkTheme: ThemeData.dark(), // standard dark theme
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const TelemetryCard(),
    );
  }
}

class TelemetryCard extends StatefulWidget {
  const TelemetryCard({Key? key}) : super(key: key);

  @override
  _TelemetryCardState createState() => _TelemetryCardState();
}

class _TelemetryCardState extends State<TelemetryCard> {
  List<TemperatureData> temperatures = [];
  List<CPULoadData> load = [];
  List<MemData> mems = [];
  List<PingData> pings = [];
  List<NetStats> netIns = [];
  List<NetStats> netOuts = [];
  List<charts.Series<NetStats, DateTime>>? _netStat;
  List<charts.Series<TemperatureData, DateTime>>? _temperatureData;
  List<charts.Series<CPULoadData, DateTime>>? _cpuData;
  List<charts.Series<MemData, DateTime>>? _memData;
  List<charts.Series<PingData, DateTime>>? _ping;
  int netIn = 0;
  int netOut = 0;
  int ramSize = 0;
  double temp = 0;
  double cpuload = 0;
  int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
  List mem = [];
  String netLocation = "Loading...";
  String status = "Connecting...";
  Duration uptimeDuration = const Duration(milliseconds: 0);
  Duration ping = const Duration(milliseconds: 0);
  String formattedUptime = "";
  DateTime startDate = DateTime.fromMillisecondsSinceEpoch(1624582565000);
  double mempercent = 0;
  int memtotal = 0;
  int memfree = 0;
  int speed = 1000;
  bool receieving = false;

  Future getData(location) async {
    try {
      currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      final tdata = await http
          .get(Uri.parse(location))
          .timeout(const Duration(seconds: 10));
      if (tdata.statusCode == 200) {
        final jsonData = json.decode(tdata.body);
        status = "Connected";
        receieving = true;
        return jsonData;
      } else {
        status = "Connection Error";
        receieving = false;
        return "";
      }
    } catch (e) {
      status = "Network Timeout";
      receieving = false;
      return "";
    }
  }

  void updateChartData(location) async {
    final startingTimestamp = DateTime.now().millisecondsSinceEpoch.toInt();
    final data = await getData(location);
    if (data == "") {
      setState(() {});
    } else {
      currentTimestamp = DateTime.now().millisecondsSinceEpoch.toInt();
      netLocation = location;
      final uptimeMilliseconds =
          (currentTimestamp - data["uptime"] * 1000).toInt();
      ping = Duration(milliseconds: currentTimestamp - startingTimestamp);
      final uptimeDuration = Duration(milliseconds: uptimeMilliseconds);
      formattedUptime = formatDuration(uptimeDuration);
      startDate = DateTime.fromMillisecondsSinceEpoch(data["uptime"] * 1000);
      cpuload = data["util"].toDouble();
      load.add(CPULoadData(DateTime.now(), cpuload));

      if (load.length > 20) {
        load.removeAt(0);
      }
      setState(() {
        _cpuData = [
          charts.Series<CPULoadData, DateTime>(
            id: 'CPU Load',
            colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
            domainFn: (CPULoadData load, _) => load.timeStamp,
            measureFn: (CPULoadData load, _) => load.value,
            data: load,
          ),
        ];
      });

      pings.add(PingData(DateTime.now(), ping.inMilliseconds.toDouble()));
      if (pings.length > 20) {
        pings.removeAt(0);
      }
      setState(() {
        _ping = [
          charts.Series<PingData, DateTime>(
            id: 'Ping',
            colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
            domainFn: (PingData ping, _) => ping.timeStamp,
            measureFn: (PingData ping, _) => ping.value,
            data: pings,
          ),
        ];
      });

      netIn = data["netspd"]["in"];
      netIns.add(NetStats(DateTime.now(), netIn.toDouble()));
      if (netIns.length > 20) {
        netIns.removeAt(0);
      }
      netOut = data["netspd"]["out"];
      netOuts.add(NetStats(DateTime.now(), netOut.toDouble()));
      if (netOuts.length > 20) {
        netOuts.removeAt(0);
      }
      setState(() {
        _netStat = [
          charts.Series<NetStats, DateTime>(
            id: 'Outbound Network Speed',
            colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
            domainFn: (NetStats netOut, _) => netOut.timeStamp,
            measureFn: (NetStats netOut, _) => netOut.value,
            data: netOuts,
          ),
          charts.Series<NetStats, DateTime>(
            id: 'Inbound Network Speed',
            colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
            domainFn: (NetStats netIn, _) => netIn.timeStamp,
            measureFn: (NetStats netIn, _) => netIn.value,
            data: netIns,
          ),
        ];
      });

      temp = data["temp"];
      temperatures.add(TemperatureData(DateTime.now(), temp));

      if (temperatures.length > 20) {
        temperatures.removeAt(0);
      }

      setState(() {
        _temperatureData = [
          charts.Series<TemperatureData, DateTime>(
            id: 'Temperature',
            colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
            domainFn: (TemperatureData temperature, _) => temperature.timeStamp,
            measureFn: (TemperatureData temperature, _) => temperature.value,
            data: temperatures,
          ),
        ];
      });

      mempercent = 100 -
          (int.parse(data["memo"]["avail"]) /
                  int.parse(data["memo"]["total"])) *
              100;
      memtotal = int.parse(data["memo"]["total"]);

      ramSize = memtotal;
      memfree = int.parse(data["memo"]["avail"]);
      final memused = memtotal - memfree;
      mems.add(MemData(DateTime.now(), memused.toDouble()));

      if (mems.length > 20) {
        mems.removeAt(0);
      }

      setState(() {
        _memData = [
          charts.Series<MemData, DateTime>(
            id: 'Memory Usage',
            colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
            domainFn: (MemData mempercent, _) => mempercent.timeStamp,
            measureFn: (MemData mempercent, _) => mempercent.value,
            data: mems,
          ),
        ];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getSettings("location").then((value) async {
      if (value == "") {
        setSettings("location", "https://api.puzzak.page/AIO.php");
        updateChartData("https://api.puzzak.page/AIO.php");
      }
      updateChartData(value);
    });
    Timer.periodic(Duration(milliseconds: speed), (timer) {
      getSettings("location").then((value) {
        updateChartData(value);
      });
    });
  }

  String formatNetworkSpeed(int speed) {
    if (speed < 1024) {
      return '$speed B/s';
    } else if (speed < 10240) {
      double speedKb = speed / 1024;
      return '${speedKb.toStringAsFixed(2)} KB/s';
    } else if (speed < 1048576) {
      double speedKb = speed / 1024;
      return '${speedKb.toStringAsFixed(1)} KB/s';
    } else if (speed < 10485760) {
      double speedMb = speed / 1048576;
      return '${speedMb.toStringAsFixed(2)} MB/s';
    } else if (speed < 104857600) {
      double speedMb = speed / 1048576;
      return '${speedMb.toStringAsFixed(1)} MB/s';
    } else {
      double speedMb = speed / 1048576;
      return '${speedMb.toInt()} MB/s';
    }
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final days = duration.inDays;
    final hours = twoDigits(duration.inHours - (days * 24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return '${DateFormat.yMMMEd().format(startDate)} ${DateFormat.jms().format(startDate)}\n($days days, $hours hrs, $minutes min, $seconds sec ago)';
  }

  static final _defaultLightColorScheme =
      ColorScheme.fromSwatch(primarySwatch: Colors.teal);

  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(
      primarySwatch: Colors.teal, brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  enableDrag: true,
                  useSafeArea: true,
                  builder: (BuildContext context) {
                    return mainSettings();
                  },
                );
              },
              child: const Icon(Icons.settings_rounded),
            ),
            body: ListView(
              children: [
                !receieving
                    ? Card(
                        surfaceTintColor: Theme.of(context).colorScheme.error,
                        child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Disconnected!",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontFamily: 'Comfortaa',
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [
                                        FontFeature.proportionalFigures(),
                                      ]),
                                ),
                                Text(
                                  "Looks like we are not getting data from the server. It could mean that you have no network connection, remote is down or AIO script is not properly set up. Either way, check settings please.",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontFamily: 'Comfortaa',
                                      fontFeatures: [
                                        FontFeature.proportionalFigures(),
                                      ]),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FilledButton(
                                        onPressed: () {
                                          showModalBottomSheet<void>(
                                            context: context,
                                            isScrollControlled: true,
                                            enableDrag: true,
                                            useSafeArea: true,
                                            builder: (BuildContext context) {
                                              return mainSettings();
                                            },
                                          );
                                        },
                                        child: const Text(
                                          'Settings',
                                          style: const TextStyle(
                                              fontFamily: 'Comfortaa',
                                              fontWeight: FontWeight.bold,
                                              fontFeatures: [
                                                FontFeature
                                                    .proportionalFigures(),
                                              ]),
                                        )),
                                  ],
                                )
                              ],
                            )),
                      )
                    : Container(), //error card
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 5,
                            height: 32,
                          ),
                          const Icon(
                            Icons.restart_alt_rounded,
                            size: 24,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          const Text(
                            "Server booted on:",
                            style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          )
                        ],
                      ),
                      Padding(
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, bottom: 10),
                          child: Text(
                            formattedUptime,
                            style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Comfortaa',
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ))
                    ],
                  ),
                ), //uptime
                Card(
                  child: Stack(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ping == null
                          ? const Center(
                              child: LinearProgressIndicator(
                              color: Colors.teal,
                              backgroundColor: Colors.transparent,
                            ))
                          : Material(
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0))),
                              child: Container(
                                transform:
                                    Matrix4.diagonal3Values(1.115, 1.45, 1.0)
                                      ..translate(-20.0, -17),
                                height: 120,
                                child: charts.TimeSeriesChart(
                                  _ping!,
                                  animate: false,
                                  animationDuration:
                                      const Duration(milliseconds: 1000),
                                  defaultRenderer: charts.LineRendererConfig(
                                    includeArea: true,
                                    areaOpacity: 0.5,
                                    includePoints: true,
                                    radiusPx: 1.0,
                                    roundEndCaps: true,
                                    strokeWidthPx: 2.0,
                                  ),
                                  primaryMeasureAxis:
                                      const charts.NumericAxisSpec(
                                    renderSpec: charts.GridlineRendererSpec(
                                      labelStyle: charts.TextStyleSpec(
                                          fontSize: 0,
                                          color: charts
                                              .MaterialPalette.transparent),
                                      lineStyle: charts.LineStyleSpec(
                                        color:
                                            charts.MaterialPalette.transparent,
                                        thickness: 0,
                                      ),
                                    ),
                                    tickProviderSpec:
                                        charts.StaticNumericTickProviderSpec(
                                      <charts.TickSpec<num>>[
                                        charts.TickSpec<num>(0),
                                        charts.TickSpec<num>(1000),
                                      ],
                                    ),
                                  ),
                                  domainAxis: const charts.DateTimeAxisSpec(
                                      renderSpec: charts.GridlineRendererSpec(
                                        lineStyle: charts.LineStyleSpec(
                                          color: charts
                                              .MaterialPalette.transparent,
                                          thickness: 0,
                                        ),
                                      ),
                                      tickFormatterSpec:
                                          charts.AutoDateTimeTickFormatterSpec(
                                              day: charts.TimeFormatterSpec(
                                                  format: 'HH:mm',
                                                  transitionFormat: 'HH:mm'))),
                                ),
                              ),
                            ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 5,
                            height: 48,
                          ),
                          const Icon(Icons.timer_outlined),
                          const SizedBox(
                            width: 5,
                          ),
                          const Text(
                            'Ping: ',
                            style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontWeight: FontWeight.bold,
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ),
                          Text(
                            '${ping.inMilliseconds}ms',
                            style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ), //ping
                Card(
                  child: Stack(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _temperatureData == null
                          ? const Center(
                              child: LinearProgressIndicator(
                              color: Colors.teal,
                              backgroundColor: Colors.transparent,
                            ))
                          : Material(
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0))),
                              child: Container(
                                transform:
                                    Matrix4.diagonal3Values(1.115, 1.5, 1.0)
                                      ..translate(-20.0, -20.0),
                                height: 120,
                                child: charts.TimeSeriesChart(
                                  _temperatureData!,
                                  animate: false,
                                  animationDuration:
                                      const Duration(milliseconds: 1000),
                                  defaultRenderer: charts.LineRendererConfig(
                                    includeArea: true,
                                    areaOpacity: 0.5,
                                    includePoints: true,
                                    radiusPx: 1.0,
                                    roundEndCaps: true,
                                    strokeWidthPx: 2.0,
                                  ),
                                  primaryMeasureAxis:
                                      const charts.NumericAxisSpec(
                                    renderSpec: charts.GridlineRendererSpec(
                                      labelStyle: charts.TextStyleSpec(
                                          fontSize: 0,
                                          color: charts
                                              .MaterialPalette.transparent),
                                      lineStyle: charts.LineStyleSpec(
                                        color:
                                            charts.MaterialPalette.transparent,
                                        thickness: 0,
                                      ),
                                    ),
                                    tickProviderSpec:
                                        charts.StaticNumericTickProviderSpec(
                                      <charts.TickSpec<num>>[
                                        charts.TickSpec<num>(0),
                                        charts.TickSpec<num>(85),
                                      ],
                                    ),
                                  ),
                                  domainAxis: const charts.DateTimeAxisSpec(
                                      renderSpec: charts.GridlineRendererSpec(
                                        lineStyle: charts.LineStyleSpec(
                                          color: charts
                                              .MaterialPalette.transparent,
                                          thickness: 0,
                                        ),
                                      ),
                                      tickFormatterSpec:
                                          charts.AutoDateTimeTickFormatterSpec(
                                              day: charts.TimeFormatterSpec(
                                                  format: 'HH:mm',
                                                  transitionFormat: 'HH:mm'))),
                                ),
                              ),
                            ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 5,
                            height: 48,
                          ),
                          const Icon(Icons.thermostat_outlined),
                          const SizedBox(
                            width: 5,
                          ),
                          const Text(
                            'SoC Temp: ',
                            style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontWeight: FontWeight.bold,
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ),
                          Text(
                            '${temp.toStringAsFixed(2)}°C',
                            style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ), //temp
                Card(
                  child: Stack(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _cpuData == null
                          ? const Center(
                              child: LinearProgressIndicator(
                              color: Colors.teal,
                              backgroundColor: Colors.transparent,
                            ))
                          : Material(
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0))),
                              child: Container(
                                transform:
                                    Matrix4.diagonal3Values(1.115, 1.5, 1.0)
                                      ..translate(-20.0, -20.0),
                                height: 120,
                                child: charts.TimeSeriesChart(
                                  _cpuData!,
                                  animate: false,
                                  animationDuration:
                                      const Duration(milliseconds: 1000),
                                  defaultRenderer: charts.LineRendererConfig(
                                    includeArea: true,
                                    areaOpacity: 0.5,
                                    includePoints: true,
                                    radiusPx: 1.0,
                                    roundEndCaps: true,
                                    strokeWidthPx: 2.0,
                                  ),
                                  primaryMeasureAxis:
                                      const charts.NumericAxisSpec(
                                    renderSpec: charts.GridlineRendererSpec(
                                      labelStyle: charts.TextStyleSpec(
                                          fontSize: 0,
                                          color: charts
                                              .MaterialPalette.transparent),
                                      lineStyle: charts.LineStyleSpec(
                                        color:
                                            charts.MaterialPalette.transparent,
                                        thickness: 0,
                                      ),
                                    ),
                                    tickProviderSpec:
                                        charts.StaticNumericTickProviderSpec(
                                      <charts.TickSpec<num>>[
                                        charts.TickSpec<num>(0),
                                        charts.TickSpec<num>(100),
                                      ],
                                    ),
                                  ),
                                  domainAxis: const charts.DateTimeAxisSpec(
                                      renderSpec: charts.GridlineRendererSpec(
                                        lineStyle: charts.LineStyleSpec(
                                          color: charts
                                              .MaterialPalette.transparent,
                                          thickness: 0,
                                        ),
                                      ),
                                      tickFormatterSpec:
                                          charts.AutoDateTimeTickFormatterSpec(
                                              day: charts.TimeFormatterSpec(
                                                  format: 'HH:mm',
                                                  transitionFormat: 'HH:mm'))),
                                ),
                              ),
                            ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 5,
                            height: 48,
                          ),
                          const Icon(Icons.developer_board),
                          const SizedBox(
                            width: 5,
                            height: 48,
                          ),
                          const Text(
                            'SoC Load: ',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comfortaa',
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ),
                          Text(
                            '${cpuload.toStringAsFixed(2)}%',
                            style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Comfortaa',
                                fontFeatures: [
                                  FontFeature.proportionalFigures(),
                                ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ), //load
                Card(
                  child: Stack(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _memData == null
                          ? const Center(
                              child: LinearProgressIndicator(
                              color: Colors.teal,
                              backgroundColor: Colors.transparent,
                            ))
                          : Material(
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0))),
                              child: Container(
                                transform:
                                    Matrix4.diagonal3Values(1.115, 1.5, 1.0)
                                      ..translate(-20.0, -20.0),
                                height: 120,
                                child: charts.TimeSeriesChart(
                                  _memData!,
                                  animate: false,
                                  animationDuration:
                                      const Duration(milliseconds: 1000),
                                  defaultRenderer: charts.LineRendererConfig(
                                    includeArea: true,
                                    areaOpacity: 0.5,
                                    includePoints: true,
                                    radiusPx: 1.0,
                                    roundEndCaps: true,
                                    strokeWidthPx: 2.0,
                                  ),
                                  primaryMeasureAxis: charts.NumericAxisSpec(
                                    renderSpec:
                                        const charts.GridlineRendererSpec(
                                      labelStyle: charts.TextStyleSpec(
                                          fontSize: 0,
                                          color: charts
                                              .MaterialPalette.transparent),
                                      lineStyle: charts.LineStyleSpec(
                                        color:
                                            charts.MaterialPalette.transparent,
                                        thickness: 0,
                                      ),
                                    ),
                                    tickProviderSpec:
                                        charts.StaticNumericTickProviderSpec(
                                      <charts.TickSpec<num>>[
                                        const charts.TickSpec<num>(0),
                                        charts.TickSpec<num>(ramSize),
                                      ],
                                    ),
                                  ),
                                  domainAxis: const charts.DateTimeAxisSpec(
                                      renderSpec: charts.GridlineRendererSpec(
                                        lineStyle: charts.LineStyleSpec(
                                          color: charts
                                              .MaterialPalette.transparent,
                                          thickness: 0,
                                        ),
                                      ),
                                      tickFormatterSpec:
                                          charts.AutoDateTimeTickFormatterSpec(
                                              day: charts.TimeFormatterSpec(
                                                  format: 'HH:mm',
                                                  transitionFormat: 'HH:mm'))),
                                ),
                              ),
                            ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 12,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 18,
                              ),
                              const Icon(
                                Icons.memory,
                                size: 24,
                              ),
                              const SizedBox(
                                width: 5,
                                height: 18,
                              ),
                              const Text(
                                'Used RAM: ',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Comfortaa',
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.proportionalFigures(),
                                    ]),
                              ),
                              Text(
                                '${((memtotal - memfree) / 1000000).toStringAsFixed(2)}/${(memtotal / 1000000).toStringAsFixed(2)}GB (${mempercent.toStringAsFixed(2)}%)',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Comfortaa',
                                    fontFeatures: [
                                      FontFeature.proportionalFigures(),
                                    ]),
                              )
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ), //ram
                Card(
                  child: Stack(
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _netStat == null
                          ? const Center(
                              child: LinearProgressIndicator(
                              color: Colors.teal,
                              backgroundColor: Colors.transparent,
                            ))
                          : Material(
                              color: Colors.transparent,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10.0))),
                              child: Container(
                                transform:
                                    Matrix4.diagonal3Values(1.115, 1.5, 1.0)
                                      ..translate(-20.0, -20.0),
                                height: 120,
                                child: charts.TimeSeriesChart(
                                  _netStat!,
                                  animate: false,
                                  animationDuration:
                                      const Duration(milliseconds: 1000),
                                  defaultRenderer: charts.LineRendererConfig(
                                    includeArea: true,
                                    areaOpacity: 0.5,
                                    includePoints: true,
                                    radiusPx: 1.0,
                                    roundEndCaps: true,
                                    strokeWidthPx: 2.0,
                                  ),
                                  primaryMeasureAxis: const charts
                                      .NumericAxisSpec(
                                      renderSpec: charts.GridlineRendererSpec(
                                        labelStyle: charts.TextStyleSpec(
                                            fontSize: 0,
                                            color: charts
                                                .MaterialPalette.transparent),
                                        lineStyle: charts.LineStyleSpec(
                                          color: charts
                                              .MaterialPalette.transparent,
                                          thickness: 0,
                                        ),
                                      ),
                                      tickProviderSpec:
                                          charts.BasicNumericTickProviderSpec(
                                              zeroBound: false)),
                                  domainAxis: const charts.DateTimeAxisSpec(
                                      renderSpec: charts.GridlineRendererSpec(
                                        lineStyle: charts.LineStyleSpec(
                                          color: charts
                                              .MaterialPalette.transparent,
                                          thickness: 0,
                                        ),
                                      ),
                                      tickFormatterSpec:
                                          charts.AutoDateTimeTickFormatterSpec(
                                              day: charts.TimeFormatterSpec(
                                                  format: 'HH:mm',
                                                  transitionFormat: 'HH:mm'))),
                                ),
                              ),
                            ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 5,
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 18,
                              ),
                              const Icon(
                                Icons.arrow_drop_up_outlined,
                                size: 24,
                                color: Colors.red,
                              ),
                              const SizedBox(
                                width: 5,
                                height: 18,
                              ),
                              const Text(
                                'Outbound: ',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Comfortaa',
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.proportionalFigures(),
                                    ]),
                              ),
                              Text(
                                formatNetworkSpeed(netOut),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Comfortaa',
                                    fontFeatures: [
                                      FontFeature.proportionalFigures(),
                                    ]),
                              )
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                                height: 18,
                              ),
                              const Icon(
                                Icons.arrow_drop_down_outlined,
                                size: 24,
                                color: Colors.teal,
                              ),
                              const SizedBox(
                                width: 5,
                                height: 18,
                              ),
                              const Text(
                                'Inbound: ',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Comfortaa',
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.proportionalFigures(),
                                    ]),
                              ),
                              Text(
                                formatNetworkSpeed(netIn),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Comfortaa',
                                    fontFeatures: [
                                      FontFeature.proportionalFigures(),
                                    ]),
                              )
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ), //net
              ],
            )),
      );
    });
  }
}

class mainSettings extends StatelessWidget {
  TextEditingController locController = TextEditingController();
  static final _defaultLightColorScheme =
      ColorScheme.fromSwatch(primarySwatch: Colors.teal);

  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(
      primarySwatch: Colors.teal, brightness: Brightness.dark);
  late final getLoc = getSettings("location");
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
          theme: ThemeData(
            colorScheme: lightColorScheme ?? _defaultLightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme ?? _defaultDarkColorScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton(
                    child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 16,),
                  Text(
                    'Settings',
                    style: TextStyle(
                        fontSize: 22,
                        height: 5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Comfortaa',
                        fontFeatures: [
                          FontFeature.proportionalFigures(),
                        ]),
                  ),
                ],
              ),
            ),
            body: ListView(
              children: [
                FutureBuilder(
                  future: getLoc,
                  builder: (BuildContext context, AsyncSnapshot data) {
                    if (data.hasData) {
                      if(locController.text != data.data) {
                        locController = TextEditingController(text: data.data);
                      }
                      return Padding(
                          padding: const EdgeInsets.only(
                              left: 5, right: 5, top: 10, bottom: 5),
                          child: TextField(
                            maxLines: 1,
                            maxLength: 256,
                            controller: locController,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1,
                              fontFamily: 'Comfortaa',
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(),
                              labelText: 'URL',
                            ),
                            onChanged: (value) async {
                              setSettings("location", value);
                            },
                            onTap: null,
                          ));
                    } else if (data.hasError) {
                      return Center(
                        child: Text('Error: ${data.error}'),
                      );
                    } else {
                      return Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              LinearProgressIndicator(
                                color: Colors.teal,
                                backgroundColor: Colors.transparent,
                              ),
                            ]),
                      );
                    }
                  },
                ),
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 15.0, top: 15, right: 15),
                        child: Text(
                          'About the app',
                          style: TextStyle(
                              fontSize: 22,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.bold,
                              fontFeatures: [
                                FontFeature.proportionalFigures(),
                              ]),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 15.0, top: 5, right: 15),
                        child: Text(
                          'This app is made for monitoring performance of the remote server. Please, reffer to the instructions you can find on GitHub. By default, app points to the monitor script on the developer\'s website. We do not collect any data and do not track anything.',
                          style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Comfortaa',
                              fontFeatures: [
                                FontFeature.proportionalFigures(),
                              ]),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                            left: 15.0, top: 5, right: 15, bottom: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                                child: Text(
                                  'GitHub',
                                  style: TextStyle(
                                      fontFamily: 'Comfortaa',
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [
                                        FontFeature.proportionalFigures(),
                                      ]),
                                ),
                                style: ButtonStyle(
                                    elevation: MaterialStateProperty.all(5)
                                ),
                                onPressed: () async {
                                  launchUrl(
                                      Uri.parse(
                                          "https://github.com/Puzzak/AIO-Monitor/blob/main/AIO.php"),
                                      mode: LaunchMode.externalApplication);
                                }
                            ),
                            ElevatedButton(
                                child: Text(
                                  'Default URL',
                                  style: TextStyle(
                                      fontFamily: 'Comfortaa',
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: [
                                        FontFeature.proportionalFigures(),
                                      ]),
                                ),
                                style: ButtonStyle(
                                    elevation: MaterialStateProperty.all(5)
                                ),
                                onPressed: () {
                                  locController.text = "https://api.puzzak.page/AIO.php";
                                  setSettings("location", "https://api.puzzak.page/AIO.php");
                                }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), //Setup
                Card(
                  child:Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                        EdgeInsets.only(left: 15.0, top: 15, right: 15),
                        child: Text(
                          'Developer contact',
                          style: TextStyle(
                              fontSize: 22,
                              fontFamily: 'Comfortaa',
                              fontWeight: FontWeight.bold,
                              fontFeatures: [
                                FontFeature.proportionalFigures(),
                              ]),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: FutureBuilder(
                            future: rootBundle.loadString('assets/data/authors.json'),
                            builder: (BuildContext context, AsyncSnapshot authorsRaw) {
                              if (authorsRaw.hasData) {
                                Map authors = jsonDecode(authorsRaw.data);
                                return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Wrap(
                                      spacing: 5.0,
                                      runSpacing: 0.0,
                                      alignment: WrapAlignment.start,
                                      runAlignment: WrapAlignment.start,
                                      verticalDirection: VerticalDirection.up,
                                      children: authors["Authors"][0]["Links"]
                                          .map((option) {
                                        return GestureDetector(
                                          onTap: () {
                                            launchUrl(Uri.parse(option["Link"]), mode: LaunchMode.externalApplication);
                                          },
                                          child: Chip(
                                            label: Text(
                                              option["Title"],
                                              style: const TextStyle(
                                                fontFamily: 'Comfortaa',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            elevation: 5.0,
                                          ),
                                        );
                                      })
                                          .toList()
                                          .cast<Widget>(),
                                    )
                                );
                              }
                              return Text("Loading");
                            })
                    )
                    ],
                  ),
                ), //Notes
              ],
            ),
          ));
    });
  }
}

class PingData {
  final DateTime timeStamp;
  final double value;

  PingData(this.timeStamp, this.value);
}

class NetStats {
  final DateTime timeStamp;
  final double value;

  NetStats(this.timeStamp, this.value);
}

class TemperatureData {
  final DateTime timeStamp;
  final double value;

  TemperatureData(this.timeStamp, this.value);
}

class CPULoadData {
  final DateTime timeStamp;
  final double value;

  CPULoadData(this.timeStamp, this.value);
}

class MemData {
  final DateTime timeStamp;
  final double value;

  MemData(this.timeStamp, this.value);
}
