# TODO

## Next Session

* Add placement sound
* Fix the texture bugs

## Somewhat "short-term"

* move some methods to get seperate classes/modules for visuals, logic, objectmanagement and sound
* move the code to seperate files

## Known Bugs

* If you drag upwards/left the "last" tile flickers.
  my guess: the swap in Map.tiles_between

* If you replace a wall with an floor the walls didn't reconnect

* If you replace tiles while they where in the build queue the sometimes are rendered as black black black/empty squares