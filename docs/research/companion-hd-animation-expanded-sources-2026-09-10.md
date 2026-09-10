# Companion 高清动画补充调查：ShinyHunters、WikiDex、FurretTurret 与 52Poké

调查日期：2026-09-10。用户以大尾立高清动图为线索要求扩大来源范围。本次仅研究公开目录与抽样素材，没有修改 App 候选、下载整套资源或发布素材。

此前 [Paraíso 覆盖核对](companion-hd-animation-coverage-2026-09-10.md) 的 535 / 1025 默认物种、190 / 554 普通色其他形态、174 / 554 异色其他形态，只描述两套指定 Paraíso 高清目录，不能据此判断全网没有其余高清动画。

## 结论

- **ShinyHunters 应加入优先候选来源。** 大尾立普通色、异色都有透明循环 GIF；它也有第九世代动画。但同库混有大图、小图、静态 PNG，必须按文件核验，不能把整个库标成高清动画。
- **WikiDex 是另一条高分辨率来源，且包含第九世代。** HOME 与朱／紫动画使用 WebM。当前 Companion 的图片渲染路径不能仅填 WebM 地址便完成接入。
- **FurretTurret 高清资源档案仍可公开列出。** 本次确认公开压缩包元数据，没有下载或核验包内每个形态；不是现成的单角色直链目录。
- **52Poké 的中间世代图库确实提供相关外观素材。** 大尾立第六、七世代栏目复用相同文件。本次原文件页遇到站点验证，没有确认其真实尺寸和是否为 APNG，不能把 PNG 后缀直接当成静态图，也不能据栏目数量推定高清覆盖率。

## ShinyHunters：实测普通色与异色

