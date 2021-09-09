import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'input_widgets.dart';
import 'parse.dart';

class TimeDuration {
  DateTime? from;
  Duration? duration;
  DateTime? get to => (duration != null) ? from?.add(duration!) : null;
  bool get valid => from != null && duration != null;

  TimeDuration(this.from, this.duration);

  TimeDuration copyWith({DateTime? from, Duration? duration}) {
    return TimeDuration(from ?? this.from, duration ?? this.duration);
  }
}

class FromFormField extends FormField<TimeDuration> {
  FromFormField({FormFieldSetter<TimeDuration>? onSaved, Key? key, TimeDuration? initialValue})
      : super(
          key: key,
          initialValue: initialValue,
          validator: (v) => (v != null && v.valid) ? null : 'Both From and Duration must be filled out',
          onSaved: onSaved,
          builder: (field) {
            var state = (field as _FromFormFieldState);

            return Row(
              children: [
                SizedBox(
                    width: 120,
                    child: TextFormField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                        hintText: '13:30',
                        helperText: 'hh[:mm]',
                        labelText: 'From',
                      ),
                      validator: (v) => isTime(v) ? null : "Not in HH:mm or HH time format",
                      controller: state._fromController,
                      focusNode: state._fromFocusNode,
                      onChanged: (s) {
                        final td = field.value ?? TimeDuration(null, null);
                        final t = parseTime(s);
                        td.from = t;
                        field.didChange(td);
                      },
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')), LengthLimitingTextInputFormatter(5)],
                    )),
                SizedBox(width: 16),
                SizedBox(
                    width: 120,
                    child: TextFormField(
                      decoration: InputDecoration(
                        icon: Icon(Icons.timelapse),
                        border: OutlineInputBorder(),
                        hintText: '1.0',
                        helperText: 'h[.h]',
                        labelText: 'Duration',
                      ),
                      validator: (v) => isDuration(v) ? null : "Not an int",
                      controller: state._durationController,
                      focusNode: state._durationFocusNode,
                      onChanged: (s) {
                        final td = field.value ?? TimeDuration(null, null);
                        final d = parseDuration(s);
                        td.duration = d;
                        field.didChange(td);
                      },
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(3)],
                    )),
                SizedBox(width: 16),
                SizedBox(
                    width: 120,
                    child: TextField(
                      decoration: InputDecoration(
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        icon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                        helperText: '',
                        labelText: 'To',
                      ),
                      enabled: false,
                      controller: state._toController,
                    )),
              ],
            );
          },
        );

  @override
  _FromFormFieldState createState() => _FromFormFieldState();
}

class _FromFormFieldState extends FormFieldState<TimeDuration> {
  late TextEditingController _fromController;
  late TextEditingController _durationController;
  late TextEditingController _toController;

  FocusNode _fromFocusNode = FocusNode();
  FocusNode _durationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: formatTime(value?.from));
    _durationController = TextEditingController(text: formatDuration(value?.duration));
    _toController = TextEditingController(text: formatTime(value?.to));

    selectAllOnFocusChange(_fromFocusNode, _fromController);
    selectAllOnFocusChange(_durationFocusNode, _durationController);
  }

  @override
  void didChange(TimeDuration? value) {
    _toController.text = formatTime(value?.to);
    super.didChange(value);
  }

  @override
  void dispose() {
    super.dispose();

    _fromFocusNode.dispose();
    _durationFocusNode.dispose();

    _fromController.dispose();
    _durationController.dispose();
    _toController.dispose();
  }
}
