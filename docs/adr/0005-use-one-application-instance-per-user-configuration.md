---
status: accepted
---

# Use one application instance per user configuration

2026-09-19 用户确认首发每个用户配置只运行一个应用实例, 再次打开时唤起原实例. 相比多实例共享缓存, 该选择减少 staging writer、LRU/pin 和 helper 所有权的竞争, 将首发复杂度集中到单实例内的任务取消与崩溃恢复; 它不免除 stale helper 和未完成产物的恢复要求.
