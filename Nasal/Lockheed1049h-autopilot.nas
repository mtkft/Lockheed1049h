################################################################################
#
# Autopilot Helper
#
# Copyright (c) 2015, Mark Kraus, Richard Senior
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

var _lock = 0;

var FlightPathMode = {OFF: 0, VOR: 1, LOC: 2, APP: 3};

################################################################################
# HELPERS
################################################################################

# Lock changes through listeners. If a function is wrapped in this lock
# function, listeners will not fire and cause an endless loop.
#
# @param f a function (func { ...})
#
var lock = func(f)
{
    if (_lock) return;
    _lock = 1;
    call(f);
    _lock = 0;
}

# Capture the current altitude into the autopilot target altitude
#
var capture_altitude = func()
{
    var a = math.round(getprop("instrumentation/altimeter/indicated-altitude-ft"));
    setprop("autopilot/settings/target-altitude-ft", a);
}

# Capture the current heading into the autopilot target heading
#
var capture_heading = func()
{
    var hi = "instrumentation/heading-indicator";
    var heading = getprop(hi, "indicated-heading-deg");
    setprop("autopilot/settings/heading-bug-deg", math.round(heading));
}

# Configure the vertical modes of the autopilot based on switch positions.
#
# When switching to altitude hold, captures the current altitude into the
# target altitude. Does not capture the current pitch when switching to
# pitch mode.
#
var configure_vertical_mode = func()
{
    if (getprop("autopilot/switches/ap")) {
        var fp = getprop("autopilot/settings/flight-path");
        if (fp == FlightPathMode.APP) {
            setprop ("autopilot/locks/altitude", "gs1-hold");
            capture_altitude();
        } else {
            if (getprop("autopilot/switches/alt")) {
                setprop("autopilot/locks/altitude", "altitude-hold");
                capture_altitude();
            } else {
                setprop("autopilot/locks/altitude", "pitch-hold");
            }
        }
    } else {
        setprop("autopilot/locks/altitude", "");
    }
}

# Configure the lateral modes of the autopilot based on switch positions.
#
# Apart from OFF, all other switch positions on the flight path selection
# dial require VOR mode (VHF, LOC and LOC/GS). In localizer modes, sets a
# new property to indicate localizer sensitivity that can be used by the
# autopilot controllers.
#
var configure_lateral_mode = func()
{
    if (getprop("autopilot/switches/ap")) {
        var fp = getprop("autopilot/settings/flight-path");
        if (fp == FlightPathMode.OFF) {
            setprop("autopilot/locks/heading", "wing-leveler");
        } else {
            setprop("autopilot/locks/heading", "nav1-hold");
        }
        var loc = (fp == FlightPathMode.LOC or fp == FlightPathMode.APP);
        setprop("autopilot/settings/localizer", loc);
    } else {
        setprop("autopilot/locks/heading", "");
    }
}

# Configure the speed modes of the autopilot based on switch positions.
#
# Speed modes are not supported by the cockpit autopilot controls but a pilot
# may use auto-throttle via the generic autopilot dialog. Any speed
# mode should be cleared when the autopilot is disconnected.
#
var configure_speed_mode = func()
{
    if (!getprop("autopilot/switches/ap")) {
        setprop("autopilot/locks/speed", "");
    }
}

# Convenience function to configure all autopilot modes
#
var configure_all_modes = func()
{
    configure_lateral_mode();
    configure_vertical_mode();
    configure_speed_mode();
}

# Infers the flight path setting based on autopilot locks changed through the
# generic autopilot dialog.
#
var infer_flight_path_setting = func()
{
    var lmode = getprop("autopilot/locks/heading");
    var vmode = getprop("autopilot/locks/altitude");

    if (lmode == "nav1-hold") {
        if (vmode == "gs1-hold") {
            setprop("autopilot/settings/flight-path", FlightPathMode.APP);
        } else {
            var gs = getprop("instrumentation/nav/gs-in-range");
            var fp = gs ? FlightPathMode.LOC : FlightPathMode.VOR;
            setprop("autopilot/settings/flight-path", fp);
        }
    } else {
        setprop("autopilot/settings/flight-path", FlightPathMode.OFF);
    }
}

# Helper to toggle the autopilot on off. Can be called from key shortcut or
# from a joystick/yoke button.
#
var toggle_autopilot_on_off = func()
{
    var ap = getprop("autopilot/switches/ap");
    var alt = getprop("autopilot/switches/alt");

    if (!ap and alt) {
        setprop("sim/messages/pilot",
            "Cannot engage autopilot when altitude switch is on"
        );
        return;
    }
    setprop("autopilot/switches/ap", !ap);
}

################################################################################
# LISTENERS
################################################################################

# Listeners for changes through the 3D cockpit

setlistener("/autopilot/switches/ap", func(ap) {
    lock(func {
        configure_all_modes();
    });
}, startup = 1, runtime = 0);

setlistener("autopilot/switches/alt", func(alt) {
    lock(func {
        configure_vertical_mode();
    });
}, startup = 1, runtime = 0);

setlistener("autopilot/settings/flight-path", func(node) {
    lock(func {
        configure_lateral_mode();
        configure_vertical_mode();
    });
}, startup = 1, runtime = 0);

setlistener("autopilot/internal/wing-leveler-heading-hold", func(node) {
    capture_heading();
}, startup = 0, runtime = 0);

# Listeners for changes through the dialog

