# Dual control for the Lockheed1049h Super Constellation
# Copyright (c) 2016 Ludovic Brenta <ludovic@ludovic-brenta.org>
# Based on the dual control tools for FlightGear, by Anders Gidenstam.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

######################################################################
# Unlike some other aircraft, this dual control does not support a
# pilot and a copilot, a situation that I find uninteresting.
# Instead, it supports a pilot and a flight engineer.  The flight
# engineer performs startup, engine and fuel management and is very
# busy during all phases of flight.
#
# There are several flows of information between pilot and engineer,
# some bidirectional.
#
# Pilot to engineer: aircraft position, velocity, orientation; control
# surfaces, lights, fuel levels, fuel flow, BMEP (computed in the
# pilot's aircraft with a property rule), i.e. everything that the
# engineer needs to see and move with the aircraft and move the
# instruments.  Some properties are already transmitted as part of the
# multiplayer protocol, some others are already transmitted as part of
# multiplayer support (see Lockheed1049h-set.xml); here we only add
# the missing ones.
#
# Engineer to pilot: cowl flaps, propeller pitch, mixture, fuel
# valves, fuel dump, battery switches, boost speed, engine start
# switches.
#
# Bidirectional: throttle.
#
# When an engineer is connected, the pilot can *not* control the
# engineer functions, except for the throttle.  In real life, pilots
# would use the throttles only during taxi (i.e. differential throttle
# to help steer the aircraft on the ground) then hand control over to
# the engineer.

var DCT = dual_control_tools;

## Pilot/copilot aircraft identifiers. Used by dual_control.
var pilot_type   = "Aircraft/Lockheed1049h/Models/Lockheed1049h.xml";
var copilot_type = "Aircraft/Lockheed1049h/Models/L1049h-engineer.xml";
var connected = 0;

expand_string = func (s) {
    # input: a string of the form "/foo/bar[0..8]/baz"
    # output: a vector of strings of the form
    #         [ "/foo/bar[0]/baz", ... , "/foo/bar[8]/baz" ]
    var result = [];
    var state = 0;
    var low_bound = 0;
    var high_bound = 0;
    var prefix = "";
    var suffix = "";
    for (var j = 0; j < size (s); j += 1) {
        var c = chr(s[j]);
        if (state == 0) { # before '['
            if (c == "[") { prefix = substr(s, 0, j+1); state = 1; }
        }
        else if (state == 1) { # between '[' and "..": extract low bound
            if (c == "]") { suffix = c; state = 2; }
            else if (c == ".") { state = 3; }
            else {
               var v = int(c);
               if (v == nil) {
                   print ("parse error in string '" ~ s ~ "' at index " ~ j
                        ~ ": expected a number, found '" ~ c);
                   return [];
               }
               low_bound = low_bound * 10 + v;
            }
        }
        else if (state == 2) { # after ']': extract rest of string
            suffix ~= c;
        }
        else if (state == 3) { # after first dot: expect a second dot
            if (c == ".") { state = 4; }
            else {
               print ("parse error in string '" ~ s ~ "' at index " ~ j
                        ~ ": expected a dot, found '" ~ c);
               return [];
            }
        }
        else if (state == 4) { # after second dot: expect digits or ']'
           if (c == "]") { suffix = "]"; state = 2; }
           else {
               var v = int(c);
               if (v == nil) {
                   print ("parse error in string '" ~ s ~ "' at index " ~ j
                        ~ ": expected a number, found '" ~ c);
                   return [];
               }
               high_bound = high_bound * 10 + v;
           }
        }
    }
    if (high_bound == 0) { result = [s]; }
    else if (high_bound < low_bound) {
        print ("semantic error: high bound lower than low bound: ["
               ~ low_bound ~ ".." ~ high_bound ~ "]");
        return [];
    }
    else {
        setsize (result, high_bound - low_bound + 1);
        var r = 0;
        for (var j = low_bound; j <= high_bound; j += 1) {
            result[r] = prefix ~ j ~ suffix;
            r += 1;
        }
    }
    return result;
}


