# Lockheed 1049H
#
# Custom 1049H routines for lighting support
#
# Gary Neely aka 'Buckaroo'


# Initialize timed beacon (anti-collision) lighting
aircraft.light.new("controls/lighting/beacon", [0.2, 2]);
# This creates two boolean properties, controls/lighting/beacon/{enabled,state} which
# we will send over multiplayer in Lockheed1049h.nas.

# the fire-warning blink
var fire_prop = func(){
  var fw = props.globals.getNode("/controls/special/fire-warning", 1);
  if(fw.getValue() == 1){
  		fw.setValue(0);
  }else{
  		fw.setValue(1);
  }
  settimer(fire_prop, 0.5);
}

fire_prop();

# Ordinance Signs

var command_bell = "controls/switches/command-bell";
var no_smoking = "controls/switches/no-smoking-signs";
var seat_belts = "controls/switches/seat-belt-signs";

var ring_command_bell = func 
{
    setprop(command_bell, 1);
    settimer(func {setprop(command_bell, 0);}, 1.0);
}

setlistener(no_smoking, func {
    ring_command_bell();
}, startup = 0, runtime = 0);

setlistener(seat_belts, func {
    ring_command_bell();
}, startup = 0, runtime = 0);

