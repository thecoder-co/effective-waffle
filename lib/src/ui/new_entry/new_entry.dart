import 'dart:math';
import 'package:flutter/material.dart';
import 'package:medicine_reminder/src/common/convert_time.dart';
import 'package:medicine_reminder/src/global_bloc.dart';
import 'package:medicine_reminder/src/models/errors.dart';
import 'package:medicine_reminder/src/models/medicine.dart';
import 'package:medicine_reminder/src/models/medicine_type.dart';
import 'package:medicine_reminder/src/ui/homepage/homepage.dart';
import 'package:medicine_reminder/src/ui/new_entry/new_entry_bloc.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart' as t;

import 'package:medicine_reminder/src/ui/success_screen/success_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NewEntry extends StatefulWidget {
  const NewEntry({super.key});

  @override
  _NewEntryState createState() => _NewEntryState();
}

class _NewEntryState extends State<NewEntry> {
  late TextEditingController nameController;
  late TextEditingController dosageController;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late NewEntryBloc _newEntryBloc;

  late GlobalKey<ScaffoldState> _scaffoldKey;

  @override
  void dispose() {
    super.dispose();
    nameController.dispose();
    dosageController.dispose();
    _newEntryBloc.dispose();
  }

  @override
  void initState() {
    super.initState();
    _newEntryBloc = NewEntryBloc();
    nameController = TextEditingController();
    dosageController = TextEditingController();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _scaffoldKey = GlobalKey<ScaffoldState>();
    initializeNotifications();
    initializeErrorListen();
  }

  @override
  Widget build(BuildContext context) {
    final GlobalBloc globalBloc = Provider.of<GlobalBloc>(context);

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Color(0xFF3EB16F),
        ),
        centerTitle: true,
        title: const Text(
          "Add New Mediminder",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        elevation: 0.0,
      ),
      body: Container(
        child: Provider<NewEntryBloc>.value(
          value: _newEntryBloc,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 25,
            ),
            children: <Widget>[
              const PanelTitle(
                title: "Medicine Name",
                isRequired: true,
              ),
              TextFormField(
                maxLength: 12,
                style: const TextStyle(
                  fontSize: 16,
                ),
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                ),
              ),
              const PanelTitle(
                title: "Dosage in mg",
                isRequired: false,
              ),
              TextFormField(
                controller: dosageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 16,
                ),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 15,
              ),

