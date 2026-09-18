# TitoDex Design System

TitoDex uses a warm, compact, modern-retro trainer-device language that remains readable on Android phones and handheld displays. Its personality should be recognizable without depending on private user information.

**Implementation:** Active design tokens live in `flutter/lib/theme/`. The
pre-Flutter React mock was removed in v0.6.5; values below document the Flutter
implementation rather than a second UI stack. Architecture boundaries live in
[ARCHITECTURE.md](./ARCHITECTURE.md).

## Design Personality

Keywords:

- warm device UI
- modern retro
- sticker UI
- playthrough progress
- compact
- friendly
- companion-like
- soft but sturdy

## Theme and skin names

Theme names are localized labels, not technology claims. Never show a
Chinese/English slash pair in the UI: Chinese locales use the Chinese column;
all other locales currently use the English column until broader localization
lands.

| Identity | 中文 | English | Implementation |
| --- | --- | --- | --- |
| Default sticker language | 训练家手帐 | Trainer's Journal | Base app / built-in classic option |
| Glass-inspired experiment | 固态塑料 | Solid Plastic | Built-in option, adapted from `codex/liquid-glass-ui` |
| Flat native experiment | 扁平贴纸 | Flat UI | `codex/material-ui-native`; built-in option beside 训练家手帐 |

The deliberately playful names describe the perceived texture. In particular,
“Solid Plastic” replaces the earlier Liquid Glass working label, while “Flat
UI” replaces Material 3 as the user-facing name. Internal Flutter `Material`
classes may still be used as implementation primitives.

## Color Direction

Use a blue-gray, cream, and deep-navy base with warm accent colors.

Suggested tokens, aligned with the supplied UI reference:

```css
:root {
  --color-deep-blue: #2f4361;
  --color-slate-blue: #7b91a6;
  --color-sky-blue: #afc7da;
  --color-cream: #f3e4b3;
  --color-coral: #ff8f6a;
  --color-ink: #221f26;
  --color-soft-yellow: #f7d977;
  --color-card: #fff7e6;
  --color-muted-ink: #536273;
}
```

Color usage:

- Cream: app background and card warmth. Trainer's Journal paper is a
  slightly lighter cream (`#FFF9ED`) than the shared card token.
- Blue gray: device shell, panels, secondary surfaces.
- Deep navy: text and top-level contrast. Trainer's Journal outlines use a
  softer gray-blue (`#7C8999`) instead of near-black ink.
- Soft yellow: friendly highlights, badge glow.
- Coral: sparing call-to-action accent.
- Mint: success / gentle progress.

## Shape and Surface

- rounded cards
- sticker-like offsets
- badge pills
- panel seams like a small handheld device
- **Trainer's Journal** uses a thin gray-blue outline and a short paper-edge
  shadow. **Solid Plastic** keeps moulded blurred depth. **Flat UI** keeps
  soft Material elevation. Journal press-down is a 1px sink; Plastic keeps
  the 3px physical key press.

Tokens (`flutter/lib/theme/tito_colors.dart` and
`flutter/lib/theme/trainer_journal.dart`, values are what ships):

| Token | Value | Use |
| --- | ---: | --- |
| `TitoRadii.sm` | 8 | chips, pills, tabs, badges, segmented buttons, list tiles |
| `TitoRadii.md` | 12 | buttons, text fields, menus, snack bars |
| `TitoRadii.lg` | 16 | cards; sheets and dialogs in Trainer's Journal |
| `TitoRadii.xl` | 28 | sheets and dialogs in Solid Plastic / Flat UI |
| `TitoBorders.card` | 2.0 | Flat UI / historical card outline |
| `TitoBorders.element` | 1.5 | Flat UI / historical small-control outline |
| `TitoBorders.journalCard` | 1.25 | Trainer's Journal cards, buttons, fields, sheets, dialogs |
| `TitoBorders.journalElement` | 0.85 | Trainer's Journal chips, badges, small controls |
| `TitoBorders.journalHairline` | 0.75 | Trainer's Journal empty-slot dashes |
| `TitoBorders.glass` | 1.1 | Solid Plastic light hairline (`LiquidGlassSurface`) |

