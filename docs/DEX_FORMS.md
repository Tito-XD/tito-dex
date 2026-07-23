# 图鉴形态数据

TitoDex 的全国图鉴仍以 1–1025 的“种”为主索引；同一全国编号下的差异记录为
`forms`。形态可以被检索，并在详情页切换。切换后会一起替换属性、种族值、特性、
招式、身高体重、出现地点和图片，而不是只换名称或立绘。

## 收录边界

构建器读取 `pokemon-species.varieties`，再解析每个 variety 对应的 `pokemon` 与其
全部 `pokemon-form` 资源。只有实际存在两个以上记录时才写 `forms`；单形态物种不会
生成无意义的默认 form。默认形态复用物种已构建的招式、特性和地点，避免重复请求。
目前按以下规则归类：

- `regional`：阿罗拉、伽勒尔、洗翠、帕底亚地区形态。
- `mega`：超级进化与 X/Y、Z 等分支；原始回归保留为特殊形态。
- `gigantamax`：超极巨化形态。
- `battle`：只能在战斗中维持的转换，例如美洛耶塔舞步形态、基格尔德完全体。
- `form`：能常驻或有独立战斗资料的其他形态。
- `cosmetic`：属性、种族值、特性、招式、身高和体重均与默认形态相同的外观差异。

这套模型会覆盖常见但容易遗漏的情况：

- 地区形态及其独立进化（乌波、火暴兽等）。
- 雌雄会改变战斗资料的形态（超能妙喵、爱管侍等）；仅外观不同的雌雄差异归入
  `cosmetic`。
- 洛托姆、代欧奇希斯、骑拉帝纳、谢米、达摩狒狒、酋雷姆、凯路迪欧、
  美洛耶塔、盖诺赛克特、甲贺忍蛙、坚盾剑怪、胡帕、鬃岩狼人、弱丁鱼、
  银伴战兽、奈克洛兹玛、颤弦蝾螈、怖思壶真伪、霜奶仙、冰砌鹅、莫鲁贝可、
  苍响/藏玛然特、武道熊师、蕾冠王合体、眷恋云、海豚侠、一家鼠、土龙节节、
  厄诡椪面具与太晶形态、太乐巴戈斯等特殊分支。
- 图腾、永恒之躯等 PokeAPI 已作为独立 variety 提供的特殊记录；是否能正常获得由
  `isBattleOnly`、出现地点及游戏版本数据共同表达。
- 花纹、颜色、帽子、修剪造型、大小等外观差异仍可搜索，但默认折叠在同一全国编号。

## 不展开为形态的状态

普通太晶属性、普通极巨化、头目/霸主尺寸、闪光、性格、个体值和携带物属于个体或
战斗状态。尤其不能为每只宝可梦生成 18 个太晶副本。厄诡椪与太乐巴戈斯这类确有
独立资料的太晶形态仍按独立 form 收录。

基格尔德收录 10%、50% 与完全体。细胞和核心是组成单位，不是可作为宝可梦使用的
“1%形态”，因此不生成虚构的 1%记录。

## 出现地点身份

每条地点记录使用 `speciesId + pokemonId + formKey` 关联具体形态。资料源只能确认物种
或同一 Pokémon entity 下有多个外观 form 时，记录改为 `formAmbiguous: true`，界面
显示“形态未区分”。固定太晶、头目、霸主、图腾、团体战和固定刷新分别保存在
`teraType` 与 encounter 状态字段，不制造额外图鉴形态。形态同时保存版本组与精确
版本两层地点映射。

bundle manifest 以 `schemaFeatures.pokemonForms = 2` 和
`schemaFeatures.encounterFormIdentity = 3`、`schemaFeatures.exactVersionLocations = 1`
显式声明能力。离线压缩包和上传目录包含全部形态 JSON；只有非外观且视觉确实不同、
同时拥有可靠来源图片的形态才写一张 `sprites/forms/` 小图。外观重复形态复用默认小图，
形态高清 artwork 不批量复制；没有可靠图片时字段留空。

## 现代游戏地点 overlay

PokeAPI 缺少现代主机作品的完整 encounter 表。bundle v6 使用 PKHeX 固定提交
`5c9e949c9f0fa932a1b63511b32c2bee5ce75b4e` 的规范化派生数据补齐 BDSP、阿尔宙斯、
剑盾及 DLC、朱紫及 DLC、Z-A 与“超次元爆涌”。生成器、GPL-3.0-or-later 说明、来源
提交与产物均保存在仓库；App 不嵌入或执行 PKHeX 程序。

`data/forms/pkhex_encounter_mappings.json` 将 PKHeX `species + form index/name`
确定性映射到 PokeAPI `pokemonId + formKey`。唯一匹配才写具体形态；不能确认的记录只保留
`speciesId` 并标记 `formAmbiguous`。当前剩余歧义是 PKHeX 以随机 form index 表示、无法
确定核心颜色的小陨星记录，不能归给默认形态。

导入范围只含可捕获的野外、固定、团体战、大量出现、头目和霸主记录；交换、赠送、蛋、
固定精灵球取得及不可捕获剧情记录排除。Champions 没有野外捕获语义，在 manifest 中标为
`notApplicable`。

## 数据新鲜度

PokeAPI 尚未收录的新作形态不能用旧形态的种族值、特性或图片冒充。新增游戏发布后，
先核对官方形态名称/属性，再等待或补齐可验证的战斗资料与离线图片。资料不完整时应
明确留空，而不是继承默认形态的战斗数据。当前需要重点审计《宝可梦传说 Z-A》及
“超次元爆涌”新增的超级进化。

2026-07-22 复核时，官方目录列出的 18 个 Z-A / Mega Dimension 新 Mega 均已拥有
PokeAPI Pokémon endpoint，并已链接进相应 species 的 `varieties`，因此由正常构建器
收录，不启用手工覆盖。状态记录在 `data/forms/overrides.json`；后续新增而上游未收录的
形态先进入 `pendingForms`，资料与独立图片齐全后才可转为有效覆盖。

自动审计：

```bash
python3 tools/audit_form_coverage.py <bundle-root> --strict --pokeapi
python3 tools/audit_encounter_coverage.py <bundle-root> --strict
python3 tools/audit_dex_golden_samples.py <bundle-root> --strict
python3 tools/verify_dex_upload_tree.py dist/dex-v6/upload
```

金样本覆盖皮卡丘、喷火龙 Mega X/Y 与超极巨、洛托姆、帕底亚乌波、洗翠火暴兽、
美洛耶塔、基格尔德 10%/50%/完全体、南瓜精、超能妙喵、爱管侍、奈克洛兹玛、蕾冠王、
厄诡椪、太乐巴戈斯、霜奶仙、彩粉蝶和不可穷举的晃晃斑，并额外要求太晶、头目、团体战、
固定刷新和形态未区分记录至少各有有效样本。

核对入口：

- PokeAPI 数据模型：<https://pokeapi.co/docs/v2#pokemon-species>、
  <https://pokeapi.co/docs/v2#pokemon-forms>
- 《宝可梦传说 Z-A》官方宝可梦目录：
  <https://legends.pokemon.com/en-us/story-world/pokemon>
- “超次元爆涌”官方目录：<https://legends.pokemon.com/en-us/dlc>
