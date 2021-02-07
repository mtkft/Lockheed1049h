# Lockheed 1049H Constellation
#
# Instrumentation and Related Drivers
#
# Code by Gary Neely aka 'Buckaroo' except as otherwise noted
#
# Switch throw animation support
# Support for nav freq decimal digits
#

#
# A little setup for simulating short switch throws:
#
var switch_ani = func(i,j) {
  setprop("/systems/switch-throw["~i~"]/value",j);
  # Switch resets after 0.5 secs
  settimer(func { setprop("/systems/switch-throw["~i~"]/value",0); },
           0.5);
}

#
# Round-off errors screw-up the textranslate animation used to display digits. This is a problem
# for the NAV and COMM freq display. This seems to affect only decimal place digits. So here I'm using
# a listener to copy the MHz and KHz portions of a freq string to a separate integer values
# that are used by the animations.
#

var nav1selstr	= props.globals.getNode("/instrumentation/nav[0]/frequencies/selected-mhz-fmt");
var nav1selmhz	= props.globals.getNode("/instrumentation/nav[0]/frequencies/display-sel-mhz");
var nav1selkhz	= props.globals.getNode("/instrumentation/nav[0]/frequencies/display-sel-khz");
var nav2selstr	= props.globals.getNode("/instrumentation/nav[1]/frequencies/selected-mhz-fmt");
var nav2selmhz	= props.globals.getNode("/instrumentation/nav[1]/frequencies/display-sel-mhz");
var nav2selkhz	= props.globals.getNode("/instrumentation/nav[1]/frequencies/display-sel-khz");
var nav1sbystr	= props.globals.getNode("/instrumentation/nav[0]/frequencies/standby-mhz-fmt");
var nav1sbymhz	= props.globals.getNode("/instrumentation/nav[0]/frequencies/display-sby-mhz");
var nav1sbykhz	= props.globals.getNode("/instrumentation/nav[0]/frequencies/display-sby-khz");
var nav2sbystr	= props.globals.getNode("/instrumentation/nav[1]/frequencies/standby-mhz-fmt");
var nav2sbymhz	= props.globals.getNode("/instrumentation/nav[1]/frequencies/display-sby-mhz");
var nav2sbykhz	= props.globals.getNode("/instrumentation/nav[1]/frequencies/display-sby-khz");

							# This initializes the values
var navtemp = split(".",nav1selstr.getValue());
nav1selmhz.setValue(navtemp[0]);
nav1selkhz.setValue(navtemp[1]);
navtemp = split(".",nav2selstr.getValue());
nav2selmhz.setValue(navtemp[0]);
nav2selkhz.setValue(navtemp[1]);
navtemp = split(".",nav1sbystr.getValue());
nav1sbymhz.setValue(navtemp[0]);
nav1sbykhz.setValue(navtemp[1]);
navtemp = split(".",nav2sbystr.getValue());
nav2sbymhz.setValue(navtemp[0]);
nav2sbykhz.setValue(navtemp[1]);
							# And these make sure they're updated
setlistener(nav1selstr, func {
  var navtemp = split(".",nav1selstr.getValue());
  nav1selmhz.setValue(navtemp[0]);
  nav1selkhz.setValue(navtemp[1]);
});
setlistener(nav2selstr, func {
  var navtemp = split(".",nav2selstr.getValue());
  nav2selmhz.setValue(navtemp[0]);
  nav2selkhz.setValue(navtemp[1]);
});
setlistener(nav1sbystr, func {
  var navtemp = split(".",nav1sbystr.getValue());
  nav1sbymhz.setValue(navtemp[0]);
  nav1sbykhz.setValue(navtemp[1]);
});
setlistener(nav2sbystr, func {
  var navtemp = split(".",nav2sbystr.getValue());
  nav2sbymhz.setValue(navtemp[0]);
  nav2sbykhz.setValue(navtemp[1]);
});


