# Lockheed 1049H
#
# Custom 1049H routines for engine support
#
# Copyright (c) 2011 Gary Neely aka 'Buckaroo'
# Copyright (c) 2015 Ludovic Brenta
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# These vars declared in electrical.nas:
# MIN_VOLTS, bus_dc

# Set the starter on a given engine on or off but only on if it has power.
#
var set_engine_starter = func(engine, on)
{
    var engines = props.globals.getNode("controls/engines");
    var starter = engines.getChild("engine", engine).getNode("starter");
    var powered = bus_dc.getNode("volts").getValue() >= MIN_VOLTS;

    starter.setValue(on and powered);
}

# Set the state of the engine starter on the selected engine in response to
# changes to the engine starter switch.
#
var engine_start_listener = func(engine_start)
{
    var selected = getprop("controls/switches/engine-start-select");

    if (selected > 0) {
        set_engine_starter(selected - 1, engine_start.getValue());
    }
}

# Ensure starters on unselected engines are turned off when the starter select
# dial changes. Disabled for automated checklist starts because multiple
# starters may fire during expedited (in-air) starts.
#
var engine_select_listener = func(engine_start_select)
{
    var auto = getprop("sim/checklists/auto/active") or 0;
    if (auto) return;

    var engine_start = getprop("controls/switches/engine-start");

    for (var s = 1; s <= 4; s += 1) {
        var selected = (s == engine_start_select.getValue());
        set_engine_starter(s - 1, selected and engine_start);
    }
}

# Adjust the cooling factor of each engine as cowl flaps are opened or closed.

var adjust_cooling_factor = func (cowl_flaps_node) {
   var engine_number = cowl_flaps_node.getParent ().getIndex ();
   setprop ("/fdm/jsbsim/propulsion/engine[" ~ engine_number ~ "]/cooling-factor",
            0.4 + 0.15 * cowl_flaps_node.getValue ());
}

var cowl_flaps_listeners = [ 0, 0, 0, 0 ]; # prevents re-registering listeners on Shift+Esc

setlistener ("/sim/signals/fdm-initialized", func {

   # Listen for changes to cowl flap settings
   for (var engine = 0; engine < 4; engine = engine + 1) {
      if (cowl_flaps_listeners [engine] == 0) {
         cowl_flaps_listeners [engine] =
           setlistener ("/controls/engines/engine[" ~ engine ~ "]/cowl-flaps-norm",
                        adjust_cooling_factor, 1, 0);
      }
      else {
         print ("FDM reinitialized; not re-registering cowl flap listeners.");
      }
   }

   # Listen for changes to engine start switch
   setlistener("controls/switches/engine-start",
       engine_start_listener, 0, 0
   );

   # Listen for changes to engine start select switch
   setlistener("controls/switches/engine-start-select",
       engine_select_listener, 0, 0
   );

}, 0, 0);