expand_vector = func (v, vector_name) {
    var result = [];
    foreach (var s; v) {
        result ~= expand_string (s);
    }
    var sz = size (result);
    print ("L1049h-dual-control: Expanded " ~ vector_name
         ~ " into " ~ sz ~ " properties");
    if (sz == 0) {
        fgcommand ("exit");
        # to make this error highly visible to the aircraft developer
    }
    if (sz > 127) {
        print ("L1049h-dual-control: error: "
             ~ "too many properties in a single string!");
        # because the TDMEncoder encodes the index of each property into a
        # single byte in the string.
        fgcommand ("exit");
    }
    return result;
}

var key_value_pair_length = mp_broadcast.Binary.sizeOf["byte"]
                          + mp_broadcast.Binary.sizeOf["double"];

var TDMEncoder = {
    new : func (inputs, dest) {
        var m = {
            parents : [ TDMEncoder, DCT.TDMEncoder.new (inputs, dest) ],
            last_input_sent : 0,
            message_counter : 0,
            old_values : [],
        };
        return m;
    },
    send_all_properties : func () {
        setsize (me.old_values, size (me.inputs));
        forindex (var j; me.inputs) {
            me.old_values[j] = { initialized: 0, value: nil };
        }
    },
    send : func (msg, key) {
        me.channel.send (msg);
        me.last_input_sent = key + 1;
        me.message_counter += 1;
    },
    update : func () {
        if (!connected) { return; }
        var msg = "";
        var debug_msg = me.message_counter ~ ": sending properties at indexes:";
        if (math.mod (me.message_counter, 100) == 0) {
            me.send_all_properties();
        }
        forindex (var index; me.inputs) {
            var key = math.mod (index + me.last_input_sent, size (me.inputs));
            var v = me.inputs[key].getValue();
            if (!me.old_values[key].initialized
                or me.old_values[key].value != v) {
                msg ~= mp_broadcast.Binary.encodeByte (key);
                msg ~= mp_broadcast.Binary.encodeDouble (v);
                debug_msg ~= " " ~ key
                    ~ (me.old_values[key].initialized ?
                       (me.old_values[key].value != v ? " (changed)" : " (resent)")
                       : " (first sent)");
                me.old_values[key] = { initialized: 1, value: v };
            }
            # Bug: there is a limit of 128 characters per string, so send the
            # message before hitting this limit.  On the next update, we will
            # send other key-value pairs.
            #
            # Bug: fgfs silently drops some properties from the packet if its
            # total length exceeds 1200 bytes; this includes all the predefined
            # properties as well as the inputs.  So, we conservatively restrict
            # the length of any one string property to fewer than the maximum;
            # even this does not guarantee that the packet length stays below
            # 1200 bytes.
            #
            # Since we can send only a few properties at a time, bandwidth is
            # severely restricted, so we send only the properties  whose value
            # has changed.  Once every 10 messages, we re-send all properties.
            if (size (msg) > 66 - key_value_pair_length) {
                me.send (msg, key);
                if (getprop ("/sim/multiplay/debug")) { print (debug_msg); }
                return;
            }
        }
        if (size (msg) > 0) {
            me.send (msg, -1);
        }
    }
};

var TDMDecoder = {
    new: func (src, remote_node, properties) {
        var m = {
            parents : [ TDMDecoder ],
            channel : mp_broadcast.MessageChannel.new
                        (src, func (msg) { m.process (msg); }),
            properties : properties,
            remote_node : remote_node };
        return m;
    },
    process_key_value_pair: func (msg) {
        var index = mp_broadcast.Binary.decodeByte (msg);
        if (index < 0) { index += 128; } # I want an unsigned byte!
        var value = mp_broadcast.Binary.decodeDouble (substr (msg, 1));
        var node = me.remote_node.getNode (me.properties[index], 1);
        node.setValue (value);
    },
    process: func (msg) {
        if (!connected) { return; }
        var j = 0;
        while (j < size (msg)) {
            me.process_key_value_pair (substr (msg, j, key_value_pair_length));
            j += key_value_pair_length;
        }
    },
    update: func () { me.channel.update(); }
};


var Translator = {
    new : func (src = nil, dest = nil, factor = 1, offset = 0) {
        print (debug.string (dest) ~ " := " ~ debug.string (src));
        return { parents: [
            Translator, DCT.Translator.new (src, dest, factor, offset)
        ] };
    }
};