              const PanelTitle(
                title: "Medicine Type",
                isRequired: false,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: StreamBuilder<MedicineType>(
                  stream: _newEntryBloc.selectedMedicineType,
                  builder: (context, snapshot) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        MedicineTypeColumn(
                            type: MedicineType.Bottle,
                            name: "Bottle",
                            iconValue: 0xe900,
                            isSelected: snapshot.data == MedicineType.Bottle
                                ? true
                                : false),
                        MedicineTypeColumn(
                            type: MedicineType.Pill,
                            name: "Pill",
                            iconValue: 0xe901,
                            isSelected: snapshot.data == MedicineType.Pill
                                ? true
                                : false),
                        MedicineTypeColumn(
                            type: MedicineType.Syringe,
                            name: "Syringe",
                            iconValue: 0xe902,
                            isSelected: snapshot.data == MedicineType.Syringe
                                ? true
                                : false),
                        MedicineTypeColumn(
                            type: MedicineType.Tablet,
                            name: "Tablet",
                            iconValue: 0xe903,
                            isSelected: snapshot.data == MedicineType.Tablet
                                ? true
                                : false),
                      ],
                    );
                  },
                ),
              ),
              const PanelTitle(
                title: "Interval Selection",
                isRequired: true,
              ),
              //ScheduleCheckBoxes(),
              const IntervalSelection(),
              const PanelTitle(
                title: "Starting Time",
                isRequired: true,
              ),
              const SelectTime(),
              const SizedBox(
                height: 35,
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.height * 0.08,
                  right: MediaQuery.of(context).size.height * 0.08,
                ),
                child: SizedBox(
                  width: 220,
                  height: 70,
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          const Color(0xFF3EB16F)),
                      shape: MaterialStateProperty.all<StadiumBorder>(
                        const StadiumBorder(),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "Confirm",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onPressed: () {
                      String? medicineName;
                      int? dosage;
                      //--------------------Error Checking------------------------
                      //Had to do error checking in UI
                      //Due to unoptimized BLoC value-grabbing architecture
                      if (nameController.text == "") {
                        _newEntryBloc.submitError(EntryError.NameNull);
                        return;
                      }
                      if (nameController.text != "") {
                        medicineName = nameController.text;
                      }
                      if (dosageController.text == "") {
                        dosage = 0;
                      }
                      if (dosageController.text != "") {
                        dosage = int.parse(dosageController.text);
                      }
                      for (var medicine in globalBloc.medicineList$.value) {
                        if (medicineName == medicine.medicineName) {
                          _newEntryBloc.submitError(EntryError.NameDuplicate);
                          return;
                        }
                      }
                      if (_newEntryBloc.selectedInterval$.value == 0) {
                        _newEntryBloc.submitError(EntryError.Interval);
                        return;
                      }
                      if (_newEntryBloc.selectedTimeOfDay$.value == "None") {
                        _newEntryBloc.submitError(EntryError.StartTime);
                        return;
                      }
                      //---------------------------------------------------------
                      String medicineType = _newEntryBloc
                          .selectedMedicineType.value
                          .toString()
                          .substring(13);
                      int interval = _newEntryBloc.selectedInterval$.value;
                      String startTime = _newEntryBloc.selectedTimeOfDay$.value;

                      List<int> intIDs =
                          makeIDs(24 / _newEntryBloc.selectedInterval$.value);
                      List<String> notificationIDs = intIDs
                          .map((i) => i.toString())
                          .toList(); //for Shared preference

                      Medicine newEntryMedicine = Medicine(
                        notificationIDs: notificationIDs,
                        medicineName: medicineName!,
                        dosage: dosage!,
                        medicineType: medicineType,
                        interval: interval,
                        startTime: startTime,
                      );

                      globalBloc.updateMedicineList(newEntryMedicine);
                      scheduleNotification(newEntryMedicine);

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (BuildContext context) {
                            return SuccessScreen();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void initializeErrorListen() {
    _newEntryBloc.errorState$.listen(
      (EntryError error) {
        switch (error) {
          case EntryError.NameNull:
            displayError("Please enter the medicine's name");
            break;
          case EntryError.NameDuplicate:
            displayError("Medicine name already exists");
            break;
          case EntryError.Dosage:
            displayError("Please enter the dosage required");
            break;
          case EntryError.Interval:
            displayError("Please select the reminder's interval");
            break;
          case EntryError.StartTime:
            displayError("Please select the reminder's starting time");
            break;
          default:
        }
      },
    );
  }

  void displayError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(error),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  List<int> makeIDs(double n) {
    var rng = Random();
    List<int> ids = [];
    for (int i = 0; i < n; i++) {
      ids.add(rng.nextInt(1000000000));
    }
    return ids;
  }

  initializeNotifications() async {
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = const DarwinInitializationSettings();
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings, /* onSelectNotification: onSelectNotification */
    );
  }

  Future onSelectNotification(String payload) async {
    debugPrint('notification payload: $payload');
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  Future<void> scheduleNotification(Medicine medicine) async {
    var hour = int.parse(medicine.startTime[0] + medicine.startTime[1]);
    var ogValue = hour;
    var minute = int.parse(medicine.startTime[2] + medicine.startTime[3]);

    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'repeatDailyAtTime channel id',
      'repeatDailyAtTime channel name',
      channelDescription: 'repeatDailyAtTime description',
      importance: Importance.max,
      ledColor: Color(0xFF3EB16F),
      ledOffMs: 1000,
      ledOnMs: 1000,
      enableLights: true,
    );
    var iOSPlatformChannelSpecifics = const DarwinNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    for (int i = 0; i < (24 / medicine.interval).floor(); i++) {
      if ((hour + (medicine.interval * i) > 23)) {
        hour = hour + (medicine.interval * i) - 24;
      } else {
        hour = hour + (medicine.interval * i);
      }
      final time = DateTime.now();
      final timeZone = TimeZone();

      // The device's timezone.
      String timeZoneName = await timeZone.getTimeZoneName();

      // Find the 'current location'
      final location = await timeZone.getLocation(timeZoneName);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        int.parse(medicine.notificationIDs[i]),
        'Mediminder: ${medicine.medicineName}',
        medicine.medicineType.toString() != MedicineType.None.toString()
            ? 'It is time to take your ${medicine.medicineType.toLowerCase()}, according to schedule'
            : 'It is time to take your medicine, according to schedule',
        t.TZDateTime.from(
            DateTime(time.year, time.month, time.day, hour, minute, 0),
            location),
        platformChannelSpecifics,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
      );
      hour = ogValue;
    }
    //await flutterLocalNotificationsPlugin.cancelAll();
  }
}

