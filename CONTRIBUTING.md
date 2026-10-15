# Contributing

Use the public PalCraft repository and fresh branches. Do not copy private development history, personal saves, skin selections, credentials or extracted Minecraft/Palworld assets into a contribution. Use `Invi <invi@users.noreply.github.com>` only as the project placeholder; contributors should use their own public identity.

Keep changes within their pack. Core supports either optional pack. HUD & Skins owns replacement screens, player cosmetics, controls, building and equipment. Islands & Animals owns islands, creatures, bosses and village services. A shared data/helper dependency belongs in Core and must not start optional services by itself.

Run the Lua 5.4 module graph checks for all install choices, including both map-art settings. Add a focused regression only when behavior needs one. Runtime native calls must stay on the existing timer master state. Do not use Lua coroutines, hot reload, engine lifecycle/widget base hooks, or native terrain edits.

Keep save readers backward compatible and preserve pending journals. Migration copies legacy data, retains recovery generations, and reports conflicts without overwriting populated saves. Describe relevant validation and remaining native/visual acceptance in your change.

Code contributions are GPL-3.0-or-later; original art contributions are CC BY 4.0. Add SPDX metadata. JSON/data files use adjacent `.license` files. Include attribution and provenance for new art. Minecraft assets remain local installer inputs, and Palworld assets remain external game dependencies.