var SwitchDecoder = {
    new : func (src_node, dest_node, targets) {
        # src_node: an input property containing a packed array of booleans
        # dest_node: a node under which to fill target properties
        # targets: a vector of property names under dest_node
        return { parents : [ SwitchDecoder, DCT.SwitchDecoder.new (src_node, []) ],
                 dest_node : dest_node,
                 targets   : targets
               };
    },
    update : func () {
        # DCT.SwitchDecoder relies on an array of action functions; we instead
        # decode into the targets.  Also, we decode every time we are called and
        # do not rely on old values of the bits in the input property.
        var value = me.src.getValue();
        if (num (value) == nil) { return; } # presumably the other party is not sending yet
        var t = getprop ("/sim/time/elapsed-sec"); # simulated time
        if (value == me.old) {
            if ((t - me.stable_since) < me.MIN_STABLE) {
                # Wait until the value becomes stable
            }
            else {
                foreach (var prop_name; me.targets) {
                    var bit = math.mod (value, 2);
                    me.dest_node.getNode (prop_name, 1).setBoolValue (bit);
                    value = (value - bit) / 2;
                }
            }
        }
        else {
            # value has changed, reset the stable counter
            me.stable_since = t;
            me.old = value;
        }
    }
};


var MultiBitIntEncoderDecoder = {
    new : func (nodes, node, bits_per_int) {
        # properties: a vector of property nodes; each is an int that will be encoded on bits_per_int bits.
        # target_node: the target integer node.
        me.check_multi_bit_prerequisites (nodes, bits_per_int);
        var factor = 1;
        for (var j = 1; j <= bits_per_int; j += 1) { factor *= 2; }
        return { parents : [ MultiBitIntEncoder ],
                 nodes : nodes,
                 node  : node,
                 factor : factor };
    },
    check_multi_bit_prerequisites : func (nodes, bits_per_int) {
        if (num (bits_per_int) == nil or bits_per_int < 1) {
            print ("MultiBitIntEncoder or Decoder: bits_per_int must be an integer and at least one");
            fgcommand ("exit");
        }
        if (size (nodes) > int (32 / bits_per_int)) {
            print ("MultiBitIntEncoder or Decoder: too many properties: " ~ debug.string (nodes)
                   ~ ", bits_per_int=" ~ bits_per_int);
            fgcommand ("exit");
        }
    }
};

var MultiBitIntEncoder = {
    new : func (nodes, node, bits_per_int) {
        return { parents : [ MultiBitIntEncoder, MultiBitIntEncoderDecoder.new (nodes, node, bits_per_int) ] };
    },
    update : func () {
        var value = 0;
        var party_not_sending_skip = 0;
        forindex (var j; me.nodes) {
           value += me.nodes[j].getValue ();
           if (j < size (me.nodes) - 1) { value *= me.factor; }
        }
        me.node.setValue (value);
    }
};

var MultiBitIntDecoder = {
    new : func (nodes, node, bits_per_int) {
        return { parents : [ MultiBitIntDecoder, MultiBitIntEncoderDecoder.new (nodes, node, bits_per_int) ],
                 stable_since : 0,
                 old_value : 0,
                 MIN_STABLE : 0.2 };
    },
    update : func () {
        var v = me.node.getValue();
        if (num (v) == nil) { return; } # presumably the other party is not sending yet
        var t = getprop ("/sim/time/elapsed-sec");
        if (v == me.old_value) {
            if ((t - me.stable_since) < me.MIN_STABLE) {
                # Wait until the value becomes stable
            }
            else {
                forindex (var j; me.nodes) {
                    var one_value = math.mod (v, me.factor);
                    me.nodes[size (me.nodes) - j - 1].setIntValue (one_value);
                    v = (v - one_value) / me.factor;
                }
            }
        }
        else {
            # value has changed, reset the stable counter
            me.stable_since = t;
            me.old_value = v;
        }
    }
};


var NormalizedFloatEncoderDecoder = {
    # Encodes or Decodes four normalized floats into four fixed-point, 8-bit values packed in
    # one 32-bit integer.
    new : func (nodes, node) {
        if (size (nodes) != 4) {
            print ("NormalizedFloatEncoderDecoder requires exactly four nodes to encode or decode");
            fgcommand ("exit");
        }
        return { parents : [ NormalizedFloatEncoderDecoder ],
                 nodes   : nodes,
                 node    : node };
    }
};

