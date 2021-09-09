// ignore: todo
// TODO: show unauth domain in snack bar as error message - handle exception

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timer/from_to_widget.dart';
import 'config.dart' as cfg;
import 'input_widgets.dart';
import 'model.dart';
import 'parse.dart';
import 'signin.dart';
import 'weektile.dart';

void main() async {
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        FutureProvider<TimeUser?>(
          create: (_) {
            return TimeUser.signinFuture();
          },
          initialData: null,
          lazy: false,
          catchError: (context, error) {
            print('Login error $error');
            return null;
          },
        ),
        ChangeNotifierProxyProvider<TimeUser?, TimeEntryList>(
          create: (_) {
            return TimeEntryList(null);
          },
          update: (_, user, timeEntry) {
            assert(timeEntry != null);

            if (user == null) {
              return timeEntry!;
            }

            timeEntry!.setUser(user);

            timeEntry.loadAccounts();
            timeEntry.loadAll(cfg.defaultAccountName);
            return timeEntry;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Nordheim Digital v${cfg.version}',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MyHomePage(title: 'Timelister for deg og meg'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// Helper class for the UI, keeping temporary values during input
//
class TimeEntryEdit {
  DateTime? date;
  String? accountName;
  DateTime? from;
  Duration? duration;
  String? comment;

  DateTime? get to => (duration != null) ? from?.add(duration!) : null;

  TimeEntryEdit(this.date, this.accountName, this.from, this.duration, {this.comment});

  TimeEntry toEntry() {
    return TimeEntry(date!, accountName!, from!, duration!, comment: comment);
  }
}

class _MyHomePageState extends State<MyHomePage> {
  var _formkey = GlobalKey<FormState>();
  var _scaffoldKey = GlobalKey<ScaffoldState>();

  late TimeEntryEdit _timeEntry;

  @override
  void initState() {
    super.initState();

    // Assign defaults to UI model
    final now = DateTime.now();
    _timeEntry = TimeEntryEdit(
      now,
      cfg.defaultAccountName,
      DateTime(now.year, now.month, now.day, now.hour),
      Duration(hours: 1),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Save form. Validate and Save all form fields, they are saved in _timeEntry object.
    // Then save to firestore.
    //
    void onSaveForm() async {
      if (_formkey.currentState!.validate()) {
        _formkey.currentState!.save(); // The Model is updated in _timeEntry.

        final model = Provider.of<TimeEntryList>(context, listen: false);

        model.addTimeEntry(_timeEntry.toEntry());

        if (_timeEntry.accountName != model.account) {
          // If we are changing the account or creating a new one, add new account, and load new list.
          model.addAccount(_timeEntry.accountName!);
          model.loadAll(_timeEntry.accountName!);
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hours added!')));
      }
    }

    // Helper called when Enter pressed in a focused field.
    //
    bool handleKeyPress(FocusNode node, RawKeyEvent event) {
      print(event.logicalKey);
      var tu = Provider.of<TimeUser?>(context, listen: false);
      if (tu != null && tu.isLoggedIn && event.character == LogicalKeyboardKey.enter.keyLabel) {
        onSaveForm();
        return true;
      }
      return false;
    }

    void onSignin() async {
      var tuModel = Provider.of<TimeUser?>(context, listen: false);
      assert(tuModel != null);

      await tuModel!.signin();
      if (!tuModel.isLoggedIn) return;

      var teModel = Provider.of<TimeEntryList>(context, listen: false);
      teModel.setUser(tuModel);
      teModel.loadAccounts();
      teModel.loadAll(cfg.defaultAccountName);
    }

    void onSignOut() async {
      var tu = Provider.of<TimeUser?>(context, listen: false);
      assert(tu != null);

      await tu!.signout();

      var model = Provider.of<TimeEntryList>(context, listen: false);
      model.clear();
      model.clearUser();
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Consumer<TimeUser?>(builder: (context, user, child) {
          return Text((user != null && user.isLoggedIn) ? user.email! : '<..no user..>');
        }),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Consumer<TimeUser?>(builder: (context, user, child) {
              return ElevatedButton(
                onPressed: user != null && user.isLoggedIn ? onSignOut : onSignin,
                child: Text(user != null && user.isLoggedIn ? 'Sign outx' : 'Sign in'),
              );
            }),
          ),
          SizedBox(width: 8),
          Checkbox(value: kDebugMode, onChanged: null),
          Center(child: Text('Debug')),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: OverflowBox(
          maxWidth: cfg.maxWidth,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Card(
                  elevation: 4,
                  child: Form(
                    key: _formkey,
                    onChanged: () {
                      print('from changed');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FocusScope(
                        onKey: handleKeyPress,
                        onFocusChange: _onFocusChange,
                        child: Container(
                          width: double.infinity,
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: _buildDateField(_timeEntry.date),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: _buildTypeAheadField(_timeEntry.accountName, Provider.of<TimeEntryList>(context)),
                                    ),
                                  ),
                                ],
                              ),
                              Container(width: double.infinity, padding: EdgeInsets.only(right: 8), child: buildQuickInputField()),
                              SizedBox(height: 16),
                              IntrinsicHeight(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FromFormField(
                                      initialValue: TimeDuration(_timeEntry.from, _timeEntry.duration),
                                      onSaved: (v) {
                                        _timeEntry.from = v?.from;
                                        _timeEntry.duration = v?.duration;
                                      },
                                    ),
                                    Spacer(),
                                    Container(
                                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      height: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => showWeeklySummary(context, cfg.history),
                                        icon: Icon(Icons.assignment_outlined),
                                        label: Text('Summary'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    elevation: 4,
                    child: GestureDetector(
                      excludeFromSemantics: true,
                      behavior: HitTestBehavior.opaque,
                      onSecondaryTap: () => print('tapped'),
                      child: Consumer<TimeEntryList>(builder: (context, model, child) {
                        return ListView.separated(
                          padding: const EdgeInsets.all(0),
                          itemBuilder: (context, index) => WeekTile(model: model.entries[index]),
                          itemCount: model.entries.length,
                          separatorBuilder: (_, __) => const Divider(indent: 10, endIndent: 10, height: 2),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Field builder helper.
  //
  Widget _buildDateField(DateTime? date) {
    void onSaved(String? v) {
      _timeEntry.date = parseDate(v);
    }

    String? validator(String? v) => isDate(v) ? null : "Not in dd.mm format";

    return TextWidget(
      initialValue: (date != null) ? dateFormat.format(date) : '',
      hintText: '12.04',
      iconData: Icons.calendar_today,
      helperText: 'dd[.MM]',
      labelText: 'Date',
      onSaved: onSaved,
      validator: validator,
      autofocus: true,
    );
  }

  // Form focus change
  //
  void _onFocusChange(bool value) {
    print('Focus change');
  }

  // Field builder helper.
  //
  TypeAheadWidget _buildTypeAheadField(String? initialAccount, TimeEntryList timeEntryList) {
    void onSelected(String account) {
      _timeEntry.accountName = account;
      timeEntryList.loadAll(account);
    }

    void onSubmitted(String account) {
      _timeEntry.accountName = account;
    }

    return TypeAheadWidget(initialAccount: initialAccount, timeEntryList: timeEntryList, wbs: timeEntryList.wbs, onSubmitted: onSubmitted, onSelected: onSelected);
  }

  // Field builder helper.
  //
  Widget buildQuickInputField() {
    return QuickEntry(
      iconData: Icons.format_quote,
      helperText: '[from] [duration] [message]',
      labelText: 'Quick Input',
      onChanged: (s) {},
      onSaved: (s) {
        final quickEntryModel = parseQuickType(s);
        _timeEntry.from = quickEntryModel.from;
        _timeEntry.duration = quickEntryModel.duration;
        _timeEntry.comment = quickEntryModel.message;
      },
    );
  }
}
