################################################################################
#
# Lockheed1049h Utility Functions
#
# Copyright (c) 2015 Richard Senior
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
################################################################################

# Get the current position of the aircraft as a geo.Coord object
#
var current_position = func()
{
    var lat = getprop("position/latitude-deg");
    var lon = getprop("position/longitude-deg");
    return geo.Coord.new().set_latlon(lat, lon);
}

# Get the distance to the nearest runway in metres
#
var distance_to_nearest_runway = func(from)
{
    var airport = airportinfo();
    var distance = 99999;

    foreach (var runway; values(airport.runways)) {
        var r = geo.Coord.new().set_latlon(runway.lat, runway.lon);
        var d = from.distance_to(r);
        if (d < distance) distance = d;
    }
    return distance;
}

# Check if the aircraft is near a runway threshold
#
var is_near_runway = func()
{
    return distance_to_nearest_runway(from:current_position()) < 50.0;
}

# Show the fuel and payload dialog. Does not display the dialog if
# automated checklists are running
#
var show_weight_dialog = func()
{
    var auto = getprop("sim/checklists/auto/active") or 0;
    if (!auto) gui.showWeightDialog();
}

# Helper function to start the selected engine from a checklist binding. If
# the binding is being run using expedited checklists, starts the engine
# directly, otherwise uses the engine starter switch
#
var start_selected_engine = func()
{
    var expedited = getprop("sim/checklists/auto/expedited") or 0;
    var auto = getprop("sim/checklists/auto/active") or 0;
    var starter = nil;

    if (auto and expedited) {
        var selected = getprop("controls/switches/engine-start-select");
        var engines = props.globals.getNode("controls/engines");
        starter = engines.getChild("engine", selected - 1).getNode("starter");
    } else {
        starter = props.globals.getNode("controls/switches/engine-start");
    }

    starter.setValue(1);

    # Hold duration must be less than automated checklist wait time (3.0s),
    # otherwise engine starts interfere with each other
    var t = maketimer(2.5, func {
        starter.setValue(0);
    });
    t.singleShot = 1;
    t.start();
}

