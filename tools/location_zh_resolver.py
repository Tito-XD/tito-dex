"""Resolve PokeAPI location-area slugs and English names to Chinese labels."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "data" / "l10n" / "zh" / "seeds" / "location_names_en_zh.json"
BULK_PATH = ROOT / "tools" / "location_names_bulk.py"
OVERRIDE_PATH = ROOT / "data" / "l10n" / "zh" / "seeds" / "location_area_slugs.json"

# Slug → 中文 (exact PokeAPI location-area slugs).
DEFAULT_SLUG_OVERRIDES: dict[str, str] = {
    "pallet-town-area": "真新镇",
    "viridian-city-area": "常磐市",
    "viridian-forest-area": "常磐森林",
    "pewter-city-area": "尼比市",
    "route-1-area": "1号道路",
    "route-2-area": "2号道路",
    "route-24-area": "24号道路",
    "route-25-area": "25号道路",
    "safari-zone-area": "狩猎地带",
    "mt-silver-area": "白银山",
    "national-park-area": "自然公园",
    "bell-tower-1f": "铃铛塔 1F",
    "burned-tower-1f": "烧焦塔 1F",
    "ice-path-1f": "冰雪小径 1F",
    "mt-mortar-1f": "擂钵山 1F",
    "dark-cave-area": "黑暗洞窟",
    "union-cave-1f": "连接洞窟 1F",
    "slowpoke-well-1f": "呆呆兽之井 1F",
    "cherrygrove-city-area": "吉花市",
    "violet-city-area": "桔梗市",
    "azalea-town-area": "桧皮镇",
    "goldenrod-city-area": "满金市",
    "ecruteak-city-area": "圆朱市",
    "olivine-city-area": "浅葱市",
    "cianwood-city-area": "湛蓝市",
    "mahogany-town-area": "卡吉镇",
    "blackthorn-city-area": "烟墨市",
    "new-bark-town-area": "若叶镇",
    "ilex-forest-area": "栎树林",
    "lake-of-rage-area": "愤怒之湖",
    "mt-moon-area": "月见山",
    "cerulean-city-area": "华蓝市",
    "lavender-town-area": "紫苑镇",
    "vermilion-city-area": "枯叶市",
    "celadon-city-area": "彩虹市",
    "fuchsia-city-area": "浅红市",
    "saffron-city-area": "金黄市",
    "cinnabar-island-area": "红莲镇",
    "indigo-plateau-area": "石英联盟",
    "victory-road-1-1f": "冠军之路 1F",
    "whirl-islands-1f": "涡旋岛 1F",
    "dragons-den-area": "龙穴",
    "tohjo-falls-area": "关都瀑布",
    "sprout-tower-1f": "喇叭芽之塔 1F",
    "ruins-of-alph-area": "阿露福遗迹",
    "radio-tower-1f": "广播塔 1F",
    "goldenrod-tunnel-area": "满金地下通道",
    "embedded-tower-area": "嵌入塔",
    "cliff-edge-gate-area": "断崖门",
    "battle-frontier-area": "对战开拓区",
    "safari-zone-gate-area": "狩猎地带入口",
}

# English place name → 中文 (HGSS / Kanto–Johto + common cross-gen locations).
DEFAULT_LOCATION_NAMES_EN_ZH: dict[str, str] = {
    "Mystery Zone": "神秘区域",
    "New Bark Town": "若叶镇",
    "Cherrygrove City": "吉花市",
    "Violet City": "桔梗市",
    "Azalea Town": "桧皮镇",
    "Goldenrod City": "满金市",
    "Ecruteak City": "圆朱市",
    "Olivine City": "浅葱市",
    "Cianwood City": "湛蓝市",
    "Mahogany Town": "卡吉镇",
    "Blackthorn City": "烟墨市",
    "Pallet Town": "真新镇",
    "Viridian City": "常磐市",
    "Pewter City": "尼比市",
    "Cerulean City": "华蓝市",
    "Lavender Town": "紫苑镇",
    "Vermilion City": "枯叶市",
    "Celadon City": "彩虹市",
    "Fuchsia City": "浅红市",
    "Saffron City": "金黄市",
    "Cinnabar Island": "红莲镇",
    "Indigo Plateau": "石英联盟",
    "Mt. Silver": "白银山",
    "National Park": "自然公园",
    "Bellchime Trail": "铃铛小径",
    "Bell Tower": "铃铛塔",
    "Burned Tower": "烧焦塔",
    "Sprout Tower": "喇叭芽之塔",
    "Ruins of Alph": "阿露福遗迹",
    "Union Cave": "连接洞窟",
    "Slowpoke Well": "呆呆兽之井",
    "Ilex Forest": "栎树林",
    "Goldenrod Tunnel": "满金地下通道",
    "Radio Tower": "广播塔",
    "Mt. Mortar": "擂钵山",
    "Lake of Rage": "愤怒之湖",
    "Ice Path": "冰雪小径",
    "Whirl Islands": "涡旋岛",
    "Dragon's Den": "龙穴",
    "Tohjo Falls": "关都瀑布",
    "Victory Road": "冠军之路",
    "Safari Zone": "狩猎地带",
    "Safari Zone Gate": "狩猎地带入口",
    "Pokéathlon Dome": "宝可梦全能竞技场",
    "Battle Frontier": "对战开拓区",
    "Embedded Tower": "嵌入塔",
    "Cliff Edge Gate": "断崖门",
    "Viridian Forest": "常磐森林",
    "Mt. Moon": "月见山",
    "Cerulean Cave": "华蓝洞窟",
    "Dark Cave": "黑暗洞窟",
    "Diglett's Cave": "地鼠洞",
    "DIGLETT's Cave": "地鼠洞",
    "Rock Tunnel": "岩山隧道",
    "Seafoam Islands": "双子岛",
    "Power Plant": "无人发电厂",
    "Silph Co.": "西尔佛公司",
    "Team Rocket HQ": "火箭队基地",
    "Lighthouse": "灯塔",
    "Global Terminal": "全球终端",
    "Cliff Cave": "断崖洞窟",
    "Battle Tower": "对战塔",
    "Battle Park": "对战公园",
    "Battle Factory": "对战工厂",
    "Battle Hall": "对战大厅",
    "Battle Castle": "对战城堡",
    "Battle Arcade": "对战轮盘",
    "Fight Area": "战斗区",
    "Frontier Access": "开拓区入口",
    "Jubilife City": "祝祝市",
    "Oreburgh City": "黑金市",
    "Floaroma Town": "百代镇",
    "Eterna City": "百代市",
    "Hearthome City": "家缘市",
    "Veilstone City": "帷幕市",
    "Pastoria City": "湿原市",
    "Canalave City": "水脉市",
    "Snowpoint City": "雪峰市",
    "Sunyshore City": "滨海市",
    "Pokemon League": "宝可梦联盟",
    "Pokémon League": "宝可梦联盟",
    "Mt. Coronet": "天冠山",
    "Lake Verity": "心齐湖",
    "Lake Valor": "立志湖",
    "Lake Acuity": "睿智湖",
    "Spear Pillar": "枪之柱",
    "Distortion World": "毁坏的世界",
    "Stark Mountain": "严酷山",
    "Iron Island": "钢铁岛",
    "Eterna Forest": "百代森林",
    "Lost Tower": "迷失塔",
    "Wayward Cave": "迷幻洞窟",
    "Great Marsh": "大湿地",
    "Valor Lakefront": "立志湖畔",
    "Acuity Lakefront": "睿智湖畔",
    "Sendoff Spring": "送行之泉",
    "Turnback Cave": "归来洞",
    "Newmoon Island": "新月岛",
    "Fullmoon Island": "满月岛",
    "Flower Paradise": "花之乐园",
    "Snowpoint Temple": "雪峰神殿",
    "Pal Park": "伙伴公园",
    "Aspertia City": "桧扇市",
    "Floccesy Town": "唐草镇",
    "Virbank City": "立涌市",
    "Accumula Town": "唐草镇",
    "Striaton City": "三曜市",
    "Nacrene City": "七宝市",
    "Castelia City": "飞云市",
    "Nimbasa City": "雷文市",
    "Driftveil City": "帆巴市",
    "Mistralton City": "吹寄市",
    "Icirrus City": "雪花市",
    "Opelucid City": "双龙市",
    "Lacunosa Town": "雪花镇",
    "Undella Town": "青海波市",
    "Black City": "黑之市",
    "White Forest": "白之森林",
    "Pinwheel Forest": "矢车森林",
    "Wellspring Cave": "泉源洞窟",
    "Twist Mountain": "螺旋山",
    "Mistralton Cave": "吹寄洞穴",
    "Chargestone Cave": "电气石洞穴",
    "Dragonspiral Tower": "龙螺旋之塔",
    "Relic Castle": "古代城",
    "Lostlorn Forest": "迷幻森林",
    "Abundant Shrine": "丰饶神社",
    "Giant Chasm": "巨人洞窟",
    "Undella Bay": "青海波湾",
    "Liberty Garden": "自由花园",
    "P2 Laboratory": "P2实验室",
    "Unity Tower": "联合塔",
    "Littleroot Town": "未白镇",
    "Oldale Town": "古辰镇",
    "Petalburg City": "橙华市",
    "Rustboro City": "卡那兹市",
    "Dewford Town": "武斗镇",
    "Slateport City": "凯那市",
    "Mauville City": "紫堇市",
    "Verdanturf Town": "绿荫镇",
    "Fallarbor Town": "釜炎镇",
    "Lavaridge Town": "釜炎镇",
    "Fortree City": "茵郁市",
    "Lilycove City": "水静市",
    "Mossdeep City": "绿岭市",
    "Sootopolis City": "琉璃市",
    "Pacifidlog Town": "暮水镇",
    "Ever Grande City": "彩幽市",
    "Petalburg Woods": "橙华森林",
    "Rusturf Tunnel": "卡绿隧道",
    "Granite Cave": "石之洞窟",
    "Mt. Pyre": "送神山",
    "Jagged Pass": "凹凸山道",
    "Fiery Path": "烈焰小径",
    "Meteor Falls": "流星瀑布",
    "Seafloor Cavern": "海底洞窟",
    "Cave of Origin": "觉醒之祠",
    "Sky Pillar": "天空之柱",
    "Shoal Cave": "浅滩洞穴",
    "New Mauville": "新紫堇",
    "Mirage Tower": "幻影塔",
    "Desert Underpass": "沙漠地下通道",
    "Artisan Cave": "工匠之穴",
    "Altering Cave": "变化洞窟",
    "Birth Island": "诞生岛",
    "Southern Island": "南方小岛",
    "Faraway Island": "边境的小岛",
    "Vaniville Town": "鹿子镇",
    "Accumula Town": "唐草镇",
    "Nuvema Town": "鹿子镇",
    "Santalune City": "白檀市",
    "Camphrier Town": "美川镇",
    "Cyllage City": "比翼市",
    "Ambrette Town": "遥香镇",
    "Geosenge Town": "石镇",
    "Shalour City": "娑罗市",
    "Coumarine City": "海翼市",
    "Laverre City": "香薰市",
    "Anistar City": "映雪市",
    "Couriway Town": "水涟镇",
    "Snowbelle City": "冰雪镇",
    "Kiloude City": "奇楠市",
    "Lumiose City": "密阿雷市",
    "Parfum Palace": "巴摩拉宫",
    "Santalune Forest": "白檀森林",
    "Glittering Cave": "闪耀洞窟",
    "Reflection Cave": "镜之洞窟",
    "Tower of Mastery": "精通塔",
    "Azure Bay": "蓝色海湾",
    "Lost Hotel": "废弃酒店",
    "Frost Cavern": "冰霜洞窟",
    "Terminus Cave": "终焉之穴",
    "Pokémon Village": "宝可梦村",
    "Alola Route 1": "1号道路",
    "Iki Town": "好奥花市",
    "Hau'oli City": "好奥花市",
    "Heahea City": "慷概市",
    "Paniola Town": "欧雷吉镇",
    "Konikoni City": "阿卡拉岛",
    "Aether Paradise": "以太乐园",
    "Mount Lanakila": "拉纳基拉山",
    "Seafolk Village": "海洋居民村",
    "Tapu Village": "卡璞村",
    "Postwick": "化朗镇",
    "Wedgehurst": "化朗镇",
    "Motostoke": "机擎市",
    "Turffield": "草路镇",
    "Hulbury": "水舟镇",
    "Hammerlocke": "拳关市",
    "Glimwood Tangle": "迷光森林",
    "Ballonlea": "迷光森林",
    "Spikemuth": "尖钉镇",
    "Circhester": "战竞镇",
    "Hearthome": "战竞镇",
    "Hammerlocke Hills": "拳关丘陵",
    "Wyndon": "宫门市",
    "Slumbering Weald": "迷之森林",
    "Galar Mine": "伽勒尔矿坑",
    "Galar Mine No. 2": "伽勒尔矿坑2",
    "Watchtower Ruins": "瞭望塔遗迹",
    "Stow-on-Side": "战竞镇",
    "Route 5": "5号道路",
    "Route 6": "6号道路",
    "Route 7": "7号道路",
    "Route 8": "8号道路",
    "Route 9": "9号道路",
    "Route 10": "10号道路",
    "Route 11": "11号道路",
    "Route 12": "12号道路",
    "Route 13": "13号道路",
    "Route 14": "14号道路",
    "Route 15": "15号道路",
    "Route 16": "16号道路",
    "Route 17": "17号道路",
    "Route 18": "18号道路",
    "Route 19": "19号道路",
    "Route 20": "20号道路",
    "Route 21": "21号道路",
    "Route 22": "22号道路",
    "Route 23": "23号道路",
    "Route 24": "24号道路",
    "Route 25": "25号道路",
    "Route 26": "26号道路",
    "Route 27": "27号道路",
    "Route 28": "28号道路",
    "Route 29": "29号道路",
    "Route 30": "30号道路",
    "Route 31": "31号道路",
    "Route 32": "32号道路",
    "Route 33": "33号道路",
    "Route 34": "34号道路",
    "Route 35": "35号道路",
    "Route 36": "36号道路",
    "Route 37": "37号道路",
    "Route 38": "38号道路",
    "Route 39": "39号道路",
    "Route 40": "40号道路",
    "Route 41": "41号道路",
    "Route 42": "42号道路",
    "Route 43": "43号道路",
    "Route 44": "44号道路",
    "Route 45": "45号道路",
    "Route 46": "46号道路",
    "Route 47": "47号道路",
    "Route 48": "48号道路",
    "Mesagoza": "桌台市",
    "Cabo Poco": "深钵镇",
    "Los Platos": "深钵镇",
    "Artazon": "深钵镇",
    "Levincia": "酿光市",
    "Porto Marinada": "玻瓶市",
    "Medali": "酿光市",
    "Montenevera": "霜抹山",
    "Alfornada": "深钵镇",
    "Casseroya Lake": "大锅湖",
    "Area Zero": "第零区",
    "Paldea": "帕底亚",
    "Kitakami": "北上",
    "Blueberry Academy": "蓝莓学园",
}

FLOOR_SUFFIX = re.compile(
    r"^(?P<base>.+?)(?:\s+(?P<floor>(?:B?\d+F|basement|inside|outside|entrance|area \d+)))$",
    re.IGNORECASE,
)


def _load_json_dict(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return {}
    return {str(k): str(v) for k, v in data.items()}


def load_slug_overrides() -> dict[str, str]:
    merged = dict(DEFAULT_SLUG_OVERRIDES)
    merged.update(_load_json_dict(OVERRIDE_PATH))
    return merged


def load_location_names_en_zh() -> dict[str, str]:
    merged = dict(DEFAULT_LOCATION_NAMES_EN_ZH)
    try:
        from location_names_bulk import BULK_LOCATION_NAMES_EN_ZH  # noqa: WPS433

        merged.update(BULK_LOCATION_NAMES_EN_ZH)
    except ImportError:
        pass
    merged.update(_load_json_dict(SEED_PATH))
    return merged


def _format_floor(floor: str) -> str:
    floor = floor.strip()
    upper = floor.upper()
    if re.fullmatch(r"B?\d+F", upper):
        return upper.replace("B", "B").replace("F", "F")
    mapping = {
        "basement": "地下室",
        "inside": "内部",
        "outside": "外部",
        "entrance": "入口",
    }
    return mapping.get(floor.lower(), floor)


def _route_from_slug(slug: str) -> str | None:
    match = re.match(r"^route-(\d+)-", slug)
    if match:
        return f"{match.group(1)}号道路"
    return None


def _route_from_english(name: str) -> str | None:
    match = re.fullmatch(r"Route (\d+)", name.strip())
    if match:
        return f"{match.group(1)}号道路"
    return None


def _slug_to_title(slug: str) -> str:
    cleaned = slug.replace("-area", "").replace("-", " ")
    return " ".join(part.capitalize() for part in cleaned.split())


def _append_floor(base_zh: str, floor_token: str | None) -> str:
    if not floor_token:
        return base_zh
    floor = _format_floor(floor_token)
    if re.fullmatch(r"B?\d+F", floor.upper()):
        return f"{base_zh} {floor.upper()}"
    return f"{base_zh} · {floor}"


def _floor_from_slug(slug: str) -> tuple[str | None, str | None]:
    """Return (base_slug, floor_token) for sub-area slugs like ice-path-b1f."""
    b_match = re.match(r"^(?P<base>.+)-b(?P<num>\d+)f$", slug)
    if b_match:
        return b_match.group("base"), f"B{b_match.group('num')}F"
    f_match = re.match(r"^(?P<base>.+)-(?P<num>\d+)f$", slug)
    if f_match:
        return f_match.group("base"), f"{f_match.group('num')}F"
    inside = re.match(r"^(?P<base>.+)-(inside|outside|entrance)$", slug)
    if inside:
        return inside.group("base"), inside.group(2)
    return None, None


def _composite_location_zh(name_en: str, names_en_zh: dict[str, str]) -> str | None:
    """Try 'Solaceon Ruins' → 随意镇 + 遗迹 when base town is known."""
    if name_en in names_en_zh:
        return names_en_zh[name_en]
    for suffix, suffix_zh in (
        (" Ruins", "遗迹"),
        (" Cave", "洞窟"),
        (" Forest", "森林"),
        (" Tunnel", "隧道"),
        (" Path", "小径"),
        (" Tower", "塔"),
        (" Lake", "湖"),
        (" Mountain", "山"),
        (" Mine", "矿坑"),
        (" Gate", "闸口"),
        (" Garden", "花园"),
        (" Island", "岛"),
        (" Beach", "海滩"),
        (" Shore", "海岸"),
        (" Wastes", "荒原"),
        (" Hill", "山丘"),
        (" Quarry", "采石场"),
        (" Lagoon", "泻湖"),
        (" Arena", "竞技场"),
        (" Resort", "度假地"),
        (" Fields", "原野"),
        (" Sewers", "下水道"),
        (" Temple", "神殿"),
        (" Shrine", "神社"),
        (" Plateau", "高原"),
        (" Canyon", "峡谷"),
        (" Volcano", "火山"),
        (" Desert", "沙漠"),
    ):
        if name_en.endswith(suffix):
            base = name_en[: -len(suffix)]
            base_zh = names_en_zh.get(base)
            if base_zh:
                return f"{base_zh}{suffix_zh}"
    return None


def resolve_location_area_zh(
    slug: str,
    *,
    area_name_en: str | None = None,
    location_name_en: str | None = None,
    slug_overrides: dict[str, str] | None = None,
    names_en_zh: dict[str, str] | None = None,
) -> tuple[str, str]:
    """Return (label_zh, source) where source explains resolution tier."""
    slug_overrides = slug_overrides or load_slug_overrides()
    names_en_zh = names_en_zh or load_location_names_en_zh()

    if slug in slug_overrides:
        return slug_overrides[slug], "slug_override"

    route = _route_from_slug(slug)
    if route:
        return route, "route_slug"

    if area_name_en:
        route_en = _route_from_english(area_name_en)
        if route_en:
            return route_en, "route_en"

    for candidate in (area_name_en, location_name_en):
        if not candidate:
            continue
        composite = _composite_location_zh(candidate, names_en_zh)
        if composite:
            return composite, "composite_en"
        if candidate in names_en_zh:
            return names_en_zh[candidate], "name_en"

    if area_name_en:
        floor_match = FLOOR_SUFFIX.match(area_name_en)
        if floor_match:
            base = floor_match.group("base")
            floor = floor_match.group("floor")
            if base in names_en_zh:
                return _append_floor(names_en_zh[base], floor), "name_en_floor"

    base_slug, floor_token = _floor_from_slug(slug)
    if base_slug:
        base_slug_area = f"{base_slug}-area" if not base_slug.endswith("-area") else base_slug
        if base_slug_area in slug_overrides:
            return _append_floor(slug_overrides[base_slug_area], floor_token), "slug_floor"
        if base_slug in slug_overrides:
            return _append_floor(slug_overrides[base_slug], floor_token), "slug_floor"
        title = _slug_to_title(base_slug)
        if title in names_en_zh:
            return _append_floor(names_en_zh[title], floor_token), "slug_floor_name"

    for candidate in (location_name_en, area_name_en):
        if candidate:
            return candidate, "english_fallback"

    title = _slug_to_title(slug)
    if title in names_en_zh:
        return names_en_zh[title], "slug_title_name"

    return title, "slug_title"
