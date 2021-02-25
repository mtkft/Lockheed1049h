# FlightGear L1049H Redux #

## IMPORTANT INSTALLATION NOTE ##
For clarity about what this repo is for, I named the repo as is, but the aircraft name should remain `Lockheed1049h` as on the legacy FGADDON one. Beyond the usual "remove `-main`", please change your folder name after extraction.

## Stated Motivations and Goals ##
- DONE: IFR with radio navaids is currently possible, but not all procedures are flyable without a DME, and being able to switch back and forth between two pre-set CDIs is convenient. DME and functionality for the `DEVIATION NAV1/NAV2` switch have been added to the top-center panel unit.
- DONE: aileron servo commands are now rate-based à la IT-Autoflight with speed/gain function for P gain
- For oceanic flying that at least I would like to do, clickable tools or automation to handle dead reckoning ("inertial navigation" if the suite gets fancy enough) may be added in the further future.
- For fun with friends and for ease of the combination captain-engineer's job, dual control is a goal for the far future to enable the signing-on of both a captain and an engineer individually in the same flyable plane.

## Credits ##
Original plane: Gary "Buckaroo" Neely
DME-339F-12A from Citation II: Sascha Reißner
Assistance with developing aileron PID (and speed/gain interpolator): Josh Davidson