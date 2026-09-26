#!/usr/bin/env python3
"""Record every tracked upstream Java source, including unported files.

Run with the pinned SPD checkout:
    python3 tools/port_inventory.py /path/to/shattered-pixel-dungeon
"""

from __future__ import annotations

import csv
import hashlib
import io
import subprocess
import sys
from pathlib import Path


UPSTREAM_COMMIT = "2bb34a4e91d29c8785a9363cad6ddfe5122b1d4f"
OUT = Path(__file__).resolve().parents[1] / "PORT_INVENTORY.tsv"

# "ported_unwired" means the source methods have a Godot counterpart but the
# active game still uses the older model. "partial" explicitly means that the
# Java class has further rules, subclasses, or dependencies not yet ported.
MAPPINGS = {
    "SPD-classes/src/main/java/com/watabou/utils/BArray.java": ("ported_unwired", "spd_barray.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/Point.java": ("ported_unwired", "spd_point.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/PointF.java": ("ported_unwired", "spd_pointf.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/Rect.java": ("ported_unwired", "spd_rect.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/GameMath.java": ("ported_unwired", "spd_game_math.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/Graph.java": ("ported_unwired", "spd_graph.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/Random.java": ("partial", "spd_random.gd"),
    "SPD-classes/src/main/java/com/watabou/utils/PathFinder.java": ("partial", "spd_pathfinder.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/Dungeon.java": ("partial", "spd_floor_seed.gd;run.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/Level.java": ("partial", "run.gd;spd_limited_drops.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/RegularLevel.java": ("partial", "run.gd;spd_regular_spawner.gd;spd_room_plan.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/rooms/Room.java": ("partial", "spd_room.gd;spd_room_door.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/builders/Builder.java": ("partial", "spd_builder.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/Actor.java": ("partial", "spd_actor_clock.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/Char.java": ("partial", "spd_combat.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/hero/Hero.java": ("partial", "run.gd;spd_combat.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/actors/mobs/MobSpawner.java": ("partial", "run.gd;spd_regular_spawner.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/items/Generator.java": ("partial", "run.gd"),
    "core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/mechanics/ShadowCaster.java": ("partial", "spd_shadowcaster.gd"),
}


def git_output(repo: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(repo), *args])


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: port_inventory.py /path/to/pinned-SPD", file=sys.stderr)
        return 2
    repo = Path(sys.argv[1]).resolve()
    commit = git_output(repo, "rev-parse", "HEAD").decode().strip()
    if commit != UPSTREAM_COMMIT:
        print(f"expected upstream {UPSTREAM_COMMIT}, found {commit}", file=sys.stderr)
        return 2
    paths = sorted(
        p.decode() for p in git_output(repo, "ls-files", "-z", "--", "*.java").split(b"\0") if p
    )
    if len(paths) != 1323:
        print(f"expected 1323 Java files, found {len(paths)}", file=sys.stderr)
        return 2
    out = io.StringIO()
    writer = csv.writer(out, delimiter="\t", lineterminator="\n")
    writer.writerow(("source_path", "source_sha256", "status", "godot_file"))
    for path in paths:
        state, godot = MAPPINGS.get(path, ("unported", "-"))
        digest = hashlib.sha256((repo / path).read_bytes()).hexdigest()
        writer.writerow((path, digest, state, godot))
    OUT.write_text(out.getvalue(), encoding="utf-8")
    counts = {state: sum(1 for path in paths if MAPPINGS.get(path, ("unported", ""))[0] == state)
              for state in ("ported_unwired", "partial", "unported")}
    print(f"{len(paths)} Java files recorded: {counts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