Radii are fixed on every device: read `TitoRadii.sm/md/lg` directly. The
old `DeviceLayout` identity helpers and font multiplier have been removed. Never write a literal outline
width in a widget — pick the token that matches the surface size. Font sizes
stay on the existing `TitoTypography` / `DeviceLayout` rules in every theme;
Trainer's Journal only remaps weight and the shared ink/muted colours.

Shadow recipes are per theme and never mixed:

| Theme | Recipe | Cards / buttons | Chips / sprites | Pressed |
| --- | --- | --- | --- | --- |
| Trainer's Journal | `TrainerJournalShadows` — hard, no blur | paper lip `0 2px` + faint `0 3px`; controls `0 2px` | none | `0 1px 0` |
| Solid Plastic | `SolidPlasticShadows` — moulded, blurred | `0 8px 16px` + `0 2px 3px` | `0 5px 11px` | `0 2px 7px` |
| Flat UI | `TitoShadows` — soft Material elevation (**Flat UI only**) | `0 2px 8px` | `0 1px 4px` | `0 1px 3px` |

Stock Material surfaces (`AlertDialog`, bottom sheets, `Divider`, chips,
menus, segmented buttons, list tiles, checkbox/radio) are styled purely by the
`ThemeData` built in `tito_theme.dart` for each style. Do not re-style them at
call sites: a plain `AlertDialog`, `showModalBottomSheet` (drag handle on) and
`Divider()` already look right in every theme.

## Selection colours

| Control | Selected colour | Notes |
| --- | --- | --- |
| Single choice drawn as segments / tabs / custom method chips | `softYellow` | one active option at a time (`SegmentedButton`, detail move-method chips, stats toggle) |
| Any Material chip (`FilterChip`, `ChoiceChip`, `InputChip`) and toggles | `mint` | `ChipThemeData` is shared by every chip class, so single-choice chip groups (weather, terrain, status…) also select in mint — do not fight it with local `selectedColor` |
| Detail bottom tabs | primary type colour sliding indicator | one continuous cream rail; intentional palette exception across themes |
| Flat UI (all of the above) | `colorScheme.secondaryContainer` | Material semantics, no cream/yellow |
| Battle calculator mode bar | `TitoSurfaceRole.card` on a `deep` rail | four connected segments, shared outline and separators; each theme supplies its own surface recipe |

Coral is reserved for destructive actions, warnings and the primary CTA — never
as a selection highlight.

### 对战工具布局

克制、能力值、伤害、盲点共用一体式分段导航和同一组攻守双方配置，滚动状态各自保留。
四页按「范围切换 → 完整结果 → 参数」整页连续滚动，结果和参数共用一个纵向列表。
完整结果离开视野后，顶部出现可点击的一行摘要；240ms 缓出展开并渐显，回看时
180ms 收起淡出，页面以 380ms 缓入缓出回到完整结果。摘要浮层不改变输入区位置，
边界留有回滞以避免慢速滚动时闪烁；系统减少动画时直接切换。长表和大字不再
限高或套第二个纵向滚动区。输入聚焦留出摘要所需空间。
工具导航和「攻守双方／整队」共用轻薄的分段控件，外框圆角 12、滑块圆角 8，左右与下方卡片齐平，触摸高度至少 44；
选中背景以 280ms 滑动，工具与范围切换伴随 220ms 淡入，并遵循减少动态效果设置。
卡片和输入框沿用原圆角层级，色彩与描边仍由三套主题各自提供。
图鉴详情底栏复用 `TitoSegmentedControl`，整条奶油白底配当前形态主属性色滑块，
底栏浮于连续滚动内容上，以轻阴影和 8px 底部留白保留悬浮感。背景遮罩从导航条上沿开始，由透明向底部页面底色渐变；底栏上方内容保持清晰，经过底栏后方时逐渐隐去。列表末尾为底栏预留空间，确保最后一张卡片可完整阅读。
内容沿用淡入和高度过渡；两处共享滑动、文字颜色过渡、居中和减少动态效果规则。

