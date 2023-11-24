import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:starklicht_flutter/messages/animation_message.dart';
import 'package:starklicht_flutter/messages/brightness_message.dart';
import 'package:starklicht_flutter/model/enums.dart';
import 'package:starklicht_flutter/model/models.dart';
import 'package:starklicht_flutter/view/animations.dart';
import 'package:starklicht_flutter/view/time_picker.dart';
import 'package:timelines/timelines.dart';

import '../controller/starklicht_bluetooth_controller.dart';
import '../messages/color_message.dart';
import '../messages/imessage.dart';
import '../model/orchestra.dart';
import '../persistence/persistence.dart';
import 'colors.dart';

enum EventStatus { NONE, PENDING, RUNNING, FINISHED }

class EventChanged {
  int index;
  EventStatus status;
  EventChanged(this.index, this.status);
}

class ChildEventChanged {
  int parentIndex;
  int childIndex;
  EventStatus status;
  double? progress;
  ChildEventChanged(this.parentIndex, this.childIndex, this.status,
      {this.progress});
}

class MessageNodeExecutor {
  List<MessageTrack> tracks;
  bool running;
  ValueChanged<double>? onProgressChanged;

  ValueChanged<EventChanged>? onEventUpdate;
  ValueChanged<ChildEventChanged>? onChildEventUpdate;

  MessageNodeExecutor(this.tracks,
      {this.running = false,
      this.onProgressChanged,
      this.onEventUpdate,
      this.onChildEventUpdate});

  Future<bool> waitForUserInput(BuildContext context) async {
    var continueProgram = false;
    await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text("Programm ist pausiert"),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () =>
                      {continueProgram = false, Navigator.pop(context)},
                  child: const Text("Abbrechen")),
              TextButton(
                  onPressed: () =>
                      {continueProgram = true, Navigator.pop(context)},
                  child: const Text("Fortsetzen"))
            ],
          );
        }).then((value) => {});
    return continueProgram;
  }

  Future<void> executeTrack(
      int trackIndex, Duration startTime, List<String> lampGroups) async {
    var track = tracks[trackIndex];
    var queue = Queue<EventNode>();
    var millis = startTime.inMilliseconds;
    var firstSleepTime = 0;
    if (millis > 0) {
      var lastTime = 0;
      var timeMap = <int, EventNode>{};
      for (var message in track.events) {
        lastTime += message.delay.inMilliseconds;
        timeMap[lastTime] = message;
      }
      var filteredTimes = timeMap.keys.where((time) => time > millis).toList();
      print(filteredTimes);
      if (filteredTimes.isEmpty) {
        print('Empty');
        return;
      }
      firstSleepTime = filteredTimes[0] - millis;
      queue.addAll(filteredTimes.map((e) => timeMap[e]!));
    } else {
      queue.addAll(track.events);
    }
    print(firstSleepTime);
    running = true;
    int currentIndex = -1;
    onEventUpdate?.call(EventChanged(trackIndex, EventStatus.RUNNING));
    while (queue.isNotEmpty && running) {
      var message = queue.removeFirst();
      currentIndex++;
      onChildEventUpdate?.call(
          ChildEventChanged(trackIndex, currentIndex, EventStatus.RUNNING));
      // TODO: IMPORTANT! SEND ONLY TO SPECIFIC GROUPS!
      if (message is MessageNode) {
        BluetoothControllerWidget()
            .broadcastToGroups(message.message, {lampGroups[trackIndex]});
      }
      if (currentIndex == 0 && millis > 0) {
        await Future.delayed(Duration(milliseconds: firstSleepTime));
      } else {
        await Future.delayed(message.delay);
      }
      onChildEventUpdate?.call(
          ChildEventChanged(trackIndex, currentIndex, EventStatus.FINISHED));
    }
    onEventUpdate?.call(EventChanged(trackIndex, EventStatus.FINISHED));
  }

  Future<void> execute(Duration startTime, List<String> lampGroups) async {
    tracks.asMap().forEach((index, value) {
      if (value.active) {
        executeTrack(index, startTime, lampGroups);
      }
    });
  }
}

class OrchestraTimeline extends StatefulWidget {
  var running = false;
  var zoomFactor = .5;
  var baseZoomFactor = 0.2;

  var scrollPosition = 0.0;
  var lastScrollPosition = 0.0;
  var cardHeight = 80.0;
  var cardHeights = [40.0, 60.0, 80.0];
  int selectedCardHeight = 0;
  var minTrackHeight = 40.0;
  var isDragging = false;
  var minZoomFactor = .02;
  var maxZoomFactor = 1.0;
  var restart = false;
  var opacityWhenDragging = .5;
  var opacityWhenInactive = .25;
  var maxTracks = 3;
  VoidCallback? play;
  VoidCallback? onFinishPlay;

  var lampGroups = ["fill", "key", "back"];

  var showMenu = true;
  double menuWidth = 180.0;