setlistener("autopilot/locks/heading", func(node) {
    lock(func {
        infer_flight_path_setting();
        setprop("autopilot/switches/ap", node.getValue() != "");
    });
}, startup = 1, runtime = 0);

setlistener("autopilot/locks/altitude", func(node) {
    lock(func {
        infer_flight_path_setting();
        setprop("autopilot/switches/alt", node.getValue() == "altitude-hold");
        setprop("autopilot/switches/ap", node.getValue() != "");
    });
}, startup = 1, runtime = 0);

setlistener("autopilot/locks/speed", func(node) {
    lock(func {
        setprop("autopilot/switches/ap", node.getValue() != "");
    });
}, startup = 1, runtime = 0);

# Manage listeners and resets

setlistener("/sim/signals/reinit", func(status) {
    if (!status.getValue()) {
        setprop("autopilot/locks/altitude", "");
        setprop("autopilot/locks/heading", "");
        setprop("autopilot/locks/speed", "");
        setprop("autopilot/switches/ap", 0);
        setprop("autopilot/switches/alt", 0);
        setprop("autopilot/settings/flight-path", 0);
        setprop("autopilot/settings/target-bank-deg", 0);
        setprop("autopilot/settings/target-pitch-deg", 4.0);
        setprop("autopilot/internal/wing-leveler-heading-hold", 0);
    }
}, startup = 1, runtime = 0);

################################################################################
# ON SCREEN HELP
################################################################################

var help_win = screen.window.new(0, 0, 1, 5);
help_win.fg = [1, 1, 1, 1];

print("Help infosystem started");

var h_altimeter = func {
    var hg = getprop("instrumentation/altimeter/setting-inhg") or 0.0;
    var hp = getprop("instrumentation/altimeter/setting-hpa") or 0.0;
    help_win.write(sprintf("Altimeter: %.0f hpa %.2f inhg ", hp, hg));
}

var h_heading = func {
    var hd = getprop("autopilot/settings/heading-bug-deg") or 0.0;
    var mv = getprop("environment/magnetic-variation-deg") or 0;
    help_win.write(sprintf("Heading: %.0f, magnetic variation: %.0f", hd, mv));
}

var h_course = func {
    var r = getprop("instrumentation/nav[0]/radials/selected-deg") or 0;
    help_win.write(sprintf("Selected radial: %.0f ", r));
}

var h_course_two = func {
    var r = getprop("instrumentation/nav[1]/radials/selected-deg") or 0;
    help_win.write(sprintf("Selected radial: %.0f ", r));
}

var h_vs = func {
    var vs = getprop("autopilot/settings/vertical-speed-fpm") or 0.0;
    help_win.write(sprintf("Vertical speed: %.0f ", vs) );
}

var h_mis = func {
    var os = getprop("instrumentation/rmi/face-offset") or 0.0;
    help_win.write(sprintf("%.0f degrees", os));
}

var h_pitch = func {
    var p = getprop("autopilot/settings/target-pitch-deg") or 0.0;
    help_win.write(sprintf("Target pitch: %.1f degrees", p));
}

var h_bank = func {
    var b = getprop("autopilot/settings/target-bank-deg") or 0.0;
    help_win.write(sprintf("Target bank: %.0f degrees", b));
}

setlistener("instrumentation/altimeter/setting-inhg", h_altimeter);
setlistener("autopilot/settings/heading-bug-deg", h_heading);
setlistener("instrumentation/nav[0]/radials/selected-deg", h_course);
setlistener("instrumentation/nav[1]/radials/selected-deg", h_course_two);
setlistener("autopilot/settings/vertical-speed-fpm", h_vs);
setlistener("instrumentation/rmi/face-offset", h_mis);
setlistener("autopilot/settings/target-pitch-deg", h_pitch);
setlistener("autopilot/settings/target-bank-deg", h_bank);

################################################################################
# TRIM WHEEL
################################################################################

var trimBackTime = 2.0;

var applyTrimWheels = func(v, which = 0) {
    if (which == 0) {
        interpolate("controls/flight/elevator-trim", v, trimBackTime);
    } elsif (which == 1) {
        interpolate("controls/flight/rudder-trim", v, trimBackTime);
    } elsif (which == 2) {
        interpolate("controls/flight/aileron-trim", v, trimBackTime);
    }
}

var lastTrimProperty = "autopilot/trim/last-elev-trim-turn";
var lastTrimValue = props.globals.initNode(lastTrimProperty, 0, "DOUBLE");

setlistener("controls/flight/elevator-trim", func(et) {
    var et = et.getValue();
    var ap = getprop("autopilot/switches/ap") or 0;
    if (!ap) {
        setprop("autopilot/trim/elevator-trim-turn", et);
        lastTrimValue.setValue(et);
    }
}, startup = 0, runtime = 0);

var trim_loop = maketimer (8.2, func{
    var et = getprop("controls/flight/elevator-trim") or 0;
    var ap = getprop("autopilot/switches/ap") or 0;
    var diff = abs(lastTrimValue.getValue() - et);
    if (ap and diff > 0.002){
        if (diff < 0.05 ) {
            interpolate("autopilot/trim/elevator-trim-turn", et, 2);
        } elsif (diff >= 0.05 and diff < 0.3) {
            interpolate("autopilot/trim/elevator-trim-turn", et, 4);
        } else {
            interpolate("autopilot/trim/elevator-trim-turn", et, 6);
        }
        lastTrimValue.setValue(et);
    }
});

trim_loop.start();