var NormalizedFloatEncoder = {
    new : func (nodes, node) {
        return { parents : [ NormalizedFloatEncoder, NormalizedFloatEncoderDecoder.new (nodes, node) ] };
    },
    update : func () {
        var v = 0;
        forindex (var j; me.nodes) {
            var one_value = me.nodes[j].getValue ();
            if (one_value < 0 or one_value > 1) {
                print ("NormalizedFloatEncoder: The property " ~ me.nodes[j].getPath() ~ " has a value outside [0..1]!");
            }
            else {
                # I would like to encode each of the properties on 8 bits but Nasal does not have proper wraparound
                # semantics; instead it has saturating arithmetic whereby any overflow causes the value to become
                # -2**31 exacltly, losing any other significant bits.  Therefore we encode each property on only 7
                # bits, the total value can thus never exceed 2**29.
                v += int (one_value * 127);
            }
            if (j < size (me.nodes) - 1) {
                v *= 128;
            }
        }
        me.node.setIntValue (v);
    }
};

var NormalizedFloatDecoder = {
    new : func (nodes, node) {
        return { parents : [ NormalizedFloatDecoder, NormalizedFloatEncoderDecoder.new (nodes, node) ],
                 stable_since : 0,
                 old_value : 0,
                 MIN_STABLE : 0.2 }
    },
    update : func () {
        var v = me.node.getValue ();
        if (num (v) == nil) { return; }
        var t = getprop ("/sim/time/elapsed-sec");
        if (v < 0) { v += mp_broadcast.Binary.TWOTO31; }
        if (v == me.old_value) {
            if ((t - me.stable_since) < me.MIN_STABLE) {
                # Wait until the value becomes stable
            }
            else {
                forindex (var j; me.nodes) {
                    var one_value = math.mod (v, 128);
                    me.nodes[size (me.nodes) - j - 1].setDoubleValue (one_value / 127);
                    v = (v - one_value) / 128;
                }
            }
        }
        else {
            # value has changed, reset the stable counter
            me.stable_since = t;
            me.old_value = v;
        }
    }
};

getNodes = func (root_node, v) {
    # v: a vector of strings with property names, like the result of
    # expand_vector above.
    # result: a vector of property nodes.
    var result = [];
    setsize (result, size (v));
    forindex (var j; v) {
        result[j] = root_node.getNode (v[j], 1);
    }
    return result;
}

check_properties = func (source_properties, transport_properties) {
    var a = size (source_properties);
    var b = size (transport_properties);
    var min = a > b ? b : a;
    var max = a > b ? a : b;
    for (var j = 0; j < max; j += 1) {
        if (j < min) {
            print ("    " ~ source_properties[j]
                ~ " <=> " ~ transport_properties[j]);
        }
        else if (j < a) {
            print ("    " ~ source_properties[j] ~ " <=> ?");
        }
        else if (j < b) {
            print ("                    ? <=> "
                   ~ transport_properties[j]);
        }
    }
    if (a != b) {
        fgcommand ("exit");
    }
}


var pilot_to_engineer_properties = expand_vector ([
    # These are properties sent above and beyond the normal multiplayer
    # properties that animate the model; they are intended only for the
    # engineer.  Therefore, be sure to use generic properties that are
    # not already used in Lockheed1049h-set.xml.
    "controls/engines/engine[0]/propeller-pitch",
    "engines/engine[0..3]/bmep",
    "engines/engine[0..3]/cht-degf",
    "engines/engine[0..3]/fuel-flow-gph",
    "engines/engine[0..3]/mp-osi",
    ], "pilot_to_engineer_properties");
var pilot_to_engineer_properties_transmitted = expand_vector ([
    "engines/engine[5]/rpm",
    "engines/engine[0..3]/n1",
    "engines/engine[5..8]/n1",
    "engines/engine[0..3]/n2",
    "engines/engine[5..8]/n2",
    ], "pilot_to_engineer_properties_transmitted");
check_properties (pilot_to_engineer_properties, pilot_to_engineer_properties_transmitted);

var packed_mixture_properties = expand_vector ([ # these are sent both ways
    "controls/engines/engine[0..3]/mixture"
    ], "packed_mixture_properties");
                    
var packed_throttle_properties = expand_vector ([ # these are sent both ways
    "controls/engines/engine[0..3]/throttle",
    ], "packed_throttle_properties");

var packed_2bit_int_properties = expand_vector ([ # these are sent both ways
    "controls/engines/engine[0..3]/magnetos",
    "controls/fuel/tankvalve[0..4]"
    ], "packed_2bit_int_properties");