  List<MessageTrack> tracks = [
    MessageTrack(
      title: "Test",
      events: [
        MessageNode(
          lamps: const {},
          message: BrightnessMessage(10),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
      ],
    ),
    MessageTrack(
      events: [
        MessageNode(
          lamps: const {},
          message: BrightnessMessage(10),
          delay: const Duration(seconds: 1),
        ),
        MessageNode(
          lamps: const {},
          message: AnimationMessage(
              [ColorPoint(Colors.red, 0), ColorPoint(Colors.blue, 1)],
              AnimationSettingsConfig(
                InterpolationType.linear,
                TimeFactor.repeat,
                0,
                1,
                0,
              )),
          delay: const Duration(seconds: 1),
        ),
      ],
    ),
    MessageTrack(
      events: [],
    ),
  ];
  OrchestraTimeline({Key? key, this.play, this.onFinishPlay}) : super(key: key);

  @override
  State<StatefulWidget> createState() => OrchestraTimelineState();
}

class Ruler extends StatelessWidget {
  double zoom;
  int totalSeconds;
  Ruler({Key? key, required this.zoom, required this.totalSeconds})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
        children: List.generate(
            totalSeconds * 10,
            (index) => Stack(
                  children: [
                    Container(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index % 10 == 0) ...[
                            Text("${index ~/ 10}",
                                style: const TextStyle(fontSize: 10)),
                            const Text("|"),
                          ] else if (zoom > .1) ...[
                            const Text("|",
                                style: TextStyle(color: Colors.grey)),
                          ]
                        ],
                      ),
                    ),
                    Container(width: 100.0 * zoom)
                  ],
                )));
  }
}

class OrchestraTimelineState extends State<OrchestraTimeline> {
  IconData getDraggingIcon(int length) {
    return Icons.collections_bookmark_outlined;
  }

  MessageNodeExecutor? executor;

  @override
  void dispose() {
    executor?.running = false;
    scrollController.removeListener(() {});

    scrollController.dispose();
    super.dispose();
  }

