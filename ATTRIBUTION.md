# Original Shattered Pixel Dungeon material

This folder is an **independent Godot port prototype** based on the gameplay and visual design of [Shattered Pixel Dungeon](https://github.com/00-Evan/shattered-pixel-dungeon), by Evan Debenham, itself based on Pixel Dungeon by Oleg Dolya. It is not the upstream game or an official release.

Upstream snapshot used for code porting and assets: `00-Evan/shattered-pixel-dungeon` commit `2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f` (retrieved 2026-09-25). The following original image files were copied **unchanged** from `core/src/main/assets/`:

- `environment/tiles_sewers.png` → `assets/tiles_sewers.png`
- `sprites/warrior.png` → `assets/warrior.png`
- `sprites/rat.png` → `assets/rat.png`
- `sprites/snake.png` → `assets/snake.png`
- `sprites/gnoll.png` → `assets/gnoll.png`
- `sprites/swarm.png` → `assets/swarm.png`
- `sprites/crab.png` → `assets/crab.png`
- `sprites/slime.png` → `assets/slime.png`
- `sprites/items.png` → `assets/items.png`

The original project lists its code under [GNU GPL v3](https://github.com/00-Evan/shattered-pixel-dungeon/blob/master/LICENSE.txt) and its assets under [Creative Commons Attribution-ShareAlike 4.0](https://shattered-pixel.itch.io/shattered-pixel-dungeon). The original GPL text is included as [LICENSE.txt](LICENSE.txt). Parts of this Godot code adapt the original Java algorithms and rules; the mapped sources are listed in [PORTING.md](PORTING.md). All Godot code here is provided under GPL-3.0-or-later. The nine copied images remain under CC BY-SA 4.0 with the original authors' attribution. If an image is modified later, label that modification and keep its required attribution and share-alike terms.

The Korean UI uses the unmodified [Galmuri11 font](assets/fonts/Galmuri11.ttf) by Lee Minseo, licensed under SIL Open Font License 1.1. Its full notice is included in [Galmuri11.LICENSE.txt](assets/fonts/Galmuri11.LICENSE.txt).

This separate prototype must not be silently mixed into the parent game's release without checking the applicable license and credit obligations.