var comm1sel	= props.globals.getNode("/instrumentation/comm[0]/frequencies/selected-mhz");
var comm1sby	= props.globals.getNode("/instrumentation/comm[0]/frequencies/standby-mhz");
var comm1selstr	= props.globals.getNode("/instrumentation/comm[0]/frequencies/selected-mhz-fmt");
var comm1sbystr	= props.globals.getNode("/instrumentation/comm[0]/frequencies/standby-mhz-fmt");
var comm1selmhz= props.globals.getNode("/instrumentation/comm[0]/frequencies/display-sel-mhz");
var comm1selkhz= props.globals.getNode("/instrumentation/comm[0]/frequencies/display-sel-khz");
var comm1sbymhz= props.globals.getNode("/instrumentation/comm[0]/frequencies/display-sby-mhz");
var comm1sbykhz= props.globals.getNode("/instrumentation/comm[0]/frequencies/display-sby-khz");

var comm2sel	= props.globals.getNode("/instrumentation/comm[1]/frequencies/selected-mhz");
var comm2sby	= props.globals.getNode("/instrumentation/comm[1]/frequencies/standby-mhz");
var comm2selstr	= props.globals.getNode("/instrumentation/comm[1]/frequencies/selected-mhz-fmt");
var comm2sbystr	= props.globals.getNode("/instrumentation/comm[1]/frequencies/standby-mhz-fmt");
var comm2selmhz= props.globals.getNode("/instrumentation/comm[1]/frequencies/display-sel-mhz");
var comm2selkhz= props.globals.getNode("/instrumentation/comm[1]/frequencies/display-sel-khz");
var comm2sbymhz= props.globals.getNode("/instrumentation/comm[1]/frequencies/display-sby-mhz");
var comm2sbykhz= props.globals.getNode("/instrumentation/comm[1]/frequencies/display-sby-khz");

							# Update support vars on comm change
setlistener(comm1sel, func {
  var commstr = sprintf("%.2f",comm1sel.getValue());	# String conversion
  var commtemp = split(".",commstr);			# Split into MHz and KHz
  comm1selmhz.setValue(commtemp[0]);
  comm1selkhz.setValue(commtemp[1]);
});
setlistener(comm1sby, func {
  var commstr = sprintf("%.2f",comm1sby.getValue());
  var commtemp = split(".",commstr);
  comm1sbymhz.setValue(commtemp[0]);
  comm1sbykhz.setValue(commtemp[1]);
});
setlistener(comm2sel, func {
  var commstr = sprintf("%.2f",comm2sel.getValue());
  var commtemp = split(".",commstr);
  comm2selmhz.setValue(commtemp[0]);
  comm2selkhz.setValue(commtemp[1]);
});
setlistener(comm2sby, func {
  var commstr = sprintf("%.2f",comm2sby.getValue());
  var commtemp = split(".",commstr);
  comm2sbymhz.setValue(commtemp[0]);
  comm2sbykhz.setValue(commtemp[1]);
});

							# Set comm support vars to startups
var update_comms = maketimer (2.0, func {
  var commstr = "";
  var commtemp = 0;

  commstr = sprintf("%.2f",comm1sel.getValue());
  commtemp = split(".",commstr);
  comm1selmhz.setValue(commtemp[0]);
  comm1selkhz.setValue(commtemp[1]);
  commstr = sprintf("%.2f",comm1sby.getValue());
  commtemp = split(".",commstr);
  comm1sbymhz.setValue(commtemp[0]);
  comm1sbykhz.setValue(commtemp[1]);

  commstr = sprintf("%.2f",comm2sel.getValue());
  commtemp = split(".",commstr);
  comm2selmhz.setValue(commtemp[0]);
  comm2selkhz.setValue(commtemp[1]);
  commstr = sprintf("%.2f",comm2sby.getValue());
  commtemp = split(".",commstr);
  comm2sbymhz.setValue(commtemp[0]);
  comm2sbykhz.setValue(commtemp[1]);
});


var InstrumentationInit = func {
  settimer (func () { update_comms.start(); }, 2.0); # delay the starting up
}
