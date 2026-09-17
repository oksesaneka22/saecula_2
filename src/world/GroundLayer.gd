extends TileMapLayer

## GroundLayer: Процедурне заповнення тайлами землі та трави.
## Генерує процедурну текстуру Image/ImageTexture у рантаймі (100% автономно без імпорту),
## створює TileSet та заповнює тестове поле.

const TILE_SIZE: int = 32

func setup_tileset() -> void:
	if tile_set != null:
		return

	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Створюємо Image розміром 64x32 (два тайли: 0,0 - трава, 1,0 - земля)
	var img: Image = Image.create(64, 32, false, Image.FORMAT_RGBA8)

	# Заповнюємо тайл 0 (Трава: x від 0 до 31)
	var grass_main: Color = Color("4b7d38")
	var grass_light: Color = Color("5e9646")
	var grass_dark: Color = Color("3d682e")

	for x in range(32):
		for y in range(32):
			var col: Color = grass_main
			if (x + y) % 7 == 0 or (x * 3 + y * 2) % 11 == 0:
				col = grass_light
			elif (x * 2 + y * 5) % 13 == 0:
				col = grass_dark
			img.set_pixel(x, y, col)

	# Заповнюємо тайл 1 (Земля: x від 32 до 63)
	var dirt_main: Color = Color("7a5538")
	var dirt_light: Color = Color("8c6342")
	var dirt_dark: Color = Color("61432b")

	for x in range(32, 64):
		for y in range(32):
			var col: Color = dirt_main
			if (x + y) % 5 == 0 or (x * 2 + y * 3) % 9 == 0:
				col = dirt_light
			elif (x * 3 + y * 7) % 11 == 0:
				col = dirt_dark
			img.set_pixel(x, y, col)

	var texture: ImageTexture = ImageTexture.create_from_image(img)

	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i(0, 0)) # Тайл 0: Трава
	source.create_tile(Vector2i(1, 0)) # Тайл 1: Земля
	ts.add_source(source, 0)

	tile_set = ts


## Заповнює область прямокутника тайлами (0 = трава, 1 = земля)
func generate_terrain(width: int, height: int) -> void:
	setup_tileset()
	clear()

	for x in range(width):
		for y in range(height):
			var tile_coord: Vector2i = Vector2i(0, 0) # Трава за замовчуванням
			# Природні острівці землі для варіативності
			if (x + y * 3) % 17 == 0 or (x * 2 + y) % 23 == 0:
				tile_coord = Vector2i(1, 0)

			set_cell(Vector2i(x, y), 0, tile_coord)