var packed_3bit_int_properties = expand_vector ([ # these are sent both ways
    "controls/fuel/enginevalve[0..3]",
    "controls/fuel/jettison[0..1]/valve",
    "controls/switches/engine-start-select",
    ], "packed_3bit_int_properties");

var packed_boolean_properties = expand_vector ([ # these are sent both ways
    "controls/fuel/crossfeedvalve[0..3]",
    "controls/switches/battery-cart",
    "controls/switches/battery-ship",
    "controls/switches/command-bell",
    "controls/switches/engine-start",
    "controls/switches/gen-apu",
    "controls/switches/generator[0..3]",
    "controls/switches/horn",
    "controls/switches/no-smoking-signs",
    "controls/switches/seat-belt-signs",
    "fdm/jsbsim/propulsion/engine[0..3]/boost-speed",
    ], "packed_boolean_properties");

var pilot_to_engineer_properties_string0 = expand_vector ([
    "consumables/fuel/tank[4..12]/level-gal_us",
    "consumables/fuel/tank[4..12]/level-lbs",
     # 0..3 are the engine fuel lines, not needed by the engineer
    "consumables/fuel/total-fuel-lbs",
    "controls/engines/engine[0..3]/cowl-flaps-norm",
    "controls/flight/aileron",
    "controls/flight/aileron-trim",
    "controls/flight/elevator",
    "controls/flight/elevator-trim",
    "controls/flight/rudder",
    "controls/flight/rudder-trim",
    "engines/engine[0..3]/egt-degf",
    "engines/engine[0..3]/est-fuelpress",
    "engines/engine[0..3]/oil-pressure-psi",
    "engines/engine[0..3]/oil-temperature-degf",
    "instrumentation/slip-skid-ball/indicated-slip-skid",
    "instrumentation/turn-indicator/indicated-turn-rate",
    ], "pilot_to_engineer_properties_string0");

var engineer_to_pilot_properties = expand_vector ([
    # The properties that the engineer sends to the pilot
    "consumables/fuel/tank[4..12]/level-gal_us",
    "controls/engines/engine[0..3]/cowl-flaps-norm",
    "controls/engines/engine[0]/propeller-pitch",
    "controls/lighting/panel-norm",
    ], "engineer_to_pilot_properties");
var engineer_to_pilot_properties_transmitted = expand_vector ([
    # The properties that are part of the default multiplayer protocol, and used
    # to send the above properties.  The engineer uses an alias to write into
    # the properties; the pilot uses a Translator to read them and write the
    # values into its own properties.
    "sim/multiplay/generic/float[4..12]",
    "engines/engine[0..3]/n1",
    "engines/engine[0]/rpm",
    "sim/multiplay/generic/float[0]",
    ], "engineer_to_pilot_properties_transmitted");
check_properties (engineer_to_pilot_properties, engineer_to_pilot_properties_transmitted);

