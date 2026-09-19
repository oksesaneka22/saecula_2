class_name TextureHelper
extends RefCounted

## TextureHelper: Утиліта для роботи зі статичними файлами текстур та StandardMaterial3D.
## Забезпечує читання текстур із файлів у res://assets/textures/, їхнє кешування
## та застосування до 3D-моделей і предметів гри.

const PATH_TERRAIN_GRASS: String = "res://assets/textures/terrain/grass.png"
const PATH_TERRAIN_WATER: String = "res://assets/textures/terrain/water.png"

const PATH_RES_WOOD_BARK: String = "res://assets/textures/resources/wood_bark.png"
const PATH_RES_FOLIAGE: String = "res://assets/textures/resources/foliage.png"
const PATH_RES_ROCK: String = "res://assets/textures/resources/rock.png"
const PATH_RES_ROCK_DARK: String = "res://assets/textures/resources/rock_dark.png"
const PATH_RES_CLAY: String = "res://assets/textures/resources/clay_deposit.png"
const PATH_RES_FLINT: String = "res://assets/textures/resources/flint_deposit.png"
const PATH_RES_BUSH: String = "res://assets/textures/resources/bush.png"
const PATH_RES_BERRIES: String = "res://assets/textures/resources/berries.png"

const PATH_BLD_CAMPFIRE_STONE: String = "res://assets/textures/buildings/campfire_stone.png"
const PATH_BLD_LOG_WOOD: String = "res://assets/textures/buildings/log_wood.png"
const PATH_BLD_FIRE: String = "res://assets/textures/buildings/fire.png"
const PATH_BLD_WOOD_PLANKS: String = "res://assets/textures/buildings/wood_planks.png"
const PATH_BLD_WOOD_POST: String = "res://assets/textures/buildings/wood_post.png"
const PATH_BLD_CRATE: String = "res://assets/textures/buildings/crate.png"
const PATH_BLD_HUT_WALL: String = "res://assets/textures/buildings/hut_wall.png"
const PATH_BLD_HUT_ROOF: String = "res://assets/textures/buildings/hut_roof.png"
const PATH_BLD_HUT_DOOR: String = "res://assets/textures/buildings/hut_door.png"
const PATH_BLD_SITE_GROUND: String = "res://assets/textures/buildings/site_ground.png"
const PATH_BLD_STRAW_THATCH: String = "res://assets/textures/buildings/straw_thatch.png"
const PATH_BLD_ROPE: String = "res://assets/textures/buildings/rope.png"
const PATH_BLD_GENERIC: String = "res://assets/textures/buildings/generic_building.png"

const PATH_BLOCK_WOOD: String = "res://assets/textures/blocks/wood_block.png"
const PATH_BLOCK_STONE: String = "res://assets/textures/blocks/stone_block.png"

const PATH_ITEM_WOOD: String = "res://assets/textures/items/wood.png"
const PATH_ITEM_STRAW: String = "res://assets/textures/items/straw.png"
const PATH_ITEM_CLAY: String = "res://assets/textures/items/clay.png"
const PATH_ITEM_STONE: String = "res://assets/textures/items/stone.png"
const PATH_ITEM_FLINT: String = "res://assets/textures/items/flint.png"
const PATH_ITEM_BERRIES: String = "res://assets/textures/items/berries.png"
const PATH_ITEM_STONE_AXE: String = "res://assets/textures/items/stone_axe.png"
const PATH_ITEM_STONE_PICKAXE: String = "res://assets/textures/items/stone_pickaxe.png"
const PATH_ITEM_CAMPFIRE: String = "res://assets/textures/items/campfire.png"
const PATH_ITEM_GENERIC: String = "res://assets/textures/items/generic_item.png"

static var _cache: Dictionary = {}


## Отримує Texture2D за шляхом або повертає null у разі відсутності файлу
static func get_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D

	if FileAccess.file_exists(path):
		var global_p: String = ProjectSettings.globalize_path(path)
		var img := Image.new()
		var err := img.load(global_p)
		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			_cache[path] = tex
			return tex

	return null


## Створює StandardMaterial3D із призначеною текстурою та налаштуваннями
static func create_material(
	texture_path: String,
	fallback_color: Color = Color.WHITE,
	roughness: float = 0.85,
	uv1_scale: Vector3 = Vector3.ONE,
	is_emission: bool = false,
	emission_color: Color = Color.BLACK,
	emission_energy: float = 1.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = get_texture(texture_path)

	if tex != null:
		mat.albedo_texture = tex
		mat.albedo_color = Color.WHITE # Нейтральний білий, щоб відображалися кольори файлу текстури
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	else:
		mat.albedo_color = fallback_color

	mat.roughness = roughness
	mat.uv1_scale = uv1_scale

	if is_emission:
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = emission_energy
		if tex != null:
			mat.emission_texture = tex

	return mat


## Повертає шлях до статичної текстури предмета за його ID
static func get_item_texture_path(item_id: StringName) -> String:
	match item_id:
		&"wood":
			return PATH_ITEM_WOOD
		&"stone":
			return PATH_ITEM_STONE
		&"flint":
			return PATH_ITEM_FLINT
		&"clay":
			return PATH_ITEM_CLAY
		&"straw":
			return PATH_ITEM_STRAW
		&"berries":
			return PATH_ITEM_BERRIES
		&"stone_axe":
			return PATH_ITEM_STONE_AXE
		&"stone_pickaxe":
			return PATH_ITEM_STONE_PICKAXE
		&"campfire":
			return PATH_ITEM_CAMPFIRE
		_:
			return PATH_ITEM_GENERIC