克制表按实际倍率分组，包含中性、抗性和免疫；特性产生的 1.5×、0.75× 等
数值也单独显示，不归并为整数倍率。盲点页的打击盲点、联防盲点均显示在顶部。
克制、伤害、盲点的配置固定为左进攻方、右防守方；能力值页可切换编辑哪一方，
数值字段按两列排布。特性、道具、状态采用紧凑选择框，伤害页的额外修正默认折叠。

`BattleSession` 随工具页创建和释放，不写回队伍；双方分别保存六项种族值、IV、EV、
等级、性格、特性、太晶状态及计算用道具和状态。切页自动代入，物理／特殊招式分别
读取对应能力。伤害页使用加成前数值，避免重复应用特性、道具和状态；手填能力值
会标记为覆盖值，修改对应培养参数或点击恢复后重新计算。

四页均可从队伍快速选择，攻守双方独立。存档 IV／EV 按 HP、攻击、防御、速度、
特攻、特防顺序映射；缺失参数明确提示默认值。未建立跨世代 ID 映射的存档道具
不会自动猜测，提示用户在更多选项中选择。队伍原数据保持不变。

克制／盲点可切换「整队分析」：共同弱点为至少两名成员受击超过 1×，抗性与免疫
分别统计人数；打击盲点沿用本系属性对单属性目标的估算，不等于实际配招覆盖，
不计太晶化。分析默认代入已保存队伍，之后使用本次工具会话的临时队伍，展示已读取人数及未知特性提示。

四页共享「攻守双方／整队分析」范围。能力值的整队模式按已保存培养参数横向比较
六项能力值；伤害整队模式逐个队员读取已配招式，针对当前共享防守方计算，分别
使用物攻／物防和特攻／特防。默认显示每名队员最高伤害的招式，展开可查看全部。
变化招式、未支持的特殊条件、晚于当前世代的招式和缺失数据均明确标注，不编造
结果。单体与队伍的招式选择仅提供所选宝可梦在当前游戏的可学招式，不跨版本回退；
选中后读取当前世代的属性、分类、威力及接触标记；单只与整队共用计算入口。
存档中不属于当前可学集合的招式不参与估算。未识别道具须先确认；已支持的特殊取值、
固定伤害、属性与特性联动及近似边界见 [计算范围](BATTLE_CALCULATION_SCOPE.md)。
队伍区采用紧凑的三列两行 `BattleTeamEditor`：直接展示等级、性格、特性、IV／EV 摘要与招式；
点选可替换成员、修改六项种族值／IV／EV、性格、特性、道具、状态和最多四个招式，空位可添加，成员可移除。
四页共享临时修改，不写回 Party。选择弹层仍复用 `PartyTeamBoard`，窄屏与大字适配行高；
菜单明确采用浅色卡片背景，深色结果卡上的操作文字采用浅色前景。

`flutter test test/battle_session_test.dart test/battle_party_damage_test.dart test/battle_tools_layout_test.dart` 验证三套主题、
窄屏、掌机、英文大字、键盘、跨页同步、队员导入、异步选择及整队统计。可选传入
`--dart-define=UI_AUDIT_CJK_FONT=<本地中文字体路径>`，在 `flutter/build/battle-audit/`
生成四页的测试数据截图；这些截图不等同于 APK 或真机验收。

## Text tokens

| Where the text sits | Token |
| --- | --- |
| Page level, directly on the shell / gradient | `SecondaryTypography.onPage(context)` (theme-aware) |
| Deep card (deepBlue, slate, gradient fills) | `SecondaryTypography.onGradient` (cream) |
| Cream / sky / mint card | `SecondaryTypography.onCard` (ink) |

