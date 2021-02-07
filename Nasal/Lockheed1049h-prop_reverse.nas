# Lockheed 1049H
#
# Propeller thrust reverser support functions
#
# Gary Neely aka 'Buckaroo'
#
# Special thanks to Wolfram Gottfried 'Yakko' for locating the relevant reverser properties.
# Special thanks to 'Tuxklok' for pointing out that the original reverser code didn't work
# well with joystick programmed reverse commands, and for suggesting the code solutions largely
# adopted below.

var PITCH_ANGLE_RAD	= -2;						# 3.1416 would be straight back,
									# but gives too much reverse thrust
var proprev_enable	= props.globals.getNode("/controls/engines/reverser_allow");
var proprev_controls	= props.globals.getNode("/controls/engines").getChildren("engine");
var proprev_fdm		= props.globals.getNode("/fdm/jsbsim/propulsion").getChildren("engine");


# Function for toggling the prop-reverse lockout lever on the Connie's center pedestal.
# If the lockout is engaged, we also disengage all reversed engines.
# Note that the reverser props on the engines are no longer really
# necessary. The 3D model for the lockout lever's position keys on the reverser_allow
# property, but it formerly keyed on the reverser property on engine[0].

toggle_reverse_lockout = func {
  if (!proprev_enable.getValue()) {					# Disabled, toggle to enable
    proprev_enable.setValue(1);
  }
  else {								# Enabled, toggle to disabled
    proprev_enable.setValue(0);
    for(var eng=0; eng<4; eng+=1) {					# Foreach engine:
      proprev_controls[eng].getNode("reverser").setValue(0);		# Reverser controls to off
      proprev_fdm[eng].getNode("pitch-angle-rad").setValue(0);		# Disable reverser
    }
  }
}


# Function for toggling prop-reversing on the Connie's engines.
# Reversing cannot occur if the lockout lever is not pulled down
# to allow reversing.

toggle_prop_reverse = func {
  if (!proprev_enable.getValue()) { return; }				# Can't toggle reverse if locked out
  if (!proprev_controls[0].getNode("reverser").getValue()) {		# Using eng 1 as master, if off
    for(var eng=0; eng<size(proprev_controls); eng+=1) {		# Foreach engine:
      proprev_controls[eng].getNode("reverser").setValue(1);		# Toggle reverser controls to on
    }
  }
  else {
    for(var eng=0; eng<4; eng+=1) {					# Foreach engine:
      proprev_controls[eng].getNode("reverser").setValue(0);		# Toggle reverser controls to off
    }
  }
}


# Listener-called function for setting the FDM's engine reverse property
# based on changes to the engine's reverser control setting.

set_prop_reverse = func(engine, value) {
  if (!proprev_enable.getValue()) {					# Cannot set reverse if locked out
    proprev_controls[engine].getNode("reverser").setValue(0);		# Make sure reverse control is off to prevent cockpit animations
    return;
  }
  #proprev_controls[engine].getNode("reverser").setValue(value);	# Not sure if necessary-- should already be set
  proprev_fdm[engine].getNode("pitch-angle-rad").setValue(value?PITCH_ANGLE_RAD:0);
}


setlistener("controls/engines/engine[0]/reverser",
  func(n) { set_prop_reverse(0, n.getValue()); }
);
setlistener("controls/engines/engine[1]/reverser",
  func(n) { set_prop_reverse(1, n.getValue()); }
);
setlistener("controls/engines/engine[2]/reverser",
  func(n) { set_prop_reverse(2, n.getValue()); }
);
setlistener("controls/engines/engine[3]/reverser",
  func(n) { set_prop_reverse(3, n.getValue()); }
);

