const dataUtil = require('../../utils/data.js');

const PAGE_SIZE = 40;

Page({
  data: {
    searchText: '',
    activeGen: 0,
    activeType: '',
    generations: dataUtil.GENERATIONS,
    typeChips: [{ slug: '', zh: '全部' }].concat(
      dataUtil.TYPE_ORDER.map(function (t) {
        return { slug: t, zh: dataUtil.TYPE_ZH[t] };
      })
    ),
    shown: [],
    total: 0,
    loadedCount: 0,
    hasMore: false,
    loading: false,
    noResult: false,
    showFilter: false
  },

  _filtered: [],

  onLoad() {
    this.applyFilter();
  },

  onShow() {
    // 从详情返回时保留搜索与筛选状态（页面实例仍在栈中，无需处理）
  },

  onReachBottom() {
    this.loadMore();
  },

  // ---- 筛选逻辑 ----
  applyFilter() {
    const filtered = dataUtil
      .filterList(
        this.data.searchText,
        this.data.activeGen || null,
        this.data.activeType || null
      )
      .map(dataUtil.decorate);
    this._filtered = filtered;
    this.setData({
      shown: filtered.slice(0, PAGE_SIZE),
      total: filtered.length,
      loadedCount: Math.min(PAGE_SIZE, filtered.length),
      hasMore: filtered.length > PAGE_SIZE,
      noResult: filtered.length === 0,
      loading: false
    });
  },

  loadMore() {
    if (!this.data.hasMore || this.data.loading) return;
    this.setData({ loading: true });
    const next = this._filtered.slice(0, this.data.loadedCount + PAGE_SIZE);
    // 延迟一帧，避免大 setData 卡住触底动画
    wx.nextTick(() => {
      this.setData({
        shown: next,
        loadedCount: next.length,
        hasMore: this._filtered.length > next.length,
        loading: false
      });
    });
  },

  // ---- 事件 ----
  onSearchInput(e) {
    this.setData({ searchText: e.detail.value });
    this.applyFilter();
  },

  onClearSearch() {
    this.setData({ searchText: '' });
    this.applyFilter();
  },

  onPickGen(e) {
    const gen = Number(e.currentTarget.dataset.gen) || 0;
    this.setData({ activeGen: gen });
    this.applyFilter();
  },

  onPickType(e) {
    this.setData({ activeType: e.currentTarget.dataset.type || '' });
    this.applyFilter();
  },

  onToggleFilter() {
    this.setData({ showFilter: !this.data.showFilter });
  },

  onResetFilter() {
    this.setData({ searchText: '', activeGen: 0, activeType: '' });
    this.applyFilter();
  },

  onImageError(e) {
    const idx = e.currentTarget.dataset.index;
    this.setData({ ['shown[' + idx + '].imgFailed']: true });
  },

  onTapCard(e) {
    const id = e.currentTarget.dataset.id;
    wx.navigateTo({ url: '/pages/detail/detail?id=' + id });
  },

  onGoAbout() {
    wx.navigateTo({ url: '/pages/about/about' });
  }
});
