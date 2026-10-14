class_name CollisionLayers
extends RefCounted

## CollisionLayers: Централізовані бітові маски фізичних шарів для 3D простору гри.

const WORLD: int = 1 << 0                   ## Шар 1 (біт 0): Тверда геометрія світу, поверхня, ресурси, готові споруди
const PLAYER: int = 1 << 1                  ## Шар 2 (біт 1): Тіло гравця
const COLONIST: int = 1 << 2                ## Шар 3 (біт 2): Фізичні тіла колоністів
const BLUEPRINT: int = 1 << 3               ## Шар 4 (біт 3, значення 8): Будівельні майданчики та напівпрозорі креслення
const WORLD_AND_BLUEPRINT: int = WORLD | BLUEPRINT ## Шари 1 + 8 = 9: Твердий світ та прохідні креслення
