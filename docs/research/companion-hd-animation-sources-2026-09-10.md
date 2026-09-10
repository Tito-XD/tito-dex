# Companion 高清动画素材调查

调查日期：2026-09-10。仅核对来源、抽样文件和当前接入代码，没有替换 App 素材、下载整包或进行设备性能测试。

后续已完成两套 Paraíso 高清目录的逐项对照，见 [全量覆盖核对](companion-hd-animation-coverage-2026-09-10.md)；本文的样本实测与全量核对的验证范围不同。

又以大尾立为线索扩展核对了 ShinyHunters、WikiDex、FurretTurret 与 52Poké，见 [补充调查与实测](companion-hd-animation-expanded-sources-2026-09-10.md)。ShinyHunters 已确认同时提供普通色与异色动画，但混有小图和伪装为 GIF 后缀的静态 PNG；下方初次调查不能当成最终覆盖结论。

## 推荐来源

1. [Pokémon Paraíso — 剑／盾大尺寸动画](https://www.pkparaiso.com/espada_escudo/sprites_pokemon.php)：页面明确区分大尺寸、带描边和背面版本，并提供 6.3 GB 的 `1300-big-front-gifs.zip`。这是文件包名称，不代表 1300 个物种。不能当成该游戏或全图鉴的完整覆盖。后续已遍历 29 个分页，记录 1391 个去重高清 GIF 地址并检查文件头；没有下载整包。
2. [Pokémon Paraíso — USUM 高清无外描边动画](https://www.pkparaiso.com/ultra-sol-ultra-luna/sprites_pokemon_sin_bordes.php)：优先试用的候选。包含火球鼠、菊草叶、火狐狸、木木枭等普通／异色版本。页面小图和点击后的原图是不同文件；必须使用 `animados-sinbordes-gigante` 原图。已读取原文件并在浏览器目视检查高清火球鼠。
3. [ShinyHunters](https://www.shinyhunters.com/en)：普通色／异色动画候选来源。初次实测首页尼多娜 GIF 为 169×230、40 帧、约 414 KiB；补充调查确认大尾立普通色 560×510、异色 314×289，均为 60 帧透明 GIF，并枚举了 1,135 条公开攻略身份。攻略索引不等于全量高清覆盖，详见补充调查。
4. adamsb0303 的朱／紫、阿尔宙斯动画：作者的 [Shiny Hunt Tracker 仓库](https://github.com/adamsb0303/Shiny_Hunt_Tracker) 与其公开发布的动画集可作后续补充线索。尚未逐文件验证。Showdown 维护者在 [2023 年讨论](https://www.smogon.com/forums/threads/gen-9-animated-sprites.3716084/) 中指出当时提交的一批素材有蓝色灯光／边缘及体积问题；不能直接把那一批当成统一风格、已优化的 App 素材。

[Project Pokémon 的第八世代索引](https://projectpokemon.org/home/docs/spriteindex_148/3d-models-generation-8-pok%C3%A9mon-r123/) 明确说明其 GIF 来自 pkparaiso，应保留来源署名，因此不是另一个独立高清源。后续确认 Paraíso 页脚链接到 [CC BY-NC-ND 3.0 ES](https://creativecommons.org/licenses/by-nc-nd/3.0/es/)；这是站点页脚声明，本调查没有据此判定每份游戏素材的 App 再分发权限。

## 实测文件

远程文件只在内存中解析，没有写入 App 或本地素材目录。尺寸是文件画布尺寸，不等于每帧角色实际占用的尺寸。MiB/KiB 使用 1024 进制。

| 素材 | 尺寸 | 帧数 | 文件字节数 | 大小 | 循环时间 |
| --- | --- | --- | --- | --- | --- |
| App 自带火球鼠 `flutter/assets/companion_media/155.gif` | 38×45 | 50 | 24,636 | 24.1 KiB | 本次未测 |
| Paraíso 火球鼠页面小图 | 43×50 | 50 | 35,994 | 35.2 KiB | 1.50 秒 |
| Paraíso 火球鼠高清原图 | 429×499 | 50 | 2,593,048 | 2.47 MiB | 1.50 秒 |
| Paraíso 菊草叶高清原图 | 364×744 | 48 | 2,606,627 | 2.49 MiB | 1.44 秒 |
| ShinyHunters 异色尼多娜 | 169×230 | 40 | 423,771 | 413.8 KiB | 1.20 秒 |

四个远程 GIF 均有透明索引、无限循环标记，帧间隔均为 30 ms。高清火球鼠目视有明显更丰富的形体细节；原尺寸仍可看见 GIF 色阶抖动和边缘噪点，需要在实际 UI 背景及目标尺寸下验收。

已验证的远程样本：

- [火球鼠高清原图](https://www.pkparaiso.com/imagenes/ultra_sol_ultra_luna/sprites/animados-sinbordes-gigante/cyndaquil.gif)
- [火球鼠页面小图](https://www.pkparaiso.com/imagenes/ultra_sol_ultra_luna/sprites/animados-sinbordes/cyndaquil.gif)
- [菊草叶高清原图](https://www.pkparaiso.com/imagenes/ultra_sol_ultra_luna/sprites/animados-sinbordes-gigante/chikorita.gif)
- [ShinyHunters 异色尼多娜](https://www.shinyhunters.com/images/shiny/30.gif)

## 当前代码与接入判断

- `flutter/lib/features/companion/companion_media.dart` 已有内置 GIF、下载候选和磁盘缓存；`flutter/lib/widgets/companion_standby.dart` 已支持 `animationSourceUrl`，显式选择的普通动画可排在内置素材前。GIF 可沿现有图片渲染路径试用。
- 当前缓存主要用媒体 ID 与固定扩展名命名。新增画质或来源需要独立缓存身份，避免高清选择命中旧小图缓存。
- `companion_standby.dart` 在 `sizeScale > 1.3` 时切到最近邻采样；这适合像素素材，高清 3D 应按素材种类选择平滑采样，不能只由放大倍率决定。
- 形态、性别、普通／异色必须显式对应。不能仅凭名称拼 URL，也不能把形态缺失当成默认形态动画可用。现有 `shinySpriteVariantUrl` 的规则需单独核对新源，不能假设自动支持 `-s` 命名。
- 当前 `FallbackSpriteImage` 走 `Image.asset/network/file`。不要把 WebM 当成 GIF 候选直接填入；若选用 WebM，需要单独的播放与透明度验证路径。

## 建议的试点

按用户确认的范围，把高清来源加入现有 Companion 素材候选列表，选中后再下载和缓存，无需增加单独的主题或画质设置。先用火球鼠、菊草叶等已验证样本做少量试点，确认透明边缘、脚底锚点、角色占比、循环接缝、异色和离线重开行为。

下载所选角色后缓存；探索长边 256／384 px 的派生版本或动画 WebP，但这些尺寸和格式是待验证方案，尚未实测体积、解码速度、内存或功耗。不要直接将多 GB 原图全集塞入 APK。最终再在 RG 真机与高 DPI 手机上比较清晰度和持续播放开销。
