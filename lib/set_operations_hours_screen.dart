import 'package:flutter/material.dart';

class OperatingHours {
  final TimeOfDay openTime;
  final TimeOfDay closeTime;
  final bool isOpen;

  const OperatingHours({
    required this.openTime,
    required this.closeTime,
    this.isOpen = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'openTime': '${openTime.hour}:${openTime.minute}',
      'closeTime': '${closeTime.hour}:${closeTime.minute}',
      'isOpen': isOpen,
    };
  }

  factory OperatingHours.fromJson(Map<String, dynamic> json) {
    return OperatingHours(
      openTime: TimeOfDay(
        hour: int.parse(json['openTime'].split(':')[0]),
        minute: int.parse(json['openTime'].split(':')[1]),
      ),
      closeTime: TimeOfDay(
        hour: int.parse(json['closeTime'].split(':')[0]),
        minute: int.parse(json['closeTime'].split(':')[1]),
      ),
      isOpen: json['isOpen'] as bool,
    );
  }

  OperatingHours copyWith({
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
    bool? isOpen,
  }) {
    return OperatingHours(
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      isOpen: isOpen ?? this.isOpen,
    );
  }
}

class SetOperatingHoursScreen extends StatefulWidget {
  final Map<String, OperatingHours>? initialHours;

  const SetOperatingHoursScreen({
    Key? key,
    this.initialHours,
  }) : super(key: key);

  @override
  State<SetOperatingHoursScreen> createState() =>
      _SetOperatingHoursScreenState();
}

class _SetOperatingHoursScreenState extends State<SetOperatingHoursScreen> {
  late Map<String, OperatingHours> _operatingHours;
  bool _hasUnsavedChanges = false;

  // Predefined operating hours templates
  final Map<String, Map<String, OperatingHours>> _operatingHoursTemplates = {
    'Standard Evening Hours': {
      'Monday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Tuesday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Wednesday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Thursday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Friday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Saturday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Sunday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
    },
    'Weekend Only': {
      'Monday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: false),
      'Tuesday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: false),
      'Wednesday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: false),
      'Thursday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: false),
      'Friday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
      'Saturday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 3, minute: 0),
          isOpen: true),
      'Sunday': OperatingHours(
          openTime: TimeOfDay(hour: 16, minute: 0),
          closeTime: TimeOfDay(hour: 2, minute: 0),
          isOpen: true),
    },
    'Late Night Hours': {
      'Monday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 4, minute: 0),
          isOpen: true),
      'Tuesday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 4, minute: 0),
          isOpen: true),
      'Wednesday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 4, minute: 0),
          isOpen: true),
      'Thursday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 4, minute: 0),
          isOpen: true),
      'Friday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 5, minute: 0),
          isOpen: true),
      'Saturday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 5, minute: 0),
          isOpen: true),
      'Sunday': OperatingHours(
          openTime: TimeOfDay(hour: 20, minute: 0),
          closeTime: TimeOfDay(hour: 4, minute: 0),
          isOpen: true),
    },
  };

  @override
  void initState() {
    super.initState();
    _operatingHours = widget.initialHours?.map(
          (key, value) => MapEntry(key, value),
        ) ??
        {
          'Monday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
          'Tuesday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
          'Wednesday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
          'Thursday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
          'Friday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
          'Saturday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
          'Sunday': OperatingHours(
            openTime: const TimeOfDay(hour: 16, minute: 0),
            closeTime: const TimeOfDay(hour: 2, minute: 0),
            isOpen: true,
          ),
        };
  }

  Future<TimeOfDay?> _showTimePicker(
      BuildContext context, TimeOfDay initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Do you want to discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
              },
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          _showUnsavedChangesDialog();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Set Operating Hours'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_hasUnsavedChanges) {
                _showUnsavedChangesDialog();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Return the operating hours to the signup screen
                Navigator.pop(context, _operatingHours);
                _hasUnsavedChanges = false;
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Quick Templates Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Templates',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        hint: const Text('Select a template'),
                        items: _operatingHoursTemplates.keys
                            .map((String template) {
                          return DropdownMenuItem<String>(
                            value: template,
                            child: Text(template),
                          );
                        }).toList(),
                        onChanged: (String? template) {
                          if (template != null) {
                            setState(() {
                              _operatingHours.clear();
                              _operatingHours
                                  .addAll(_operatingHoursTemplates[template]!);
                              _hasUnsavedChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Days List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _operatingHours.length,
                itemBuilder: (context, index) {
                  final day = _operatingHours.keys.elementAt(index);
                  final hours = _operatingHours[day]!;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                day,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: hours.isOpen,
                                onChanged: (bool value) {
                                  setState(() {
                                    _operatingHours[day] =
                                        hours.copyWith(isOpen: value);
                                    _hasUnsavedChanges = true;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (hours.isOpen) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Opening Time',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () async {
                                          final TimeOfDay? newTime =
                                              await _showTimePicker(
                                            context,
                                            hours.openTime,
                                          );
                                          if (newTime != null) {
                                            setState(() {
                                              _operatingHours[day] = hours
                                                  .copyWith(openTime: newTime);
                                              _hasUnsavedChanges = true;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_formatTimeOfDay(
                                                  hours.openTime)),
                                              const Icon(Icons.access_time,
                                                  size: 18),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Closing Time',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () async {
                                          final TimeOfDay? newTime =
                                              await _showTimePicker(
                                            context,
                                            hours.closeTime,
                                          );
                                          if (newTime != null) {
                                            setState(() {
                                              _operatingHours[day] = hours
                                                  .copyWith(closeTime: newTime);
                                              _hasUnsavedChanges = true;
                                            });
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(_formatTimeOfDay(
                                                  hours.closeTime)),
                                              const Icon(Icons.access_time,
                                                  size: 18),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
