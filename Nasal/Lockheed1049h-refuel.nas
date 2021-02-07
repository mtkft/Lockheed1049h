################################################################################
#
# Lockheed1049h Refuelling
#
# Copyright (c) 2015, Richard Senior
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

################################################################################
# GLOBALS
################################################################################

var fuel = props.globals.getNode("consumables/fuel");

# Fuel tank arrangement
var line01 = fuel.getChild("tank", 0);  # Fuel line 1
var line02 = fuel.getChild("tank", 1);  # Fuel line 2
var line03 = fuel.getChild("tank", 2);  # Fuel line 3
var line04 = fuel.getChild("tank", 3);  # Fuel line 4

var tank01 = fuel.getChild("tank", 4);  # Middle wing
var tank02 = fuel.getChild("tank", 5);  # Inner wing
var tank03 = fuel.getChild("tank", 6);  # Inner wing
var tank04 = fuel.getChild("tank", 7);  # Middle wing
var tank05 = fuel.getChild("tank", 8);  # Center
var tank2B = fuel.getChild("tank", 9);  # Unused (not fitted on 1049h)
var tank2A = fuel.getChild("tank", 10); # Outer wing
var tank3A = fuel.getChild("tank", 11); # Outer wing
var tank3B = fuel.getChild("tank", 12); # Unused (not fitted on 1049h)

# Capacities
var cap01 = tank01.getChild("capacity-gal_us").getValue();
var cap02 = tank02.getChild("capacity-gal_us").getValue();
var cap03 = tank03.getChild("capacity-gal_us").getValue();
var cap04 = tank04.getChild("capacity-gal_us").getValue();
var cap05 = tank05.getChild("capacity-gal_us").getValue();
var cap2B = tank2B.getChild("capacity-gal_us").getValue();
var cap2A = tank2A.getChild("capacity-gal_us").getValue();
var cap3A = tank3A.getChild("capacity-gal_us").getValue();
var cap3B = tank3B.getChild("capacity-gal_us").getValue();

# Refuelling phases (refer to crew operations manual, p202)
var phase1 = 2 * (cap2A + cap3A);
var phase2 = phase1 + 2 * (cap02 + cap03);
var phase3 = phase2 + (cap01 - (cap02 + cap2A) + cap04 - (cap03 + cap3A));
var phase4 = phase3 + cap05;

# Pounds to US gallons conversion
var USG2LB = 6.0;

# Total fuel capacity
var MAX_FUEL_USG = cap01 + cap02 + cap03 + cap04 + cap05 + cap2A + cap3A;

################################################################################
# HELPERS
################################################################################

# Cap a value to a limit
#
# @param vaue the value to cap
# @param limit the value to limit to
#
var cap = func(value, limit)
{
    return value > limit ? limit : value;
}

# Calculate a value of x from y along a line from (x1, y1) to (x2, y2)
#
# @param y the y value, capped to y2
# @param x1 the x value starting the line
# @param x2 the x value ending the line
# @param y1 the y value starting the line
# @param y2 the y value ending the line
#
var slope = func(y, x1, x2, y1, y2)
{
    var dx = x2 - x1;
    var dy = y2 - y1;
    return (cap(y, y2) - y1) * dx / dy;
}

# Calculate the dry weight of the aircraft, i.e. empty weight + pointmasses
#
var dry_weight_lbs = func()
{
    var empty_weight_lbs = getprop("fdm/jsbsim/inertia/empty-weight-lbs");

    var payload_weight_lbs = 0.0;
    var payload = props.globals.getNode("fdm/jsbsim/inertia");
    foreach (var pointmass; payload.getChildren("pointmass-weight-lbs")) {
        payload_weight_lbs += pointmass.getValue() or 0.0;
    }

    return int(empty_weight_lbs + payload_weight_lbs);
}

################################################################################
# API FUNCTIONS
################################################################################

# Request fuel quantity in US gallons
#
# This function allocates fuel to each tank according to the
# recommended operational fuel loading chart for the 1049h.
#
# Phase1: Fill 1/2A/3A/4 until 2A and 3A are full
# Phase2: Fill 1/2/3/4 until 2 and 3 are full
# Phase3: Fill 1/4 until 1 and 4 are full
# Phase1: Fill 5 until 5 is full (center tank)
#
# @param usg the fuel required in US gallons
# @see Lockheed Super Constellation Crew Operating Manual, p202
#
var request_fuel_quantity_usg = func(usg)
{
    usg = cap(usg, MAX_FUEL_USG);

    # Calculate the fuel quantities according to the operations manual,
    # assuming that corresponding tanks are equal volumes, e.g. 2A == 3A.
    if (usg <= phase1) {
        # Fill 1/2A/3A/4 until 2A/3A are full
        aux = slope(usg, 0.0, cap2A, 0.0, phase1);
        mid = 0.0;
        inr = slope(usg, 0.0, cap2A, 0.0, phase1);
        ctr = 0.0;
    } elsif (usg <= phase2) {
        # Fill 1/2/3/4 until 2/3 are full
        aux = cap2A;
        mid = slope(usg, 0.0, cap02, phase1, phase2);
        inr = slope(usg, 0.0, cap02 + cap2A, 0.0, phase2);
        ctr = 0.0;
    } elsif (usg <= phase3) {
        # Fill 1/4 until 1/4 are full
        aux = cap2A;
        mid = cap02;
        in1 = slope(usg, 0.0, cap02 + cap2A, 0.0, phase2);
        in2 = slope(usg, cap02 + cap2A, cap01, phase2, phase3);
        inr = in1 + in2;
        ctr = 0.0;
    } else {
        # Fill 5 (center tank) until 5 is full. Max capacity.
        aux = cap2A;
        mid = cap02;
        inr = cap01;
        ctr = slope(usg, 0.0, cap05, phase3, phase4);
    }

    # Empty the fuel lines
    line01.getChild("level-gal_us").setValue(0.0);
    line02.getChild("level-gal_us").setValue(0.0);
    line03.getChild("level-gal_us").setValue(0.0);
    line04.getChild("level-gal_us").setValue(0.0);

    # Set the fuel quantities in the tanks (no interpolation)
    tank01.getChild("level-gal_us").setValue(inr);
    tank02.getChild("level-gal_us").setValue(mid);
    tank03.getChild("level-gal_us").setValue(mid);
    tank04.getChild("level-gal_us").setValue(inr);
    tank05.getChild("level-gal_us").setValue(ctr);
    tank2B.getChild("level-gal_us").setValue(0.0);
    tank2A.getChild("level-gal_us").setValue(aux);
    tank3A.getChild("level-gal_us").setValue(aux);
    tank3B.getChild("level-gal_us").setValue(0.0);
}

# Request fuel quantity in pounds
#
# @param lbs the fuel required in pounds
#
var request_fuel_quantity_lbs = func(lbs)
{
    usg = cap(lbs / USG2LB, MAX_FUEL_USG);
    request_fuel_quantity_usg(usg);    
}

# Request fuel quantity up to max takeoff weight
#
var request_fuel_quantity_mtow = func()
{
    var mtow_lbs = getprop("limits/mass-and-balance/maximum-takeoff-mass-lbs");
    request_fuel_quantity_lbs(mtow_lbs - dry_weight_lbs());
}

# Request fuel quantity up to max landing weight
#
var request_fuel_quantity_mlw = func()
{
    var mlw_lbs = getprop("limits/mass-and-balance/maximum-landing-mass-lbs");
    request_fuel_quantity_lbs(mlw_lbs - dry_weight_lbs());
}