来源：[公开攻略目录](https://www.shinyhunters.com/en/guides)、[大尾立攻略](https://www.shinyhunters.com/en/guides/pokemon/162)。遍历目录公开链接的 43 个游戏攻略页，得到 1,135 个去重攻略身份，涉及 984 个全国图鉴编号。它是攻略可枚举范围，**不是全站图片清单，更不是 984 个物种已通过高清动画验证**；攻略未列出的物种可能仍有素材。

本次读取大尾立与另 14 个身份的普通／异色样本，共 30 个 ShinyHunters 文件，并用 Pillow 解码全部帧。另解析 Paraíso 小尺寸大尾立作为比较。原始媒体仅在内存解析，没有写入素材目录。画布尺寸不等于每帧角色实际占用尺寸，也不能证明原生渲染分辨率。

| 物种／形态 | 普通色实际尺寸、帧数 | 异色实际尺寸、帧数 | 观察 |
| --- | --- | --- | --- |
| 妙蛙种子 | 320×350，42 帧 | 182×194，42 帧 | 两色尺寸不同 |
| 大尾立 | **560×510，60 帧** | **314×289，60 帧** | 两者透明、无限循环，周期 1.8 秒 |
| 木守宫 | 360×450，40 帧 | 182×248，40 帧 | 两色尺寸不同 |
| 未知图腾 B | 63×63，79 帧 | 259×277，80 帧 | 普通色是小图 |
| 阿尔宙斯 | 450×610，90 帧 | 291×346，90 帧 | 仅验证页面对应外观，没有验证所有属性形态 |
| 盖诺赛克特 | 70×92，49 帧 | 204×274，50 帧 | 普通色是小图 |
| 甲贺忍蛙 | 131×76，39 帧 | 526×313，40 帧 | 普通色是小图 |
| 彩粉蝶（冰雪花纹） | 104×104，79 帧 | 313×312，80 帧 | 普通色是小图 |
| 银伴战兽 | 57×117，47 帧 | 165×346，48 帧 | 普通色是小图 |
| 敲音猴 | 301×379，40 帧 | 151×190，40 帧 | 两色尺寸不同 |
| 霜奶仙（攻略标为草莓糖饰） | 320×438，60 帧 | 503×669，60 帧 | 奶油形态尚未绑定本地 formKey |
| 卡蒂狗（洗翠） | **250×250，单帧 PNG** | 594×667，40 帧 GIF | 普通色文件虽以 `.gif` 结尾，实际静态 |
| 新叶喵 | 158×228，60 帧 | 158×228，60 帧 | 第九世代动画存在，尺寸较小 |
| 故勒顿 | 470×573，110 帧 | 470×573，110 帧 | 两色约 6.79 / 7.12 MiB，具体姿态尚未绑定本地 formKey |
| 来悲粗茶 | **250×250，单帧 PNG** | 599×822，90 帧 GIF | 两色动画可用性不对称；真伪形态尚未绑定 |

已在浏览器实际打开普通色大尾立：形体细节明显比 85×73 的 Paraíso XY 小图丰富；仍能看到 GIF 色阶和轮廓锯齿，不意味着无损画质。

- [ShinyHunters 普通色大尾立](https://www.shinyhunters.com/images/regular/162.gif)：2,148,354 字节。
- [ShinyHunters 异色大尾立](https://www.shinyhunters.com/images/shiny/162.gif)：921,765 字节。
- [Paraíso XY 大尾立小图](https://www.pkparaiso.com/imagenes/xy/sprites/animados/furret.gif)：85×73，59 帧，170,567 字节。

### 身份映射不能由全国编号拼接

ShinyHunters 的文件／攻略数字使用内部编号。例如：

| 内部编号 | 全国图鉴编号 | 攻略对应身份 |
| --- | --- | --- |
| 867 | 201 | 未知图腾 B |
| 903 | 810 | 敲音猴 |
| 906 | 813 | 炎兔儿，**不是新叶喵** |
| 1024 | 58 | 洗翠卡蒂狗，**不是太乐巴戈斯** |
| 1044 | 906 | 新叶喵 |
| 1138 | 1007 | 故勒顿 |
| 1160 | 1013 | 来悲粗茶 |

攻略索引里未知图腾有 28 个条目、洛托姆 6 个、四季鹿／萌芽鹿各 4 个、花舞鸟 4 个；彩粉蝶列出 19 个，霜奶仙只列出 2 个糖饰条目。阿尔宙斯／银伴战兽各只有一个攻略条目。后几项说明这个攻略目录不足以保证本地图鉴 554 个其他形态全部对应，**不能反过来断言未列出的图片在站点不存在**。

## WikiDex：更大尺寸，格式为 WebM

- [大尾立 HOME 文件页](https://www.wikidex.net/wiki/Archivo:Furret_HOME.webm)：页面标明 **633×590**，1.8 秒，VP9，168 kB。
- [大尾立朱／紫文件页](https://www.wikidex.net/wiki/Archivo:Furret_EP.webm)：页面标明 **1472×1543**，2.7 秒，VP9，690 kB。
- [HOME 普通色分类](https://www.wikidex.net/wiki/Categor%C3%ADa:Sprites_animados_de_Pok%C3%A9mon_HOME)：分类显示 1,494 个文件。
- [HOME 异色分类](https://www.wikidex.net/wiki/Categor%C3%ADa:Sprites_animados_variocolores_de_Pok%C3%A9mon_HOME)：分类显示 1,426 个文件。

分类文件数含形态／性别变体，不等于物种数，也不等于本地 formKey 覆盖数。读取 HOME 普通色项目的 [第一部分](https://www.wikidex.net/wiki/WikiDex:Proyecto_Pok%C3%A9dex/Sprites_animados_de_Pok%C3%A9mon_HOME_(1))、[第二部分](https://www.wikidex.net/wiki/WikiDex:Proyecto_Pok%C3%A9dex/Sprites_animados_de_Pok%C3%A9mon_HOME_(2))、[第三部分](https://www.wikidex.net/wiki/WikiDex:Proyecto_Pok%C3%A9dex/Sprites_animados_de_Pok%C3%A9mon_HOME_(3))，分别提取 575、487、377 个原始 WebM 链接，去除缩略图／转码链接后合计 1,439 个去重 URL。项目页与分类页收录范围不同；没有将其合并成“全部验证通过”。

这次只核对文件页元数据和项目目录，没有下载／逐帧解码这些视频，没有验证透明通道、Flutter 解码兼容性或全形态匹配。若后续选择此源，需先准备当前渲染路径支持的动画格式，或另行实现播放器；不应把 WebM 当 GIF 填进候选。

## FurretTurret：公开高清压缩包档案

[MediaFire 公开文件夹](https://www.mediafire.com/folder/9t19091d3l857/Pok%C3%A9mon_Sprites) 的公开列表接口本次返回 13 个 ZIP 文件、无后续分页：普通色 GEN1–GEN4，异色 GEN1–GEN7、ULTRA，以及一个异色合并包。

其中 [普通色 GEN2](https://www.mediafire.com/file/68x5m310j3hd11a/FurretTurret_REGULAR_HD_SPRITE_GEN2.zip/file) 为 252,282,164 字节；异色合并包约 4.57 GB（十进制）。这确实是更早世代高清素材的补充线索，但本次没有下载 ZIP，不能声称已验证其中的大尾立、全部形态或异色完整性。

查到的 `dokkanart/gen1-7sprites` GitHub 仓库只有 README 与 LICENSE，没有实际 GIF，不能把它当现成素材 CDN。公开存档也不是逐只角色的稳定直链 API；如需后续分拆托管，应另行核对来源和发布条件。

## 52Poké：图库存在，高清原件还未核实

[大尾立条目](https://wiki.52poke.com/wiki/%E5%A4%A7%E5%B0%BE%E7%AB%8B) 的第六世代 XY／ORAS 与第七世代 SM／USUM 栏目复用 `Spr_6x_162.png`、`Spr_6x_162_s.png` 等相同原文件；不是四套独立素材。条目还列出 BDSP、朱／紫、HOME 外观图。

第五世代栏目有 GIF，但属于低分辨率像素素材。第六／七世代 PNG 原文件可能包含动画，不能只根据后缀断言；此次文件页触发站点验证，未完成原图尺寸、实际格式与帧数核验。停止了进一步原文件请求，没有绕过验证或批量抓取。

仓库当前 `tools/fetch_52poke_media_catalog.py` 也已停用新增 52Poké 图片／音频抓取，只允许复用已审计缓存；本次没有恢复该流程或新增其运行时下载地址。

## 对现有候选功能的建议

保持用户确认的流程：**原有候选列表中选中来源后，再下载所选素材并缓存**。优先整理 ShinyHunters 与已审计 Paraíso 的显式身份映射，普通色和异色各自记录 URL、真实格式、尺寸、帧数。只有通过核验的多帧素材才作为动画候选；缺失或静态文件不能用默认形态／另一颜色充数。

来源编号、物种、formKey、性别、普通／异色、来源／尺寸需分别记录。相同物种的不同来源应拥有不同缓存身份，防止选中高清地址却命中旧小图。此次没有写入 App 候选数据，也没有完成 ShinyHunters／WikiDex 对本地 1,579 个身份的逐项全量媒体验收。

## 可复核数据

- [ShinyHunters 攻略索引](hd-companion-audit-2026-09-10/shinyhunters-guide-index.json)：1,135 条公开攻略记录，记录站点自己的物种标签与原始 URL；不是已批准的运行时候选清单。
- [样本解码结果](hd-companion-audit-2026-09-10/expanded-source-samples.json)：30 个 ShinyHunters 文件与一个 Paraíso 对比文件的尺寸／帧数等元数据。
- [其他目录元数据](hd-companion-audit-2026-09-10/expanded-source-index-metadata.json)：WikiDex 项目链接统计、攻略目录范围和公开 ZIP 元数据。

没有跑 Flutter 构建、设备性能测试或全 App 测试，因为本次没有改动产品代码。