`onGradient` is a fixed cream and does not adapt to Flat UI; use `onPage` for
anything that is not inside a deep card.

## Loading indicators

| Situation | Widget |
| --- | --- |
| Determinate progress (downloads, installs, sync) | `TitoProgressBar` |
| Whole section / page waiting | `TitoLoadingPanel` or `TitoPokeballLoading` |
| Image / sprite placeholder | `TitoSkeletonBox` |

No bare `CircularProgressIndicator` in feature code.

## Theme-blind components are bugs

共享表面通过 `Theme.of(context).extension<TitoSurfaceTokens>()` 获取令牌，
不要在组件中重复全局三主题的 fill / outline / shadow 判断。
`buildTitoTheme` 为三套主题分别注册扩展；`StickerCard`、`StickerPressable`、
表单、队伍槽、属性/状态徽章、详情控件、骨架与进度条读取同一来源。
塑料光学层、Material 控件与手帐专属装饰仍保留各自的渲染方式；
主题特有的布局、字体、插画和业务状态颜色不属于通用表面令牌。

### 共享表面令牌与导出

- 源码：`flutter/lib/theme/tito_surface_tokens.dart`；基础色、阴影与尺寸引用现有主题常量。
- 对照表：[`design-tokens.json`](design-tokens.json)，由真实 `buildTitoTheme` 实例生成，禁止手改数值。
- 核心字段：`cardFill`、`cardOutline`（颜色、宽度）、`cardShadow`、`elementOutline`、`pressSink`。
- `surfaces` 包含卡片变体、输入框、队伍槽、徽章、选中态等语义角色。
- 颜色格式为 CSS `#RRGGBBAA`（不是 Flutter 的 AARRGGBB）；尺寸使用逻辑像素 / CSS px。
- 塑料表面的 `fill` 是光学渲染底色，`opacity` 是其透明度参数；JSON 不替代光学渲染器。
- `retroStyle` 仍控制阴影与按压；JSON 表示开启深度时的配方，Flat 关闭深度时读 `flatCardOutline`。
- 外壳两端颜色统一为 `TitoColors.shellGradientTop/Bottom`，页面和设备外壳共用。

在 `flutter/` 下执行：

```sh
flutter test --no-pub test/design_tokens_test.dart --dart-define=EXPORT_DESIGN_TOKENS=true
flutter test --no-pub test/design_tokens_test.dart
```

第二条命令及完整测试会校验 JSON 与运行时令牌一致，并验证局部 Theme 覆盖、
`copyWith` 和跨主题插值。Web 端可消费该生成表或与其核对，本次没有修改 Web 仓库。

UI 回归与可选截图：

```sh
flutter test --no-pub test/ui_surface_audit_test.dart
flutter test --no-pub test/ui_surface_audit_test.dart --dart-define=UI_AUDIT_CJK_FONT=C:/Windows/Fonts/msyh.ttc
```

截图输出至 `flutter/build/ui-audit/`，使用离线测试条目、精灵占位图及仅在测试
宿主注册的中文字体回退，覆盖三套主题的图鉴、详情四个 Tab、设置总览和外观页。
这些是 Flutter 测试引擎渲染，不是 Android 真机截图。实际设备仍需检查捕获对勾、
状态文字、塑料徽章以及页面滚动和点按。

`_PreviewShell` 经检索仍由 Web 入口调用，因此保留实际实现并移除错误的 legacy
alias 注释；它不是死代码。

### Retro sticker feel (Flutter implementation)

Settings → 界面风格 → **Retro 贴纸手感** (default on) drives the whole
package through `retroStyle`:

- `TrainerJournalShadows.sticker` (paper lip) on cream cards, `.control`
  (0/2px) on buttons and quick tiles, `.stickerSmall` empty on chips/sprites,
  `.stickerPressed` (0/1px) while held. Solid Plastic swaps in
  `SolidPlasticShadows`; Flat UI uses `TitoShadows`.
