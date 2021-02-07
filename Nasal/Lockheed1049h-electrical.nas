# Lockheed 1049H
#
# Custom 1049H routines for electrical support
#
# Gary Neely aka 'Buckaroo'
#
#
# This system provides support for the DC bus, though the system currently exists to animate the MJB
# panels more than anything else. AC power is provided via inverters to sub-systems that require it,
# but currently I don't simulate AC power.
#
# There are 7 possible feeds for the DC bus: 4 engine generators, the auxilliary power unit, the
# aircraft batteries, and the external/cart power. External power is available only when the
# aircraft is on the ground and not moving. Battery power is virtually inexhaustable as I currently
# don't have data on what amps various systems draw and therefore a true drain/charge system isn't
# feasible. Until more data is available, all voltages and currents are typical for their functions.
#
# Note that power sources show volts only if their generator sources are switched on. In reality, the
# source may show volts even if not switched on, as switched on may mean only that it is connected to
# the power bus. For example, the ship's batteries might show volts even if not tied to the main bus.
# I'm not sure which situation is true, but showing no volts when switched off provides better feedback
# to users so I am going with that for the moment. For example, the batteries must be tied to the bus
# (switched on) before battery volts will display on the voltmeter.

var STD_VOLTS	= 24.0;							# Typical volts for a power source
var MIN_VOLTS	= 23.5;							# Typical minimum voltage level for generic equipment
var STD_AMPS	= 350;							# Typical amps for a power source
									# Handy handles for DC source feed indices
var feed	= {	eng1	: 0,
			eng2	: 1,
			eng3	: 2,
			eng4	: 3,
			apu	: 4,
			batt	: 5,
			cart	: 6
		  };
var feed_sw	= [0,0,0,0,0,0,0];					# For fast feed switch checking

									# Other property handles:
var engines	= props.globals.getNode("/engines").getChildren("engine");
var sources	= props.globals.getNode("/systems/electrical").getChildren("power-source");
var sw_gen	= props.globals.getNode("/controls/switches").getChildren("generator");
var sw_apu	= props.globals.getNode("/controls/switches/gen-apu");
var sw_batt	= props.globals.getNode("/controls/switches/battery-ship");
var sw_cart	= props.globals.getNode("/controls/switches/battery-cart");
var cart_wow	= props.globals.getNode("/gear/gear[0]/wow");
var gndspd	= props.globals.getNode("velocities/groundspeed-kt",1);
var cart_lamp	= props.globals.getNode("/systems/electrical/battery-cart-lamp");
var test_volts	= props.globals.getNode("/systems/electrical/test-volts-dc");
var bus_dc	= props.globals.getNode("/systems/electrical/bus-dc");

#
# DC Voltmeter selector support
# The 1049's had a built-in voltmeter for sampling the various source voltages. This system
# does the same thing, allows various feed volts to be tested.
#
									# DC selector to source mappings
var sel_source		= {	0 : -2,					# off
				1 : -1,					# bus
				2 : 5,					# batt
				3 : 0,					# gen 1
				4 : 1,					# gen 2
				5 : 2,					# gen 3
				6 : 3,					# gen 4
				7 : 4,					# apu
				8 : -1					# bus
		  	  };
									# The selector switch knob position:
var sw_volts_sel_dc	= props.globals.getNode("/controls/switches/volts-select-dc");

									# Advance dc volts selector knob
									# to next setting using sequence map:
#
# Primary electrical system support:
#

									# If an engine is running and the generator switch
									# is on, simulate power available on that source by
									# setting its volts and amps to usable values
var update_generators = func {
  for(var i=0; i<size(engines); i+=1) {
    feed_sw[i] = sw_gen[i].getValue();
    if (engines[i].getNode("running").getValue() and
        feed_sw[i]) {
      sources[i].getNode("volts").setValue(STD_VOLTS);
      sources[i].getNode("amps").setValue(STD_AMPS);
    }
    else {
      sources[i].getNode("volts").setValue(0);
      sources[i].getNode("amps").setValue(0);
    }
  }
}

var update_apu = func {
  feed_sw[feed["apu"]] = sw_apu.getValue();
  if (sw_apu.getValue()) {
    sources[feed["apu"]].getNode("volts").setValue(STD_VOLTS);
    sources[feed["apu"]].getNode("amps").setValue(STD_AMPS);
  }
  else {
    sources[feed["apu"]].getNode("volts").setValue(0);
    sources[feed["apu"]].getNode("amps").setValue(0);
  }
}

var update_battery = func {
  feed_sw[feed["batt"]] = sw_batt.getValue();
  if (sw_batt.getValue()) {
    sources[feed["batt"]].getNode("volts").setValue(STD_VOLTS);
    sources[feed["batt"]].getNode("amps").setValue(STD_AMPS);
  }
  else {
    sources[feed["batt"]].getNode("volts").setValue(0);
    sources[feed["batt"]].getNode("amps").setValue(0);
  }
}
									# External power is available only if
									# aircraft is on the ground and stopped
var update_cart = func {
  feed_sw[feed["cart"]] = sw_cart.getValue();
  if (sw_cart.getValue() and
      cart_wow.getValue() and
      gndspd.getValue() < 0.1) {
    sources[feed["cart"]].getNode("volts").setValue(STD_VOLTS);
    sources[feed["cart"]].getNode("amps").setValue(STD_AMPS);
    cart_lamp.setValue(1);
  }
  else {
    sw_cart.setValue(0);
    sources[feed["cart"]].getNode("volts").setValue(0);
    sources[feed["cart"]].getNode("amps").setValue(0);
    cart_lamp.setValue(0);
  }
}
									# Update the source the voltmeter is reporting--
									# Will be 0, or bus volts, or a source voltage
var update_voltmeter = func {
  var source = sel_source[sw_volts_sel_dc.getValue()];
  if (source == -2) {							# Voltmeter is off
    test_volts.setValue(0);
    return 0;
  }
  if (source == -1) {							# Voltmeter set to bus
    test_volts.setValue(bus_dc.getNode("volts").getValue());
    return 0;
  }
  test_volts.setValue(sources[source].getNode("volts").getValue());	# Voltmeter set to some source
}

var update_bus_feeds = func {
  var volts = 0;							# Assume no volts on bus
  for(var i=0; i<size(feed_sw); i+=1) {					# Check all possible feeds
    if (feed_sw[i]) {							# If feed is on
      var source_volts = sources[i].getNode("volts").getValue();
      if (source_volts > volts) {					# Volts takes on largest source value
        volts = source_volts;
      }
    }
  }
  bus_dc.getNode("volts").setValue(volts);				# Bus takes on largest source value
}


									# The master bus update system
var update_bus = maketimer (1.0, func {
  update_generators();
  update_apu();
  update_battery();
  update_cart();
  update_bus_feeds();
  update_voltmeter();
  #var mpvolts = bus_dc.getNode("volts").getValue();
  #if (mpvolts > 0) { mpvolts = mpvolts / 100; }
});

#
# Initialize electrical system
# Update every 1 seconds
#

var electrical_update_init = func {
									# Currently no initialization required
  update_bus.start();
}

settimer(electrical_update_init,2);
