const dataUtil = require('../../utils/data.js');

Page({
  data: {
    loading: true,
    notFound: false,
    entry: null,
    hasDetail: false,
    // 基础信息
    types: [],
    heightM: '',
    weightKg: '',
    generationLabel: '',
    genusZh: '',
    // 扩展详情（17 个代表条目）
    stats: [],
    statTotal: 0,
    abilities: [],
    flavor: [],
    flavorExpanded: false,
    evoChain: [],
    extra: null,
    imgFailed: false
  },

  onLoad(options) {
    const id = parseInt(options.id, 10);
    const indexItem = dataUtil.getIndex()[id - 1];
    if (!indexItem || indexItem.id !== id) {
      this.setData({ loading: false, notFound: true });
      return;
    }

    const genInfo = dataUtil.GENERATIONS[indexItem.generation - 1];
    const detail = dataUtil.getDetail(id);

    // 基础信息（全部条目都有）
    const base = {
      loading: false,
      notFound: false,
      id: id,
      no: dataUtil.padNo(id),
      nameZh: indexItem.nameZh,
      nameEn: indexItem.nameEn,
      genusZh: /宝可梦/.test(indexItem.genusZh || '') ? indexItem.genusZh : '',
      types: (indexItem.types || []).map(function (t) {
        return { slug: t, zh: dataUtil.TYPE_ZH[t] || t, color: dataUtil.TYPE_COLOR[t] || '#7b91a6' };
      }),
      imageUrl: indexItem.imageUrl,
      heightM: indexItem.heightDm != null ? (indexItem.heightDm / 10).toFixed(1) : '',
      generationLabel: genInfo ? genInfo.label + ' · ' + genInfo.region : '',
      hasDetail: !!detail,
      imgFailed: false
    };

    wx.setNavigationBarTitle({ title: base.nameZh + ' · TitoDex' });

    if (detail) {
      // 种族值
      const bs = detail.baseStats || {};
      const stats = Object.keys(dataUtil.STAT_ZH).map(function (k) {
        const v = bs[k];
        return {
          key: k,
          zh: dataUtil.STAT_ZH[k],
          color: dataUtil.STAT_COLOR[k],
          value: v != null ? v : null,
          width: v != null ? Math.min(100, Math.round((v / 255) * 100)) : 0
        };
      });
      const statTotal = stats.reduce(function (s, it) { return s + (it.value || 0); }, 0);

      // 特性
      const abilities = (detail.abilities || []).map(function (a) {
        return {
          nameZh: a.nameZh || a.nameEn,
          nameEn: a.nameEn || '',
          descriptionZh: (a.descriptionZh || '').replace(/\n/g, ' '),
          isHidden: !!a.isHidden
        };
      });

      // 版本描述
      const flavor = (detail.flavorEntries || []).map(function (f) {
        return { labelZh: f.labelZh || f.version, text: (f.text || '').replace(/\s+/g, ' ') };
      });

      // 进化链（结构化条件 -> 中文）
      const evoChain = detail.evolutionChain ? dataUtil.flattenChain(detail.evolutionChain) : [];

      // 其他信息
      const gfp = detail.genderFemalePercent;
      const genderText =
        gfp == null ? '无性别' : '♂ ' + (100 - gfp) + '% / ♀ ' + gfp + '%';
      const extra = {
        weightKg: detail.weightHg != null ? (detail.weightHg / 10).toFixed(1) : '',
        captureRate: detail.captureRate != null ? String(detail.captureRate) : '',
        baseHappiness: detail.baseHappiness != null ? String(detail.baseHappiness) : '',
        genderText: genderText,
        eggGroups: (detail.eggGroups || []).join('、'),
        hatchCycles: detail.hatchCounter != null && !(detail.eggGroups || []).includes('未发现') ? String(detail.hatchCounter) + ' 个周期' : '',
        growthRate: dataUtil.GROWTH_ZH[detail.growthRateSlug] || detail.growthRateSlug || ''
      };

      this.setData(Object.assign(base, {
        stats: stats,
        statTotal: statTotal,
        abilities: abilities,
        flavor: flavor,
        evoChain: evoChain,
        extra: extra
      }));
    } else {
      // 无扩展详情：只展示已知信息
      this.setData(base);
    }
  },

  onToggleFlavor() {
    this.setData({ flavorExpanded: !this.data.flavorExpanded });
  },

  onImageError() {
    this.setData({ imgFailed: true });
  },

  onEvoImageError(e) {
    const idx = e.currentTarget.dataset.index;
    this.setData({ ['evoChain[' + idx + '].imgFailed']: true });
  },

  onGoAbout() {
    wx.navigateTo({ url: '/pages/about/about' });
  }
});