- `StickerPressable` wraps interactive stickers: Journal sinks 1px in ~80ms;
  Solid Plastic keeps the 3px physical key. `ownShadow: false` gives
  sink-only physics when the inner `StickerCard` already paints the drop.
- Headings tighten to `letter-spacing: -0.02em` (applies in both modes).
- Toggle off = pure flat stickers; every shadow and press effect gates on
  `retroStyle.enabled` and switches live.

## Typography

Bundled Nunito and `SecondaryTypography` provide the fixed comfort baseline for
secondary routes. These sizes do not multiply by `handheldUiScale`:

| Tier | px | Token | Typical use |
| --- | ---: | --- | --- |
| Page title | 22.5 | `onGradient.title` | Secondary app bars |
| Section | 15 | `onCard.h15` / `onGradient.h15` | Card headings |
| Body | 14 | `onCard.body14` | Descriptions and paths |
| Meta | 14 | `onCard.meta14` | Counts, values and tabs |
| Small | 12 | `small12` / `team12` | Hints, HP/EXP and compact labels |

Dex, Team, Journey, Search, Settings and battle/Sleep tools use this hierarchy.
Trainer's Journal remaps Nunito weights one step lighter (body Regular 400,
labels SemiBold 600, titles Bold 700) because the bundled files have no
Medium cut. Sizes stay the same in every theme.
The Home dashboard intentionally stays larger for glanceability: its title is
layout-driven near 33 px, quick tiles own explicit sizes, and trainer details
may use `homeDetailMultiplier`. `TitoFontScale` is retired; layout dimensions
and body type must not share an inherited multiplier.

## Layout and system UI

| Device | System UI | Header status | Home composition |
| --- | --- | --- | --- |
| Handheld panel around 1:1 / 3:4 / 4:3 | Immersive | TitoDex Wi-Fi/battery | Square or short-landscape dashboard |
| Regular phone/tablet | Native status/navigation bars | OS chrome | Portrait stack or wide rows |

`DeviceLayout`, `SystemUiCoordinator` and `DeviceShell` own that split. Regular
phones must not use immersive sticky. Web keeps the mock device frame for
preview only. The handheld gradient remains full bleed, while page content
keeps a small 6 px top/bottom optical inset because immersive mode removes the
system status and gesture-bar safe areas.

`HomeDashboardBody` has three explicit compositions:

| Composition | Condition | Shape |
| --- | --- | --- |
| Portrait | Non-square portrait | trainer → journey → party → quick actions |
| Horizontal | Square or landscape under 560 px tall | trainer/journey beside party |
| Wide rows | Non-square landscape at least 560 px tall | natural-height top row plus capped party strip |

`PartyStrip` always renders six slots: portrait uses 3×2 horizontal cells,
save-linked square/short landscape uses 2×3 upright cells, and no-save/wide-row
layouts use a centered 6×1 strip. Callers select the mode explicitly rather
than inferring it from width. The header game pill opens the 3–4 column edition
grid and always retains a text fallback for missing icons.

## Home Screen Composition

The home screen should prioritize:

1. TitoDex title
2. Trainer Card
3. Journey status card when the selected game has save-linked support
4. Six-slot party card
5. Team / Dex / Search quick widgets

Square screens may show these as a dashboard with multiple panels visible at once. Phone portrait can stack them.

## Component Direction

### Loading feedback

First-open reads should reuse cached data and avoid eager hidden-page or full-list construction. Ordinary image cells retain static placeholders. Slow image slots and section loads use one pale white Poké Ball rotating in place, with constant opacity and no shimmer; a faint outline keeps it visible on light surfaces. Shared loaders wait 160 ms before appearing and disappear as soon as content is ready. Respect reduced motion and stop tickers in hidden battle tools. Measured download progress and the Assistant's semantic response animation keep their own behavior. See [FIRST_OPEN_LOADING.md](./FIRST_OPEN_LOADING.md).

