# Lockheed 1049H
#
# Custom 1049H routines for seat support
#
# Gary Neely aka 'Buckaroo'
#


var current_z		= props.globals.getNode("/sim/current-view/z-offset-m");
var current_y		= props.globals.getNode("/sim/current-view/y-offset-m");
var current_pitch	= props.globals.getNode("/sim/current-view/pitch-offset-deg");

var default_z		= props.globals.getNode("/systems/seat/defaults/z-offset-m");
var default_y		= props.globals.getNode("/systems/seat/defaults/y-offset-m");
var default_pitch	= props.globals.getNode("/systems/seat/defaults/pitch-offset-deg");

var view_z		= props.globals.getNode("/sim/view/config/z-offset-m");
var view_y		= props.globals.getNode("/sim/view/config/y-offset-m");
var view_pitch		= props.globals.getNode("/sim/view/config/pitch-offset-deg");

var preset_z		= props.globals.getNode("/systems/seat/presets/z-offset-m");
var preset_y		= props.globals.getNode("/systems/seat/presets/y-offset-m");
var preset_pitch	= props.globals.getNode("/systems/seat/presets/pitch-offset-deg");

var enable_presets	= props.globals.getNode("/systems/seat/presets/enable-presets");

var seat_pilot_offset_z	= props.globals.getNode("/systems/seat/pilot-z-offset-m");


# Calculate offset for moving pilot's seat forward-back according to custom preferences;
#   current view settings - default view settings = offset along z (+x in Blender)
# The offset is used for a cockpit animation.

var seat_pilot_update = func {
  seat_pilot_offset_z.setValue(current_z.getValue()-default_z.getValue());
  preset_z.setValue(current_z.getValue());
  preset_y.setValue(current_y.getValue());
  preset_pitch.setValue(current_pitch.getValue());
}


# Reset viewing properties to aircraft configuration settings.

var seat_pilot_defaults = func {
  current_z.setValue(default_z.getValue());
  current_y.setValue(default_y.getValue());
  current_pitch.setValue(default_pitch.getValue());
  seat_pilot_offset_z.setValue(0);
}

#var seat_pilot_defaults = func {
#  current_view_z.setValue(default_view_z.getValue());
#  current_view_y.setValue(default_view_y.getValue());
#  current_view_pitch.setValue(default_view_pitch.getValue());
#  seat_pilot_offset_z.setValue(0);
#}


var seat_load_presets = func {
  view_z.setValue(preset_z.getValue());
  view_y.setValue(preset_y.getValue());
  view_pitch.setValue(preset_pitch.getValue());
}
