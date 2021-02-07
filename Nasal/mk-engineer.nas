# some functions must be answered for the engineer
#
# M.Kraus, March 2012


toggle_reverse_lockout = func {
  print ("toggle_reverse_lockout() ... not for engineer!");
}

toggle_prop_reverse = func {
  print ("toggle_prop_reverse() ... not for engineer!");
}

# mk-agl-radar is not load in Lockheed1049h-engineer-set.xml
# so fake here the altitude-agl-ft for the terrain-warning lamps

setlistener("/position/gear-agl-ft", func(alt) {
    var alt = alt.getValue() + 7.63;
    setprop("/position/altitude-agl-ft", alt);
});
