# FlightGear Lockheed1049h Redux #

## Notes about installation ##
Please remove the name of the branch if cloning the state of any Git branch, e.g. `-main`. The name of the directory and model is designed such that this meshes cleanly for any users still using the FGAddon version of `Lockheed1049h`. However, the 3D model will diverge, which may present issues for multiplayer passengers/engineers.

## Stated Motivations and Goals ##
- DONE: IFR with radio navaids is currently possible, but not all procedures are flyable without a DME, and being able to switch back and forth between two pre-set CDIs is convenient. DME has been added to the top-center panel unit, and functionality for the `DEVIATION NAV1/NAV2` switch has been extended from the Zero Indicator to also select NAV1/NAV2 for the autopilot.
- DONE: fresh new autopilot by Josh Davidson (github:Octal450)
- For oceanic flying that at least I would like to do, clickable tools or automation to handle dead reckoning ("inertial navigation" if the suite gets fancy enough) may be added in the further future.
- For fun with friends and for ease of the combination captain-engineer's job, dual control is a goal for the far future to enable the signing-on of both a captain and an engineer individually in the same flyable plane.

## Contributing ##
- Single-issue development guests feel free to fork and then make a pull request.
- If you'd like to stick around longer, ask to be invited as a collaborator. You can either open and occupy a `username-dev` branch or play with a branch themed around a feature or a bugfix. Use `feature/` or `bugfix/`.

## Credits ##
Original plane: Gary "Buckaroo" Neely

DME-339F-12A from Citation II: Sascha Reißner
Assistance with developing aileron PID (and speed/gain interpolator): Josh Davidson
Mixture automation: Justin Nicholson