### Trainer Card

Use a cream surface, deep-blue text, avatar or companion illustration, trainer identity, and concise progress metadata. It should feel specific to the current journey rather than like a generic account profile.

Core content:

- trainer display name
- current game
- avatar or companion illustration
- badge strip
- soft yellow or blue-gray panel

On normal RG panels the compact Trainer Card uses a slightly taller frame and
larger avatar/type; only the minimum 360 px compatibility layout keeps the
short micro height.

### Journey Card

The save-linked journey entry is a compact deep-blue status block rather than a
literal “continue game” button. It opens Journey detail; emulator launch is a
separate action there and in Settings. Manual/dex-only editions omit the card.
On the narrow RG half-column, badge progress owns one line and play time plus
the save-assistant summary own a second line; do not concatenate all metadata
into one truncated row.

Core content:

- localized current location and selected game context
- play time and separate regional badge progress where available
- latest save-assistant reminder / nearby-capture summary
- clear secondary-page affordance

### Party Card

Six slots, always all six — filled members and empty slots share the same cell frame so the card reads as a device's party screen rather than a variable-length list. Empty cells stay muted with a dashed-feeling low-alpha border and a plus glyph.

Cells are **upright**: sprite on top, name centered below across the full cell width. The name gets the whole width because the level is not a text line — it rides on the sprite.

**Level badge.** The level sits on the sprite's bottom-right corner as a small softYellow pill with an ink outline, the same visual family as journey badge pills. This is the general pattern for a short numeric qualifier attached to an image: put it on the artwork, not in the text stack. It buys back a whole text line, which goes to the sprite.

Rules:

- badge type scales with the sprite (roughly a quarter of sprite size, floored around 7.5 px so it stays legible on the square handheld)
- no badge when the value is unknown — never render a placeholder dash
- sprite size derives from the cell, never a fixed constant; cells that would stretch (a card given more height than it needs) cap near-square and center instead

### Quick Widgets

Small chunky buttons:

- Team
- Dex
- Search

Each widget should look like a friendly sticker or device tile.

### Companion Character

The companion is user-selectable and may use static, animated, shiny and cry
media where the audited catalog has an explicit candidate. Missing form media
must remain missing rather than silently borrowing another form. Source and
rights boundaries are maintained in `CREDITS.md` and the in-app credits page.

## Supplied Reference Translation

The reference image should be interpreted as a product direction, not a requirement to copy every pixel. Preserve the feeling: warm blue device, cream sticker cards, companion presence, dashboard density, and playful Trainer Card energy. Trainer's Journal now uses thinner gray-blue outlines and a paper lip instead of chunky near-black ink.


### Compact fact grids and answer progress (0.9.17)

Journey and Team facts share `TitoFactGrid` / `TitoFactTile`: 8px row/column
spacing, `TitoRadii.sm`, 10px cell padding, 12px label and 14px value separated
by 6px. Cells grow to their content. The requested column count is an upper
bound; the minimum 84px cell width scales with system text size. Trainer's
Journal fact tiles use a pale fill with no outline. Flat keeps
`TitoBorders.element` and Plastic uses `TitoBorders.glass` for the light edge.
Flat text uses the semantic on-surface colours.

Native answer progress uses an 18px prop in a 26px leading lane, with the
12px progress label aligned to the answer's leading edge. Loading rotates
only semantically related props, while completion holds the original subject.
Idle prompts keep their separate inline word transitions. Primary buttons
wrap long labels within available width without shrinking accessibility text.

### Setup and update surfaces (0.9.18)

First-run guidance reuses the App theme, existing avatar cropper and responsive
scrollable content; it is replayable from Settings without enabling Ask consent.
The companion Settings icon uses the same outlined Poké Ball family as other
icons. App-update progress and actions live in Settings → About. Custom form
and exact-game/DLC choice sheets retain themed spacing, selection and large-text
behavior; Android installer and launcher confirmation remain system surfaces.