  Widget getNode(
      Duration animationDuration,
      Curve animationCurve,
      double width,
      double opacity,
      MessageTrack e,
      EventNode message,
      Color? color,
      Gradient? gradient,
      {bool elevated = false}) {
    return AnimatedOpacity(
      duration: animationDuration,
      curve: animationCurve,
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(right: 2.0, bottom: 2.0),
        child: SizedBox(
          width: width,
          child: Card(
            elevation: elevated ? 8 : null,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: AnimatedContainer(
              duration: animationDuration,
              curve: animationCurve,
              decoration: BoxDecoration(
                  border: message.isSelected ? null : null,
                  borderRadius: BorderRadius.circular(2.0),
                  color: color,
                  gradient: gradient),
              clipBehavior: Clip.antiAlias,
              height: widget.cardHeights[widget.selectedCardHeight],
              child: Container(
                alignment: Alignment.center,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  direction: Axis.horizontal,
                  spacing: double.maxFinite,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "${message.getTitle()} (${message.formatTime()})",
                      style: const TextStyle(
                          fontSize: 10, overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                    Text(
                      message.getSubtitleText(),
                      style: const TextStyle(
                          fontSize: 8, overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      offsetListener.changes.listen((currentOffset) {
        setState(() {
          widget.lastScrollPosition = widget.scrollPosition;
          widget.scrollPosition += currentOffset;
        });
        var delta = widget.scrollPosition - widget.lastScrollPosition;
      });
    });
    widget.play = () {
      setState(() {
        for (var node in widget.tracks) {
          node.status = EventStatus.NONE;
        }
      });
      executor ??= MessageNodeExecutor(widget.tracks, onEventUpdate: (ev) {
        if (mounted) {
          setState(() {
            widget.tracks[ev.index].status = ev.status;
          });
          if (ev.status == EventStatus.FINISHED) {
            terminalController.text +=
                "\n${ev.index} status set to ${ev.status}";
          }
        }
      }, onChildEventUpdate: (ev) {
        if (mounted) {
          if (ev.status == EventStatus.RUNNING) {
            terminalController.text +=
                "\n${ev.parentIndex} sent message ${ev.childIndex}";
          }
        }
      });

      executor
          ?.execute(getScrollLocation(), widget.lampGroups)
          .then((value) {});
    };
  }

  int expandedTitle = -1;
  int addParentId = -1;
  DragType dragType = DragType.GROUP;
  ScrollController scrollController = ScrollController();
  ScrollOffsetListener offsetListener = ScrollOffsetListener.create();
  ScrollOffsetController offsetController = ScrollOffsetController();
  LinkedScrollControllerGroup group = LinkedScrollControllerGroup();

  ScrollOffsetController offsetController2 = ScrollOffsetController();
  TextEditingController terminalController = TextEditingController();
  int getPlayTime() {
    var playTimes = widget.tracks
        .expand((e) => {
              e.events
                  .fold(0, (int sum, item) => sum + item.delay.inMilliseconds)
            })
        .toList();
    return playTimes.reduce(max);
  }

  Offset myOffset(
      Draggable<Object> draggable, BuildContext context, Offset position) {
    final RenderBox renderObject = context.findRenderObject()! as RenderBox;
    var pos = renderObject.globalToLocal(position);
    return Offset(0, pos.dy);
  }

  @override
  Widget build(BuildContext context) {
    var animationDuration = Duration(milliseconds: 500);
    var animationCurve = Curves.ease;
    var menuItemHeight = max(widget.minTrackHeight,
            widget.cardHeights[widget.selectedCardHeight]) +
        2;
    var menuActive = widget.scrollPosition <
            MediaQuery.of(context).size.width / 2 - widget.menuWidth + 8 &&
        !widget.isDragging;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      widget.running = false;
                    });
                    offsetController.animateScroll(
                        offset: -widget.scrollPosition,
                        duration: animationDuration);
                  },
                  icon: Icon(Icons.skip_previous)),
              IconButton(
                  onPressed: () {
                    setState(() {
                      widget.running = !widget.running;
                    });
                    if (widget.running) {
                      // Play via executor
                      setState(() {
                        widget.showMenu = false;
                      });
                      widget.play?.call();
                      offsetController
                          .animateScroll(
                              offset: (getPlayTime()) * widget.zoomFactor,
                              duration: Duration(
                                  milliseconds: getPlayTime() -
                                      getScrollLocation().inMilliseconds),
                              curve: Curves.linear)
                          .then((value) {
                        if (mounted) {
                          setState(() {
                            offsetController.animateScroll(
                                offset: -widget.scrollPosition,
                                duration: animationDuration);
                            widget.running = false;
                            executor?.running = false;
                          });
                        }
                      });
                    } else {
                      setState(() {
                        widget.showMenu = true;
                      });
                      offsetController.animateScroll(
                          offset: 0,
                          duration: animationDuration,
                          curve: animationCurve);
                    }
                  },
                  icon: Icon(widget.running ? Icons.stop : Icons.play_arrow))
            ],
          ),
          Text(formatScrollTime(),
              style: TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: (details) {
              setState(() {
                widget.baseZoomFactor = widget.zoomFactor;
              });
            },
            onScaleUpdate: (details) {
              setState(() {
                var zoom = widget.baseZoomFactor * details.scale;
                zoom = max(widget.minZoomFactor, zoom);
                zoom = min(widget.maxZoomFactor, zoom);
                var zoomDelta = widget.zoomFactor - zoom;
                widget.zoomFactor = zoom;
                var currentTime = scrollController.offset / widget.zoomFactor;
                // TODO: Je weiter rechts sich die Animation befindet, desto mehr "lenkt" sie nach links
                scrollController
                    .jumpTo(scrollController.offset - zoomDelta * currentTime);
              });
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: widget.cardHeights[widget.selectedCardHeight] *
                          widget.lampGroups.length,
                      child: ScrollablePositionedList.builder(
                          itemCount: widget.tracks[0].events.length + 2,
                          scrollDirection: Axis.horizontal,
                          scrollOffsetController: offsetController,
                          scrollOffsetListener: offsetListener,
                          itemBuilder: (context, index) {
                            var currentItemCount =
                                widget.tracks[0].events.length;
                            if (index == 0 || index > currentItemCount) {
                              return SizedBox(
                                width: MediaQuery.of(context).size.width / 2,
                              );
                            }
                            var e = widget.tracks[0];
                            var message = e.events[index - 1];
                            var color =
                                message.cardIndicator == CardIndicator.COLOR
                                    ? message.toColor()
                                    : message.cardIndicator ==
                                            CardIndicator.PROGRESS
                                        ? Theme.of(context).colorScheme.surface
                                        : null;
                            var gradient =
                                message.cardIndicator == CardIndicator.GRADIENT
                                    ? message.toGradient()
                                    : null;

                            return Stack(children: [
                              LongPressDraggable<DragData>(
                                  data: DragData(
                                      parentId: widget.tracks.indexOf(e),
                                      index: e.events.indexOf(message),
                                      dragType: DragType.NODE),
                                  onDragStarted: () => setState(() {
                                        widget.isDragging = true;
                                      }),
                                  onDragEnd: (details) => setState(() {
                                        widget.isDragging = false;
                                      }),
                                  dragAnchorStrategy: myOffset,
                                  childWhenDragging: getNode(
                                      animationDuration,
                                      animationCurve,
                                      max(
                                          message.delay.inMilliseconds *
                                                  (widget.zoomFactor) -
                                              2,
                                          0),
                                      .2,
                                      e,
                                      message,
                                      color,
                                      gradient),
                                  feedback: getNode(
                                      animationDuration,
                                      animationCurve,
                                      150,
                                      !e.active
                                          ? widget.opacityWhenInactive
                                          : message.isDragging
                                              ? widget.opacityWhenDragging
                                              : 1,
                                      e,
                                      message,
                                      color,
                                      gradient,
                                      elevated: true),
                                  child: InkWell(
                                    child: getNode(
                                        animationDuration,
                                        animationCurve,
                                        max(
                                            message.delay.inMilliseconds *
                                                    (widget.zoomFactor) -
                                                2,
                                            0),
                                        !e.active
                                            ? widget.opacityWhenInactive
                                            : message.isDragging
                                                ? widget.opacityWhenDragging
                                                : 1,
                                        e,
                                        message,
                                        color,
                                        gradient),
                                    onTap: () => {
                                      showDialog(
                                          context: context,
                                          builder: (_) {
                                            var currentDur = Duration(
                                                milliseconds: message
                                                    .delay.inMilliseconds);
                                            return AlertDialog(
                                              title: Text("Zeit bearbeiten"),
                                              scrollable: false,
                                              content: Container(
                                                height: 200,
                                                child: TimePicker(
                                                    startDuration: currentDur,
                                                    onChanged: (dur) =>
                                                        {currentDur = dur}),
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () => {
                                                          Navigator.pop(context)
                                                        },
                                                    child: Text(
                                                      "Abbrechen",
                                                    )),
                                                TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        message.delay =
                                                            currentDur;
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                    child: Text(
                                                      "Anwenden",
                                                    ))
                                              ],
                                            );
                                          })
                                    },
                                  ))
                            ]);
                          }),
                    ),
                  ],
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width / 2,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                        duration: Duration(milliseconds: 250),
                        curve: Curves.ease,
                        width: menuActive ? widget.menuWidth : 0,
                        child: Card(
                          elevation: 32,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(4.0),
                              topRight: Radius.circular(4.0),
                            ),
                          ),
                          margin: EdgeInsets.only(right: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...List.generate(widget.maxTracks,
                                      (int index) => index).map((e) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 800),
                                          curve: animationCurve,
                                          height: menuItemHeight - 1,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Checkbox(
                                                  activeColor: Colors.green,
                                                  value:
                                                      widget.tracks[e].active,
                                                  onChanged: (val) => {
                                                        setState(() {
                                                          widget.tracks[e]
                                                              .active = val!;
                                                        })
                                                      }),
                                              LampGroupChip(
                                                  name: widget.lampGroups[e]),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 1, child: Divider())
                                      ],
                                    );
                                  }),
                                ]),
                          ),
                        )),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(
                      left: MediaQuery.of(context).size.width / 2 - 1,
                      right: MediaQuery.of(context).size.width / 2 - 1),
                  child: AnimatedContainer(
                      duration: animationDuration,
                      curve: animationCurve,
                      height: (menuItemHeight + 2) * widget.maxTracks - 16,
                      child: Container(
                          decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.2),
                            blurRadius: 4.0,
                            spreadRadius: 0.0,
                            offset: Offset(
                                2.0, 2.0), // shadow direction: bottom right
                          )
                        ],
                        border: Border(
                            left: BorderSide(color: Colors.white, width: 2)),
                      ))),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          ToggleButtons(
            isSelected: [
              widget.selectedCardHeight == 0,
              widget.selectedCardHeight == 1,
              widget.selectedCardHeight == 2
            ],
            children: [
              Icon(Icons.density_small),
              Icon(Icons.density_medium),
              Icon(Icons.density_large)
            ],
            onPressed: (i) => {
              setState(() {
                widget.selectedCardHeight = i;
              })
            },
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(height: 20),
          AnimatedOpacity(
            opacity: widget.isDragging ? 1 : 0,
            duration: animationDuration,
            curve: animationCurve,
            child: DragTarget<DragData>(
              builder: ((context, candidateData, rejectedData) => Icon(
                    candidateData.length > 0
                        ? Icons.delete_forever
                        : Icons.delete,
                    size: 32,
                    color: Theme.of(context).colorScheme.error,
                  )),
              onWillAccept: (data) {
                return true;
              },
              onAccept: (data) {
                setState(() {
                  var snackBar = SnackBar(
                    content: Text('Element wurde gelöscht.'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                  widget.tracks[data.parentId].events.removeAt(data.index);
                });
              },
            ),
          )
        ],
      ),
    );
  }

  List<AnimationMessage> _animationStore = [];
  var _messageType = MessageType.brightness;
  var _currentBrightness = 100.0;
  var _currentColor = Colors.white;

  void openAddDialog(BuildContext context, StateSetter setState, int parentId) {
    showDialog(
        context: context,
        builder: (_) {
          Persistence()
              .getAnimationStore()
              .then((value) => _animationStore = value);
          int? selectedAnimation = 0;
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              scrollable: true,
              title: const Text("Zeitevent hinzufügen"),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TODO Export this into an own fucker
                  RadioListTile<MessageType>(
                      value: MessageType.brightness,
                      title: const Text("Helligkeit"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  RadioListTile<MessageType>(
                      value: MessageType.color,
                      title: const Text("Farbe"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  RadioListTile<MessageType>(
                      value: MessageType.interpolated,
                      title: const Text("Animation"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  if (_messageType == MessageType.brightness) ...[
                    Text("Helligkeit bestimmen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    Column(
                      children: [
                        Slider(
                          max: 100,
                          onChangeEnd: (d) => {
                            setState(() {
                              _currentBrightness = d;
                            }),
                          },
                          onChanged: (d) => {
                            setState(() {
                              _currentBrightness = d;
                            }),
                          },
                          value: _currentBrightness,
                        ),
                        Text(
                          "${_currentBrightness.toInt()}%",
                          style: const TextStyle(fontSize: 32),
                        )
                      ],
                    )
                  ] else if (_messageType == MessageType.color) ...[
                    Text("Farbe auswählen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    ColorsWidget(
                      startColor: _currentColor,
                      onChanged: (c) => {
                        setState(() {
                          _currentColor = c;
                        })
                      },
                    )
                  ] else if (_messageType == MessageType.interpolated) ...[
                    Text("Animation aus Liste auswählen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    // Persistence
                    DropdownButton<int>(
                      items: _animationStore
                          .mapIndexed((animation, index) =>
                              DropdownMenuItem<int>(
                                  value: index, child: Text(animation.title!)))
                          .toList(),
                      onChanged: (i) => {
                        setState(() {
                          selectedAnimation = i;
                        })
                      },
                      value: selectedAnimation,
                    )
                  ]
                ],
              ),
              actions: [
                TextButton(
                    child: const Text("Abbrechen"),
                    onPressed: () => {Navigator.pop(context)}),
                TextButton(
                    child: const Text("Hinzufügen"),
                    onPressed: () {
                      setState(() {
                        // TODO: Implement factory pattern
                        IBluetoothMessage? message;
                        if (_messageType == MessageType.color) {
                          message = ColorMessage.fromColor(_currentColor);
                        } else if (_messageType == MessageType.brightness) {
                          message =
                              BrightnessMessage(_currentBrightness.toInt());
                        }
                        if (_messageType == MessageType.interpolated) {
                          if (selectedAnimation != null) {
                            message = _animationStore[selectedAnimation!];
                          }
                        }
                        if (message == null) {
                          return;
                        }
                        setState(() {
                          widget.tracks[parentId].events.add(MessageNode(
                              lamps: const {},
                              message: message!,
                              delay: Duration(seconds: 1)));
                        });
                      });
                      refresh();
                      Navigator.pop(context);
                    })
              ],
            );
          });
        });
  }

  void refresh() {
    setState(() {});
  }

  Duration getScrollLocation() {
    return Duration(milliseconds: (widget.scrollPosition ~/ widget.zoomFactor));
  }

  String formatScrollTime() {
    var time = getScrollLocation();
    var minutes = max(time.inMinutes.remainder(60), 0).toString();
    var seconds = max(time.inSeconds.remainder(60), 0).toString();
    var millis = max(time.inMilliseconds.remainder(1000) ~/ 10, 0).toString();
    return "${minutes.padLeft(2, '0')}:${seconds.padLeft(2, '0')}:${millis.padLeft(2, '0')}";
  }

  bool hasReached(index) {
    if (index > widget.tracks.length - 1) {
      if (widget.tracks[widget.tracks.length - 1].status ==
          EventStatus.FINISHED) {
        return true;
      }
      return false;
    }
    return widget.tracks[index].status == EventStatus.RUNNING ||
        widget.tracks[index].status == EventStatus.FINISHED;
  }

  bool isRunning(index) {
    if (index > widget.tracks.length - 1) {
      return false;
    }
    return widget.tracks[index].status == EventStatus.RUNNING;
  }

  IconData getIcon(index) {
    if (index > widget.tracks.length - 1) {
      if (widget.tracks[widget.tracks.length - 1].status ==
          EventStatus.FINISHED) {
        return Icons.checklist;
      }
      return Icons.flag;
    }
    switch (widget.tracks[index].status) {
      case EventStatus.NONE:
        return Icons.arrow_downward;
      case EventStatus.PENDING:
        return Icons.timelapse;
      case EventStatus.RUNNING:
        return Icons.add;
      case EventStatus.FINISHED:
        return Icons.check;
    }
  }

  Color getDotIndicatorColor(index) {
    if (index > widget.tracks.length - 1) {
      if (widget.tracks[widget.tracks.length - 1].status ==
          EventStatus.FINISHED) {
        return Colors.green;
      }
      return Theme.of(context).colorScheme.background;
    }
    switch (widget.tracks[index].status) {
      case EventStatus.PENDING:
        return Colors.blueGrey;
      case EventStatus.RUNNING:
        return Colors.blue;
      case EventStatus.FINISHED:
        return Colors.green;
      case EventStatus.NONE:
        return Theme.of(context).colorScheme.background;
    }
  }
}

class _DeliveryMessage {
  const _DeliveryMessage(this.createdAt, this.message);

  final String createdAt; // final DateTime createdAt;
  final String message;

  @override
  String toString() {
    return '$createdAt $message';
  }
}

class InnerTimeline extends StatefulWidget {
  List<EventNode> messages;
  int parentId;
  int dragTargetIndex = -1;
  int data = -1;
  ExpansionDirection expansionDirection = ExpansionDirection.BOTTOM;
  ValueChanged<MoveNodeEvent> onMoveNodeToOtherParent;

  InnerTimeline(
      {Key? key,
      required this.messages,
      required this.parentId,
      required this.onMoveNodeToOtherParent})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => InnerTimelineState();
}

class MoveNodeEvent {
  DragData from;
  DragData to;

  @override
  String toString() {
    return "From: id = ${from.index}, parentId = ${from.parentId}, to: id = ${to.index}, parentId = ${to.parentId}";
  }

  MoveNodeEvent({required this.from, required this.to});
}

enum DragType { GROUP, NODE }

class DragData {
  int parentId;
  int index;
  DragType dragType;
  DragData(
      {required this.parentId, required this.index, required this.dragType});

  bool equals(var other) {
    if (other is DragData) {
      return parentId == other.parentId &&
          index == other.index &&
          dragType == other.dragType;
    }
    return false;
  }

  @override
  String toString() {
    return "parent: ${parentId} id: ${index}";
  }
}

enum ExpansionDirection { TOP, BOTTOM }

class InnerTimelineState extends State<InnerTimeline> {
  List<AnimationMessage> _animationStore = [];
  var _messageType = MessageType.brightness;
  var _currentBrightness = 100.0;
  var _currentColor = Colors.white;

  void refresh() {
    setState(() {});
  }

  void openAddDialog(BuildContext context, StateSetter setState) {
    showDialog(
        context: context,
        builder: (_) {
          Persistence()
              .getAnimationStore()
              .then((value) => _animationStore = value);
          int? selectedAnimation = 0;
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              scrollable: true,
              title: const Text("Zeitevent hinzufügen"),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TODO Export this into an own fucker
                  RadioListTile<MessageType>(
                      value: MessageType.brightness,
                      title: const Text("Helligkeit"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  RadioListTile<MessageType>(
                      value: MessageType.color,
                      title: const Text("Farbe"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  RadioListTile<MessageType>(
                      value: MessageType.interpolated,
                      title: const Text("Animation"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  if (_messageType == MessageType.brightness) ...[
                    Text("Helligkeit bestimmen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    Column(
                      children: [
                        Slider(
                          max: 100,
                          onChangeEnd: (d) => {
                            setState(() {
                              _currentBrightness = d;
                            }),
                          },
                          onChanged: (d) => {
                            setState(() {
                              _currentBrightness = d;
                            }),
                          },
                          value: _currentBrightness,
                        ),
                        Text(
                          "${_currentBrightness.toInt()}%",
                          style: const TextStyle(fontSize: 32),
                        )
                      ],
                    )
                  ] else if (_messageType == MessageType.color) ...[
                    Text("Farbe auswählen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    ColorsWidget(
                      startColor: _currentColor,
                      onChanged: (c) => {
                        setState(() {
                          _currentColor = c;
                        })
                      },
                    )
                  ] else if (_messageType == MessageType.interpolated) ...[
                    Text("Animation aus Liste auswählen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    // Persistence
                    DropdownButton<int>(
                      items: _animationStore
                          .mapIndexed((animation, index) =>
                              DropdownMenuItem<int>(
                                  value: index, child: Text(animation.title!)))
                          .toList(),
                      onChanged: (i) => {
                        setState(() {
                          selectedAnimation = i;
                        })
                      },
                      value: selectedAnimation,
                    )
                  ]
                ],
              ),
              actions: [
                TextButton(
                    child: const Text("Abbrechen"),
                    onPressed: () => {Navigator.pop(context)}),
                TextButton(
                    child: const Text("Hinzufügen"),
                    onPressed: () {
                      setState(() {
                        // TODO: Implement factory pattern
                        IBluetoothMessage? message;
                        if (_messageType == MessageType.color) {
                          message = ColorMessage.fromColor(_currentColor);
                        } else if (_messageType == MessageType.brightness) {
                          message =
                              BrightnessMessage(_currentBrightness.toInt());
                        }
                        if (_messageType == MessageType.interpolated) {
                          if (selectedAnimation != null) {
                            message = _animationStore[selectedAnimation!];
                          }
                        }
                        if (message == null) {
                          return;
                        }
                        widget.messages.add(
                            MessageNode(lamps: const {}, message: message));
                      });
                      refresh();
                      Navigator.pop(context);
                    })
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    bool isEdgeIndex(int index) {
      return index == 0 || index == widget.messages.length + 1;
    }

    bool isLastIndex(int index) {
      return index == widget.messages.length + 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: FixedTimeline.tileBuilder(
        theme: TimelineTheme.of(context).copyWith(
          nodePosition: 0,
          connectorTheme: TimelineTheme.of(context).connectorTheme.copyWith(
                thickness: 1.0,
              ),
          indicatorTheme: TimelineTheme.of(context).indicatorTheme.copyWith(
                size: 10.0,
                position: 0.5,
              ),
        ),
        builder: TimelineTileBuilder(
          indicatorBuilder: (_, index) =>
              !isEdgeIndex(index) ? Indicator.outlined(borderWidth: 1.0) : null,
          startConnectorBuilder: (_, index) => Connector.solidLine(),
          endConnectorBuilder: (_, index) => Connector.solidLine(),
          contentsBuilder: (_, index) {
            if (isLastIndex(index)) {
              return ElevatedButton(
                child: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: () => {openAddDialog(context, setState)},
              );
            } else if (isEdgeIndex(index)) {
              return null;
            }
            return DraggableMessageNode(
              message: widget.messages[index - 1],
              index: index - 1,
              parentId: widget.parentId,
              onDelete: () => {
                setState(() {
                  widget.messages.removeAt(index - 1);
                })
              },
              onAccept: (MoveNodeEvent event) {
                if (event.from.parentId != event.to.parentId) {
                  widget.onMoveNodeToOtherParent.call(event);
                } else {
                  setState(() {
                    EventNode node = widget.messages.removeAt(event.from.index);
                    widget.messages.insert(event.to.index, node);
                  });
                }
              },
            );
          },
          nodeItemOverlapBuilder: (_, index) =>
              isEdgeIndex(index) ? true : null,
          itemCount: widget.messages.length + 2,
        ),
      ),
    );
  }
}

class DraggableMessageNode extends StatefulWidget {
  EventNode message;
  int index;
  double dragExpansion;
  int parentId;
  ValueChanged<MoveNodeEvent>? onAccept;
  VoidCallback? onDelete;
  VoidCallback? onEdit;
  bool isDragGoal = false;
  bool finished;
  ExpansionDirection expansionDirection = ExpansionDirection.TOP;
  VoidCallback? doRefresh;

  DraggableMessageNode(
      {Key? key,
      required this.message,
      required this.index,
      required this.parentId,
      this.onAccept,
      this.onDelete,
      this.dragExpansion = 78,
      this.finished = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => DraggableMessageNodeState();
}

class DraggableMessageNodeState extends State<DraggableMessageNode> {
  bool timeIsExtended = false;

  Widget? getLeading(bool verySmall) {
    if (verySmall) {
      return null;
    }
    if (widget.message.status == EventStatus.RUNNING) {
      return Transform.scale(
          scale: 0.5,
          child: CircularProgressIndicator(value: widget.message.progress));
    } else if (widget.message.status == EventStatus.FINISHED) {
      return const Icon(
        Icons.check,
        color: Colors.green,
      );
    }
    return null;
  }

  getCard(BuildContext context,
      {bool dragging = false, bool verySmall = false}) {
    var currentMessage = widget.message;
    return Card(
      elevation: dragging ? 8.0 : 1.0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          currentMessage.displayAsProgressBar()
              ? LinearProgressIndicator(
                  value: currentMessage.toPercentage(),
                  minHeight: verySmall ? 4 : 8,
                )
              : Container(
                  height: verySmall ? 4 : 12,
                  decoration: BoxDecoration(
                    color: currentMessage.cardIndicator == CardIndicator.COLOR
                        ? currentMessage.toColor()
                        : null,
                    gradient:
                        currentMessage.cardIndicator == CardIndicator.GRADIENT
                            ? currentMessage.toGradient()
                            : null,
                    boxShadow: [
                      BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .shadow
                              .withOpacity(.2),
                          offset: const Offset(0, 0),
                          blurRadius: 2)
                    ],
                  ),
                ),
          ListTile(
            dense: true,
            leading: getLeading(verySmall),
            title: Text(currentMessage.getTitle(),
                style: Theme.of(context).textTheme.titleLarge),
            isThreeLine: true,
            subtitle: verySmall
                ? widget.message.lamps.length == 0
                    ? const Text("Keine Beschränkungen")
                    : Text("${widget.message.lamps.length} Beschränkungen")
                : currentMessage.getSubtitle(
                    context, Theme.of(context).textTheme.bodySmall!),
            trailing: verySmall
                ? null
                : Wrap(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              {openEditMessage(context, setState)}),
                      IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => {widget.onDelete?.call()}),
                    ],
                  ),
          ),
          if (!verySmall && widget.message.hasLamps()) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Gruppenbeschränkungen",
                  style: Theme.of(context).textTheme.subtitle1),
            ),
            currentMessage,
            const SizedBox(height: 12),
          ]
        ],
      ),
    );
  }

  ExpansionDirection? isHovering() {
    return widget.isDragGoal ? widget.expansionDirection : null;
  }

  bool isHoveringBottom() {
    return isHovering() == ExpansionDirection.BOTTOM;
  }

  bool isHoveringTop() {
    return isHovering() == ExpansionDirection.TOP;
  }

  GlobalKey key = GlobalKey();

  RenderBox getRenderBox() {
    return key.currentContext?.findRenderObject() as RenderBox;
  }

  DragData? willAccept(DragData from) {
    int newIndex;
    if (from.parentId == widget.parentId) {
      if (widget.index > from.index) {
        // When Moving down
        if (widget.expansionDirection == ExpansionDirection.TOP) {
          newIndex = widget.index - 1;
        } else {
          newIndex = widget.index;
        }
      } else {
        // When moving up
        if (widget.expansionDirection == ExpansionDirection.TOP) {
          newIndex = widget.index;
        } else {
          newIndex = widget.index + 1;
        }
      }
    } else {
      // If parent is different, we can just insert it
      if (widget.expansionDirection == ExpansionDirection.TOP) {
        newIndex = widget.index;
      } else {
        newIndex = widget.index + 1;
      }
    }
    var newPosition = DragData(
        parentId: widget.parentId, index: newIndex, dragType: DragType.NODE);
    if (from.equals(newPosition)) {
      return null;
    }
    return newPosition;
  }

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<DragData>(
      childWhenDragging: Opacity(opacity: .2, child: getCard(context)),
      data: DragData(
          parentId: widget.parentId,
          index: widget.index,
          dragType: DragType.NODE),
      child: DragTarget(
        key: key,
        onMove: (DragTargetDetails<DragData> details) {
          RenderBox box = key.currentContext?.findRenderObject() as RenderBox;
          Offset position =
              box.localToGlobal(Offset.zero); //this is global position
          double y = position.dy; //this is y - I think it's what you want
          double height = box.size.height;
          if (y + height / 2 > details.offset.dy) {
            setState(() {
              widget.expansionDirection = ExpansionDirection.TOP;
            });
          } else {
            setState(() {
              widget.expansionDirection = ExpansionDirection.BOTTOM;
            });
          }
        },
        onWillAccept: (DragData? data) {
          if (data?.index == widget.index &&
                  data?.parentId == widget.parentId ||
              data?.dragType == DragType.GROUP) {
            return false;
          }
          setState(() {
            widget.isDragGoal = true;
          });
          return true;
        },
        onLeave: (DragData? data) => {
          setState(() {
            widget.isDragGoal = false;
          })
        },
        builder: (
          BuildContext context,
          List<dynamic> accepted,
          List<dynamic> rejected,
        ) {
          return Column(
            children: [
              AnimatedContainer(
                width: 200,
                height: isHoveringTop() ? widget.dragExpansion : 0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.ease,
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              getCard(context),
              AnimatedContainer(
                width: 200,
                height: isHoveringBottom() ? widget.dragExpansion : 0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.ease,
                decoration: BoxDecoration(
                  color: Colors.lightBlue.withOpacity(.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              )
            ],
          );
        },
        onAccept: (DragData data) => {
          setState(() {
            widget.isDragGoal = false;
            // Move
            int newIndex = widget.index;
            // If moving to the same parent, we have to consider that this element is taken out
            if (data.parentId == widget.parentId) {
              if (widget.index > data.index) {
                // When Moving down
                if (widget.expansionDirection == ExpansionDirection.TOP) {
                  newIndex = widget.index - 1;
                } else {
                  newIndex = widget.index;
                }
              } else {
                // When moving up
                if (widget.expansionDirection == ExpansionDirection.TOP) {
                  newIndex = widget.index;
                } else {
                  newIndex = widget.index + 1;
                }
              }
            } else {
              // If parent is different, we can just insert it
              if (widget.expansionDirection == ExpansionDirection.TOP) {
                newIndex = widget.index;
              } else {
                newIndex = widget.index + 1;
              }
            }

            var newPosition = DragData(
                parentId: widget.parentId,
                index: newIndex,
                dragType: DragType.NODE);
            if (data.equals(newPosition)) {
              return;
            }
            var event = MoveNodeEvent(from: data, to: newPosition);
            widget.onAccept?.call(event);
          })
        },
      ),
      dragAnchorStrategy: myOffset,
      feedback: SizedBox(
        width: 200,
        height: widget.dragExpansion,
        child: getCard(context, dragging: true, verySmall: true),
      ),
    );
  }

  Offset myOffset(
      Draggable<Object> draggable, BuildContext context, Offset position) {
    final RenderBox renderObject = context.findRenderObject()! as RenderBox;
    var pos = renderObject.globalToLocal(position);
    return Offset(pos.dx, widget.dragExpansion / 2);
  }

  void openEditMessage(BuildContext context, StateSetter setState) {
    assert(widget.message is MessageNode);
    var m = widget.message as MessageNode;
    var _messageType = m.message.messageType;
    var _currentBrightness = m.message.toPercentage() * 100;
    var _currentColor = m.message.toColor();
    var _animationStore = [];
    showDialog(
        context: context,
        builder: (_) {
          Persistence()
              .getAnimationStore()
              .then((value) => _animationStore = value);
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              scrollable: true,
              title: const Text("Zeitevent ändern"),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TODO Export this into an own fucker
                  RadioListTile<MessageType>(
                      value: MessageType.brightness,
                      title: const Text("Helligkeit"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  RadioListTile<MessageType>(
                      value: MessageType.color,
                      title: const Text("Farbe"),
                      groupValue: _messageType,
                      onChanged: (value) => {
                            setState(() {
                              _messageType = value!;
                            })
                          }),
                  /* RadioListTile<MessageType>(value: MessageType.interpolated,
                  title: const Text("Animation"),
                  groupValue: _messageType,
                  onChanged: (value) => {setState((){ _messageType = value!; })}), */
                  if (_messageType == MessageType.brightness) ...[
                    Text("Helligkeit bestimmen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    Column(
                      children: [
                        Slider(
                          max: 100,
                          onChangeEnd: (d) => {
                            setState(() {
                              _currentBrightness = d;
                            }),
                          },
                          onChanged: (d) => {
                            setState(() {
                              _currentBrightness = d;
                            }),
                          },
                          value: _currentBrightness,
                        ),
                        Text(
                          "${_currentBrightness.toInt()}%",
                          style: const TextStyle(fontSize: 32),
                        )
                      ],
                    )
                  ] else if (_messageType == MessageType.color) ...[
                    Text("Farbe auswählen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    ColorsWidget(
                      startColor: _currentColor,
                      onChanged: (c) => {
                        setState(() {
                          _currentColor = c;
                        })
                      },
                    )
                  ] else if (_messageType == MessageType.interpolated) ...[
                    Text("Animation aus Liste auswählen".toUpperCase(),
                        style: Theme.of(context).textTheme.overline),
                    // Persistence
                    //DropdownButton<String>(items: _animationStore.map((e) => DropdownMenuItem(child: Text(e.title))).toList(), onChanged: (i) => {})
                  ]
                ],
              ),
              actions: [
                TextButton(
                    child: const Text("Abbrechen"),
                    onPressed: () => {Navigator.pop(context)}),
                TextButton(
                    child: const Text("Ändern"),
                    onPressed: () {
                      setState(() {
                        // TODO: Implement factory pattern
                        IBluetoothMessage? message;
                        if (_messageType == MessageType.color) {
                          message = ColorMessage.fromColor(_currentColor);
                        } else if (_messageType == MessageType.brightness) {
                          message =
                              BrightnessMessage(_currentBrightness.toInt());
                        }
                        if (message == null) {
                          return;
                        }
                        m.onUpdateMessage?.call(message);
                      });
                      Future.delayed(Duration.zero, () => {refresh()});
                      refresh();
                      Navigator.pop(context);
                    })
              ],
            );
          });
        });
  }

  void refresh() {
    setState(() {});
  }
}
