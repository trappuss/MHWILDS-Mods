# MenusEverywhere

A REFramework mod for Monster Hunter Wilds that brings the facility menus to you: Item Box,
Smithy, Artian weapons, shop, Melding Pot, Smelting Foundry, village trade, Support Desk,
camp functions and lobby tools.

Each facility is added as **one folder row** named with the game's own text, so the menus
stay tidy, and everything can be switched on or off.

## Where the menus can appear

Each place is set up separately and has its own presets: Everything, Essentials, Vanilla,
and Custom, which is your own setup and saves itself whenever you change an option.

| Place | What you can do |
| --- | --- |
| Player menu (Esc) | Pick a tab per folder, or collect folders in an extra tab you can name; put them first, hide the game's own entries |
| Main tent menu | Add facility folders |
| Pop-up and makeshift camp menus | Add facility folders, include everything the base camp tent offers |
| Handler menu (Alma) | Same as camps, plus Item Box, Equipment and Camp folders. Off by default |

Camp and handler menus can also collect the folders in a tab of their own.

Smithy and Artian weapons only work from the player menu, so they are not offered in camp
or handler menus. The change equipment screens are not offered in the handler menu.

Other options:

- Reorder the folders and untick single entries inside any folder.
- Close stuck menus: a button that frees the game if a menu ever stops taking input.

## Install

Requires [REFramework](https://github.com/praydog/REFramework-nightly/releases).

Copy the `reframework` folder from this folder into the game folder. With Fluffy Mod Manager,
zip this folder's contents (`modinfo.ini` and `reframework`) and install that.

Settings are under **REFramework > Script Generated UI > MenusEverywhere** and are saved to
`reframework/data/MenusEverywhere.json`. Changes apply the next time a menu is opened.

## Notes

- No game files are replaced. The menus are changed in memory, so the mod does not depend on
  a specific game version, and removing it restores the vanilla menus.
- Do not combine it with mods that replace `StartMenuSetting.user.3` or the
  `FacilityMenu/*.user.3` files.
- The game decides which entries are usable. Entries you have not unlocked, or that the game
  blocks during a quest, stay hidden or greyed out.
- Tested in single player, in the hub and during quests. Multiplayer lobbies are untested.