pilot_connect_copilot = func (copilot) {
    connected = 1;
    var result = [
        MultiBitIntDecoder.new (getNodes (copilot, packed_2bit_int_properties),
                                copilot.getNode ("sim/multiplay/generic/int[3]", 1),
                                2),
        MultiBitIntDecoder.new (getNodes (copilot, packed_3bit_int_properties),
                                copilot.getNode ("sim/multiplay/generic/int[4]", 1),
                                3),
        NormalizedFloatDecoder.new (getNodes (copilot, packed_mixture_properties),
                                    copilot.getNode ("sim/multiplay/generic/int[5]", 1)),
        NormalizedFloatDecoder.new (getNodes (copilot, packed_throttle_properties),
                                    copilot.getNode ("sim/multiplay/generic/int[6]", 1)),
        SwitchDecoder.new (copilot.getNode ("sim/multiplay/generic/int[19]", 1),
                           copilot,
                           packed_boolean_properties),
    ];
    forindex (var j; engineer_to_pilot_properties) {
        var engineer_node = copilot.getNode (engineer_to_pilot_properties_transmitted[j]);
        var pilot_node = props.globals.getNode (engineer_to_pilot_properties[j]);
        result ~= [ DCT.MostRecentSelector.new (engineer_node, pilot_node, pilot_node, 0.01) ];
    }
    var rpm0 = props.globals.getNode ("controls/engines/engine[0]/propeller-pitch");
    # propeller-pitch is special: propagate it to all other engines as there is only one command for all 4.
    result ~= [
        DCT.Translator.new (rpm0, props.globals.getNode ("controls/engines/engine[1]/propeller-pitch")),
        DCT.Translator.new (rpm0, props.globals.getNode ("controls/engines/engine[2]/propeller-pitch")),
        DCT.Translator.new (rpm0, props.globals.getNode ("controls/engines/engine[3]/propeller-pitch")) ];
    foreach (var prop; packed_2bit_int_properties) {
        var engineer_node = copilot.getNode (prop, "INT", 1);
        var pilot_node = props.globals.getNode (prop, "INT", 1);
        result ~= [ DCT.MostRecentSelector.new (engineer_node, pilot_node, pilot_node, 0.9) ];
    }
    foreach (var prop; packed_3bit_int_properties) {
        var engineer_node = copilot.getNode (prop, "INT", 1);
        var pilot_node = props.globals.getNode (prop, "INT", 1);
        result ~= [ DCT.MostRecentSelector.new (engineer_node, pilot_node, pilot_node, 0.9) ];
    }
    foreach (var prop; packed_mixture_properties) {
        var engineer_node = copilot.getNode (prop, "DOUBLE", 1);
        var pilot_node = props.globals.getNode (prop, "DOUBLE", 1);
        result ~= [ DCT.MostRecentSelector.new (engineer_node, pilot_node, pilot_node, 1 / 127) ];
    }
    foreach (var prop; packed_throttle_properties) {
        var engineer_node = copilot.getNode (prop, "DOUBLE", 1);
        var pilot_node = props.globals.getNode (prop, "DOUBLE", 1);
        result ~= [ DCT.MostRecentSelector.new (engineer_node, pilot_node, pilot_node, 1 / 127) ];
    }
    foreach (var prop; packed_boolean_properties) {
        var engineer_node = copilot.getNode (prop, "BOOL", 1);
        var pilot_node = props.globals.getNode (prop, "BOOL", 1);
        result ~= [ DCT.MostRecentSelector.new (engineer_node, pilot_node, pilot_node, 0.9) ];
    }
    var pilot_nodes = getNodes (props.globals, pilot_to_engineer_properties);
    var mp_protocol_nodes = getNodes (props.globals, pilot_to_engineer_properties_transmitted);
    forindex (var j; pilot_to_engineer_properties) {
        result ~= [ DCT.Translator.new (pilot_nodes[j], mp_protocol_nodes[j]) ];
    }
    result ~= [
        TDMEncoder.new (getNodes (props.globals, pilot_to_engineer_properties_string0),
                        props.globals.getNode ("sim/multiplay/generic/string[0]", 1)),
        MultiBitIntEncoder.new (getNodes (props.globals, packed_2bit_int_properties),
                                props.globals.getNode ("sim/multiplay/generic/int[3]", 1),
                                2),
        MultiBitIntEncoder.new (getNodes (props.globals, packed_3bit_int_properties),
                                props.globals.getNode ("sim/multiplay/generic/int[4]", 1),
                                3),
        NormalizedFloatEncoder.new (getNodes (props.globals, packed_mixture_properties),
                                    props.globals.getNode  ("sim/multiplay/generic/int[5]", 1)),
        NormalizedFloatEncoder.new (getNodes (props.globals, packed_throttle_properties),
                                    props.globals.getNode  ("sim/multiplay/generic/int[6]", 1)),
        DCT.SwitchEncoder.new (getNodes (props.globals, packed_boolean_properties),
                               props.globals.getNode ("sim/multiplay/generic/int[2]", 1))
    ];
    return result;
}

pilot_disconnect_copilot = func () { connected = 0; }