class IntervalSelection extends StatefulWidget {
  const IntervalSelection({super.key});

  @override
  _IntervalSelectionState createState() => _IntervalSelectionState();
}

class _IntervalSelectionState extends State<IntervalSelection> {
  final _intervals = [
    6,
    8,
    12,
    24,
  ];
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final NewEntryBloc newEntryBloc = Provider.of<NewEntryBloc>(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "Remind me every  ",
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            DropdownButton<int>(
              iconEnabledColor: const Color(0xFF3EB16F),
              hint: _selected == 0
                  ? const Text(
                      "Select an Interval",
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                          fontWeight: FontWeight.w400),
                    )
                  : null,
              elevation: 4,
              value: _selected == 0 ? null : _selected,
              items: _intervals.map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    value.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (newVal) {
                setState(() {
                  _selected = newVal!;
                  newEntryBloc.updateInterval(newVal);
                });
              },
            ),
            Text(
              _selected == 1 ? " hour" : " hours",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectTime extends StatefulWidget {
  const SelectTime({super.key});

  @override
  _SelectTimeState createState() => _SelectTimeState();
}

class _SelectTimeState extends State<SelectTime> {
  TimeOfDay _time = const TimeOfDay(hour: 0, minute: 00);
  bool _clicked = false;

  Future<TimeOfDay?> _selectTime(BuildContext context) async {
    final NewEntryBloc newEntryBloc =
        Provider.of<NewEntryBloc>(context, listen: false);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null && picked != _time) {
      setState(() {
        _time = picked;
        _clicked = true;
        newEntryBloc.updateTime(convertTime(_time.hour.toString()) +
            convertTime(_time.minute.toString()));
      });
    }
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0, bottom: 4),
        child: TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF3EB16F),
            shape: const StadiumBorder(),
          ),
          onPressed: () {
            _selectTime(context);
          },
          child: Center(
            child: Text(
              _clicked == false
                  ? "Pick Time"
                  : "${convertTime(_time.hour.toString())}:${convertTime(_time.minute.toString())}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MedicineTypeColumn extends StatelessWidget {
  final MedicineType type;
  final String name;
  final int iconValue;
  final bool isSelected;

  const MedicineTypeColumn(
      {Key? key,
      required this.type,
      required this.name,
      required this.iconValue,
      required this.isSelected})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final NewEntryBloc newEntryBloc = Provider.of<NewEntryBloc>(context);
    return GestureDetector(
      onTap: () {
        newEntryBloc.updateSelectedMedicine(type);
      },
      child: Column(
        children: <Widget>[
          Container(
            width: 85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected ? const Color(0xFF3EB16F) : Colors.white,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 14.0),
                child: Icon(
                  IconData(iconValue, fontFamily: "Ic"),
                  size: 75,
                  color: isSelected ? Colors.white : const Color(0xFF3EB16F),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: 80,
              height: 30,
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF3EB16F) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? Colors.white : const Color(0xFF3EB16F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class PanelTitle extends StatelessWidget {
  final String title;
  final bool isRequired;
  const PanelTitle({
    Key? key,
    required this.title,
    required this.isRequired,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text.rich(
        TextSpan(children: <TextSpan>[
          TextSpan(
            text: title,
            style: const TextStyle(
                fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: isRequired ? " *" : "",
            style: const TextStyle(fontSize: 14, color: Color(0xFF3EB16F)),
          ),
        ]),
      ),
    );
  }
}

class TimeZone {
  factory TimeZone() => _this ?? TimeZone._();

  TimeZone._() {
    initializeTimeZones();
  }
  static TimeZone? _this;

  Future<String> getTimeZoneName() async => 'UTC';

  Future<t.Location> getLocation([String? timeZoneName]) async {
    if (timeZoneName == null || timeZoneName.isEmpty) {
      timeZoneName = await getTimeZoneName();
    }
    return t.getLocation(timeZoneName);
  }
}
