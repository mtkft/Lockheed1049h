# Lockheed 1049H Constellation
#
# Initialization routines
#	fire up the fuel system
#	set up autopilot (deprecated)
#	set up menu dialogs
#
# Gary Neely aka 'Buckaroo'


LockheedMain = {};

LockheedMain.new = func {
  obj = { parents : [LockheedMain]
        };
  obj.init();
  return obj;
}

								# Determines values carried between sessions
LockheedMain.savedata = func {
  aircraft.data.add("/sim/presets/fuel");			# User's default fuel load selection
  aircraft.data.add("/systems/seat/presets/z-offset-m");	# User's pilot seat view selections
  aircraft.data.add("/systems/seat/presets/y-offset-m");
  aircraft.data.add("/systems/seat/presets/pitch-offset-deg");
  aircraft.data.add("/systems/fuel/tanks/request-fuel-lbs");
  aircraft.data.add("/sim/model/options/hide-dice");
  aircraft.data.add("/sim/model/options/hide-yokes");
  aircraft.data.add("/sim/model/options/refuel-error-pct");
  aircraft.data.add("/sim/model/options/show-heading-bug");
  #aircraft.data.add("/sim/current-view/z-offset-m");
  #aircraft.data.add("/sim/current-view/y-offset-m");
  #aircraft.data.add("/sim/current-view/pitch-offset-deg");
}


# global variables in Lockheed1049h namespace, for call by XML
LockheedMain.instantiate = func {
   #globals.Lockheed1049h.autopilotsystem = Autopilot.new();
   globals.Lockheed1049h.menusystem = Menu.new();
}

LockheedMain.init = func {
   me.instantiate();
   aircraft.livery.init("Models/Liveries");
   InstrumentationInit();					# See Lockheed1049h_instrumentation_drivers.nas
   me.savedata();  						# Initiate save on exit, restore on launch stuff
}


L1049hL = setlistener("/sim/signals/fdm-initialized", func {
  theconstellation = LockheedMain.new();
  removelistener(L1049hL);
  }
);

# Pack multiple booleans into a single property for transmission over the multiplayer
# protocol.  The decoder corresponding to this encoder is in the <nasal><load> tag
# of the model and runs in aircraft that see a remote Lockheed1049h.  For ease of
# maintenance the properties are in alphabetical order.  All are booleans.
var encoder = dual_control_tools.SwitchEncoder.new (
[
  props.globals.getNode ("/controls/fuel/jettison[0]/spray"),
  props.globals.getNode ("/controls/fuel/jettison[1]/spray"),
  props.globals.getNode ("/controls/lighting/beacon/enabled"),
  props.globals.getNode ("/controls/lighting/beacon/state"),
  props.globals.getNode ("/controls/lighting/landing-extend-left"),
  props.globals.getNode ("/controls/lighting/landing-extend-right"),
  props.globals.getNode ("/controls/lighting/landing-left"),
  props.globals.getNode ("/controls/lighting/landing-right"),
  props.globals.getNode ("/controls/lighting/nav"),
  props.globals.getNode ("/controls/lighting/tail"),
  props.globals.getNode ("/controls/lighting/taxi"),
  props.globals.getNode ("/engines/engine[0]/running"),
  props.globals.getNode ("/engines/engine[1]/running"),
  props.globals.getNode ("/engines/engine[2]/running"),
  props.globals.getNode ("/engines/engine[3]/running"),
  props.globals.getNode ("/hazards/fire/engine[0]"),
  props.globals.getNode ("/hazards/fire/engine[1]"),
  props.globals.getNode ("/hazards/fire/engine[2]"),
  props.globals.getNode ("/hazards/fire/engine[3]"),
],
props.globals.getNode ("/sim/multiplay/generic/int[1]", 1));

var multiplayer_send_loop = maketimer (0.1, func () {
  encoder.update ();
});
multiplayer_send_loop.start();

setlistener("/sim/signals/fdm-initialized", func {
  var initstate = getprop("/sim/aircraft-state");
  if (initstate == "parking")  autochecklist.complete_checklists("terminal-start", 0);
  if (initstate == "taxi")  autochecklist.complete_checklists("runway-start", 0);
  if (initstate == "take-off")  autochecklist.complete_checklists("runway-start", 0);
  if (initstate == "cruise")  autochecklist.complete_checklists("in-air-start", 0);
  if (initstate == "approach")  autochecklist.complete_checklists("approach", 0);
});
