extends RefCounted
## Godot port of levels/Patch.java generate(), upstream 2bb34a4.
## Clustering and forced fill-rate rules follow the Java algorithm.


static func generate(rng, width: int, height: int,
		fill: float, clustering: int, force_fill_rate: bool) -> PackedByteArray:
	var length := width * height
	var target := roundi(length * fill)
	var fill_diff := -target
	if force_fill_rate and clustering > 0:
		fill += (0.5 - fill) * 0.5
	var current := PackedByteArray()
	var previous := PackedByteArray()
	current.resize(length)
	previous.resize(length)
	for index in range(length):
		previous[index] = 1 if rng.randf() < fill else 0
		if previous[index] != 0:
			fill_diff += 1
	for iteration in range(clustering):
		for y in range(height):
			for x in range(width):
				var index := x + y * width
				var count := 0
				var neighbors := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < width and ny < height:
							neighbors += 1
							if previous[nx + ny * width] != 0:
								count += 1
				current[index] = 1 if 2 * count >= neighbors else 0
				if current[index] != previous[index]:
					fill_diff += 1 if current[index] != 0 else -1
		var swap := current
		current = previous
		previous = swap
	if force_fill_rate and mini(width, height) > 2:
		var growing := fill_diff < 0
		var correction_steps := 0
		while fill_diff != 0 and correction_steps < length * 20:
			correction_steps += 1
			var cell := 0
			var tries := 0
			while true:
				cell = rng.randi_range(1, width - 2) + rng.randi_range(1, height - 2) * width
				tries += 1
				if (previous[cell] != 0) == growing or tries * 10 >= length:
					break
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var neighbor := cell + dx + dy * width
					if fill_diff != 0 and (previous[neighbor] != 0) != growing:
						previous[neighbor] = 1 if growing else 0
						fill_diff += 1 if growing else -1
		# The Java loop has no bound. Keep malformed Godot maps from hanging.
		if fill_diff != 0:
			for index in range(length):
				if fill_diff == 0:
					break
				if (previous[index] != 0) != growing:
					previous[index] = 1 if growing else 0
					fill_diff += 1 if growing else -1
	return previous