copilot_connect_pilot = func (pilot) {
    connected = 1;
    result = [
        MultiBitIntDecoder.new (getNodes (pilot, packed_2bit_int_properties),
                                pilot.getNode ("sim/multiplay/generic/int[3]", 1),
                                2),
        MultiBitIntDecoder.new (getNodes (pilot, packed_3bit_int_properties),
                                pilot.getNode ("sim/multiplay/generic/int[4]", 1),
                                3),
        NormalizedFloatDecoder.new (getNodes (pilot, packed_mixture_properties),
                                    pilot.getNode ("sim/multiplay/generic/int[5]", 1)),
        NormalizedFloatDecoder.new (getNodes (pilot, packed_throttle_properties),
                                    pilot.getNode ("sim/multiplay/generic/int[6]", 1)),
        TDMDecoder.new (pilot.getNode ("sim/multiplay/generic/string[0]", 1),
                        pilot,
                        pilot_to_engineer_properties_string0),
        SwitchDecoder.new (pilot.getNode ("sim/multiplay/generic/int[2]", 1),
                           pilot,
                           packed_boolean_properties)
    ];
    forindex (var j; engineer_to_pilot_properties) {
        var transmitted_engineer_node = props.globals.getNode (engineer_to_pilot_properties_transmitted[j], 1);
        var engineer_node = props.globals.getNode (engineer_to_pilot_properties[j], 1);
        transmitted_engineer_node.alias (engineer_node);
    }
    forindex (var j; pilot_to_engineer_properties) {
        var transmitted_pilot_node = pilot.getNode (pilot_to_engineer_properties_transmitted[j], 1);
        var pilot_node = pilot.getNode (pilot_to_engineer_properties[j], 1);
        pilot_node.alias (transmitted_pilot_node);
    }
    var rpm0 = pilot.getNode ("controls/engines/engine[0]/propeller-pitch");
    # propeller-pitch is special: propagate it to all other engines as there is only one command for all 4.
    result ~= [
        DCT.Translator.new (rpm0, pilot.getNode ("controls/engines/engine[1]/propeller-pitch", 1)),
        DCT.Translator.new (rpm0, pilot.getNode ("controls/engines/engine[2]/propeller-pitch", 1)),
        DCT.Translator.new (rpm0, pilot.getNode ("controls/engines/engine[3]/propeller-pitch", 1)) ];
    foreach (var prop; packed_2bit_int_properties) {
        var pilot_node = pilot.getNode (prop, "INT", 1);
        var engineer_node = props.globals.getNode (prop, "INT", 1);
        result ~= [ DCT.MostRecentSelector.new (pilot_node, engineer_node, engineer_node, 0.9) ];
    }
    foreach (var prop; packed_3bit_int_properties) {
        var pilot_node = pilot.getNode (prop, "INT", 1);
        var engineer_node = props.globals.getNode (prop, "INT", 1);
        result ~= [ DCT.MostRecentSelector.new (pilot_node, engineer_node, engineer_node, 0.9) ];
    }
    foreach (var prop; packed_boolean_properties) {
        var engineer_node = pilot.getNode (prop, "BOOL", 1);
        var pilot_node = props.globals.getNode (prop, "BOOL", 1);
        result ~= [ DCT.MostRecentSelector.new (pilot_node, engineer_node, engineer_node, 0.1) ];
    }
    foreach (var prop; packed_mixture_properties) {
        var engineer_node = pilot.getNode (prop, "DOUBLE", 1);
        var pilot_node = props.globals.getNode (prop, "DOUBLE", 1);
        result ~= [ DCT.MostRecentSelector.new (pilot_node, engineer_node, engineer_node, 1 / 127) ];
    }
    foreach (var prop; packed_throttle_properties) {
        var engineer_node = pilot.getNode (prop, "DOUBLE", 1);
        var pilot_node = props.globals.getNode (prop, "DOUBLE", 1);
        result ~= [ DCT.MostRecentSelector.new (pilot_node, engineer_node, engineer_node, 1 / 127) ];
    }
    result ~= [
        MultiBitIntEncoder.new (getNodes (props.globals, packed_2bit_int_properties),
                                props.globals.getNode ("sim/multiplay/generic/int[3]", 1),
                                2),
        MultiBitIntEncoder.new (getNodes (props.globals, packed_3bit_int_properties),
                                props.globals.getNode ("sim/multiplay/generic/int[4]", 1),
                                3),
        NormalizedFloatEncoder.new (getNodes (props.globals, packed_mixture_properties),
                                props.globals.getNode ("sim/multiplay/generic/int[5]", 1)),
        NormalizedFloatEncoder.new (getNodes (props.globals, packed_throttle_properties),
                                props.globals.getNode ("sim/multiplay/generic/int[6]", 1)),
        DCT.SwitchEncoder.new (getNodes (props.globals, packed_boolean_properties),
                               props.globals.getNode ("sim/multiplay/generic/int[19]", 1))
    ];
    return result;
}

copilot_disconnect_pilot = func () { connected = 0; }
