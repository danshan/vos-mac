extends RefCounted

const LANGUAGE_EN: String = "en"
const LANGUAGE_ZH: String = "zh"
const DEFAULT_LANGUAGE: String = LANGUAGE_EN
const LANGUAGE_ORDER: Array[String] = [LANGUAGE_EN, LANGUAGE_ZH]
const LANGUAGE_LABELS: Dictionary = {
	LANGUAGE_EN: "English",
	LANGUAGE_ZH: "中文",
}

const TRANSLATIONS: Dictionary = {
	"settings.title": {
		LANGUAGE_EN: "Settings",
		LANGUAGE_ZH: "设置",
	},
	"settings.help": {
		LANGUAGE_EN: "Game setup, audio, display, and controls.",
		LANGUAGE_ZH: "游戏设置, 音频, 显示和键位.",
	},
	"settings.section.language.title": {
		LANGUAGE_EN: "Language",
		LANGUAGE_ZH: "语言",
	},
	"settings.section.language.description": {
		LANGUAGE_EN: "Settings page language. This affects Settings only and does not change gameplay.",
		LANGUAGE_ZH: "设置页面显示语言. 只影响设置页面, 不会改变游戏画面.",
	},
	"settings.language.label": {
		LANGUAGE_EN: "Settings language",
		LANGUAGE_ZH: "设置语言",
	},
	"settings.language.description": {
		LANGUAGE_EN: "Changes labels and descriptions on this Settings page only.",
		LANGUAGE_ZH: "只切换设置页面中的标签和说明.",
	},
	"settings.section.songs.title": {
		LANGUAGE_EN: "Song library",
		LANGUAGE_ZH: "歌曲库",
	},
	"settings.section.songs.name": {
		LANGUAGE_EN: "Songs",
		LANGUAGE_ZH: "歌曲",
	},
	"settings.section.songs.description": {
		LANGUAGE_EN: "Folders that contain VOS, OJN/OJM, osu!mania 7K, or exported song bundles.",
		LANGUAGE_ZH: "包含 VOS, OJN/OJM, osu!mania 7K 或已导出歌曲包的文件夹.",
	},
	"settings.song_directory.label": {
		LANGUAGE_EN: "Song directory",
		LANGUAGE_ZH: "歌曲目录",
	},
	"settings.song_directory.description": {
		LANGUAGE_EN: "Folder scanned when Start is pressed. Choose a directory with the browser so the path is stored exactly as selected.",
		LANGUAGE_ZH: "点击 Start 时扫描的文件夹. 使用浏览器选择目录, 以便按所选路径精确保存.",
	},
	"settings.song_directory.empty": {
		LANGUAGE_EN: "No folder selected",
		LANGUAGE_ZH: "未选择文件夹",
	},
	"settings.song_directory.browse": {
		LANGUAGE_EN: "Browse...",
		LANGUAGE_ZH: "浏览...",
	},
	"settings.song_directory.dialog_title": {
		LANGUAGE_EN: "Select song directory",
		LANGUAGE_ZH: "选择歌曲目录",
	},
	"settings.section.display.title": {
		LANGUAGE_EN: "Display",
		LANGUAGE_ZH: "显示",
	},
	"settings.section.display.description": {
		LANGUAGE_EN: "Fullscreen behavior and screen mode.",
		LANGUAGE_ZH: "全屏行为和屏幕模式.",
	},
	"settings.fullscreen.label": {
		LANGUAGE_EN: "Fullscreen",
		LANGUAGE_ZH: "全屏",
	},
	"settings.fullscreen.description": {
		LANGUAGE_EN: "When enabled, returning from Settings requests fullscreen mode for the game window.",
		LANGUAGE_ZH: "启用后, 从设置返回时会请求游戏窗口进入全屏模式.",
	},
	"settings.fullscreen.control": {
		LANGUAGE_EN: "Use fullscreen mode",
		LANGUAGE_ZH: "使用全屏模式",
	},
	"settings.vsync.label": {
		LANGUAGE_EN: "VSync",
		LANGUAGE_ZH: "垂直同步",
	},
	"settings.vsync.description": {
		LANGUAGE_EN: "Synchronizes frame presentation with the display refresh, matching Java's launch-time VSync option.",
		LANGUAGE_ZH: "将画面呈现同步到显示器刷新, 对齐 Java 启动时的 VSync 选项.",
	},
	"settings.vsync.control": {
		LANGUAGE_EN: "Use VSync",
		LANGUAGE_ZH: "使用 VSync",
	},
	"settings.section.playback.title": {
		LANGUAGE_EN: "Playback assists",
		LANGUAGE_ZH: "播放辅助",
	},
	"settings.section.playback.description": {
		LANGUAGE_EN: "Testing assists that can play charts without manual input.",
		LANGUAGE_ZH: "用于测试的辅助功能, 可以在没有手动输入时播放谱面.",
	},
	"settings.autoplay.label": {
		LANGUAGE_EN: "Autoplay",
		LANGUAGE_ZH: "自动判定",
	},
	"settings.autoplay.description": {
		LANGUAGE_EN: "Automatically judges lane notes as hits. Use this for visual or audio checks, not normal play.",
		LANGUAGE_ZH: "自动将轨道音符判定为命中. 用于视觉或音频检查, 不适合正常游玩.",
	},
	"settings.autoplay.control": {
		LANGUAGE_EN: "Auto-hit lane notes",
		LANGUAGE_ZH: "自动命中轨道音符",
	},
	"settings.autosound.label": {
		LANGUAGE_EN: "AutoSound",
		LANGUAGE_ZH: "自动音效",
	},
	"settings.autosound.description": {
		LANGUAGE_EN: "Plays note keysounds at chart timing even without key presses. Disable it for manual keysound-only play.",
		LANGUAGE_ZH: "即使没有按键, 也按谱面时间播放 note keysound. 手动 keysound-only 游玩时可关闭.",
	},
	"settings.autosound.control": {
		LANGUAGE_EN: "Play keysounds automatically",
		LANGUAGE_ZH: "自动播放 keysound",
	},
	"settings.start_paused.label": {
		LANGUAGE_EN: "Start paused",
		LANGUAGE_ZH: "开局暂停",
	},
	"settings.start_paused.description": {
		LANGUAGE_EN: "Keeps chart time at zero until the first lane key is pressed.",
		LANGUAGE_ZH: "在第一次轨道按键前, 将谱面时间保持在零.",
	},
	"settings.start_paused.control": {
		LANGUAGE_EN: "Wait for first lane key",
		LANGUAGE_ZH: "等待第一次轨道按键",
	},
	"settings.local_matching.label": {
		LANGUAGE_EN: "Local matching server",
		LANGUAGE_ZH: "本地联机服务器",
	},
	"settings.local_matching.description": {
		LANGUAGE_EN: "Optional Java partytime host:port. When valid, gameplay waits for matching readiness instead of first-key start.",
		LANGUAGE_ZH: "可选 Java partytime host:port. 有效时, 游戏等待联机就绪, 而不是第一次按键开始.",
	},
	"settings.local_matching.placeholder": {
		LANGUAGE_EN: "host:port",
		LANGUAGE_ZH: "host:port",
	},
	"settings.create_server.label": {
		LANGUAGE_EN: "Create server",
		LANGUAGE_ZH: "创建服务器",
	},
	"settings.create_server.description": {
		LANGUAGE_EN: "Starts a Java-compatible partytime server on the port from Local matching server, or 7273 when the field is empty.",
		LANGUAGE_ZH: "使用本地联机服务器字段中的端口启动 Java 兼容 partytime server. 字段为空时使用 7273.",
	},
	"settings.section.timing.title": {
		LANGUAGE_EN: "Timing",
		LANGUAGE_ZH: "时序",
	},
	"settings.section.timing.description": {
		LANGUAGE_EN: "Millisecond offsets used to align input judgment, note drawing, and audio playback.",
		LANGUAGE_ZH: "用于对齐输入判定, 音符绘制和音频播放的毫秒偏移.",
	},
	"settings.audio_latency.label": {
		LANGUAGE_EN: "Audio latency",
		LANGUAGE_ZH: "音频延迟",
	},
	"settings.audio_latency.description": {
		LANGUAGE_EN: "Global audio and judgment offset in milliseconds. Positive values judge notes later; negative values judge earlier.",
		LANGUAGE_ZH: "全局音频与判定偏移, 单位毫秒. 正值让判定更晚, 负值让判定更早.",
	},
	"settings.display_latency.label": {
		LANGUAGE_EN: "Display latency",
		LANGUAGE_ZH: "显示延迟",
	},
	"settings.display_latency.description": {
		LANGUAGE_EN: "Visual offset in milliseconds applied after audio latency. Positive values draw notes later; negative values draw earlier.",
		LANGUAGE_ZH: "音频延迟之后应用的视觉偏移, 单位毫秒. 正值让音符更晚绘制, 负值让音符更早绘制.",
	},
	"settings.autosync.label": {
		LANGUAGE_EN: "Autosync mode",
		LANGUAGE_ZH: "自动同步模式",
	},
	"settings.autosync.description": {
		LANGUAGE_EN: "Optional Java autosync mode. It updates one latency value from normal tap judgments while a chart is running.",
		LANGUAGE_ZH: "可选 Java autosync 模式. 游戏运行时, 根据普通 tap 判定更新一个延迟值.",
	},
	"settings.section.audio.title": {
		LANGUAGE_EN: "Audio",
		LANGUAGE_ZH: "音频",
	},
	"settings.section.audio.description": {
		LANGUAGE_EN: "Volume multipliers for master output, note keysounds, and background music.",
		LANGUAGE_ZH: "主输出, note keysound 和背景音乐的音量倍率.",
	},
	"settings.master_volume.label": {
		LANGUAGE_EN: "Master volume",
		LANGUAGE_ZH: "主音量",
	},
	"settings.master_volume.description": {
		LANGUAGE_EN: "Master gain from 0.00 to 1.00 applied to every audio channel.",
		LANGUAGE_ZH: "应用到所有音频通道的主增益, 范围 0.00 到 1.00.",
	},
	"settings.key_volume.label": {
		LANGUAGE_EN: "Key volume",
		LANGUAGE_ZH: "按键音量",
	},
	"settings.key_volume.description": {
		LANGUAGE_EN: "Keysound gain from 0.00 to 1.00 applied to note samples.",
		LANGUAGE_ZH: "应用到 note sample 的 keysound 增益, 范围 0.00 到 1.00.",
	},
	"settings.bgm_volume.label": {
		LANGUAGE_EN: "BGM volume",
		LANGUAGE_ZH: "BGM 音量",
	},
	"settings.bgm_volume.description": {
		LANGUAGE_EN: "Background music gain from 0.00 to 1.00 applied to BGM samples.",
		LANGUAGE_ZH: "应用到 BGM sample 的背景音乐增益, 范围 0.00 到 1.00.",
	},
	"settings.section.modifiers.title": {
		LANGUAGE_EN: "Modifiers",
		LANGUAGE_ZH: "修饰符",
	},
	"settings.section.modifiers.description": {
		LANGUAGE_EN: "Optional gameplay rules that alter lanes, scroll distance, visibility, or judgment windows.",
		LANGUAGE_ZH: "可选游戏规则, 用于改变轨道, 滚动距离, 可见性或判定窗口.",
	},
	"settings.haste_mode.label": {
		LANGUAGE_EN: "Haste mode",
		LANGUAGE_ZH: "Haste 模式",
	},
	"settings.haste_mode.description": {
		LANGUAGE_EN: "Enables Java-style haste: chart speed and audio pitch change over time.",
		LANGUAGE_ZH: "启用 Java 风格 haste: 谱面速度和音频音高随时间变化.",
	},
	"settings.haste_mode.control": {
		LANGUAGE_EN: "Enable haste speed changes",
		LANGUAGE_ZH: "启用 haste 速度变化",
	},
	"settings.haste_normalize.label": {
		LANGUAGE_EN: "Haste normalize speed",
		LANGUAGE_ZH: "Haste 速度归一化",
	},
	"settings.haste_normalize.description": {
		LANGUAGE_EN: "Keeps note travel distance stable while haste changes pitch. Disable it to let scroll speed change with haste.",
		LANGUAGE_ZH: "当 haste 改变音高时保持音符移动距离稳定. 关闭后滚动速度会随 haste 变化.",
	},
	"settings.haste_normalize.control": {
		LANGUAGE_EN: "Keep scroll distance stable",
		LANGUAGE_ZH: "保持滚动距离稳定",
	},
	"settings.channel_modifier.label": {
		LANGUAGE_EN: "Channel modifier",
		LANGUAGE_ZH: "轨道修饰符",
	},
	"settings.channel_modifier.description": {
		LANGUAGE_EN: "Lane remap before play: None keeps lanes, Mirror reverses lanes, Shuffle picks one chart-wide map, Random changes by measure while preserving held lanes.",
		LANGUAGE_ZH: "游玩前重映射轨道: 无保持轨道, 镜像反转轨道, 洗牌使用整曲固定映射, 随机按小节变化并保持长按轨道.",
	},
	"settings.speed_type.label": {
		LANGUAGE_EN: "Speed type",
		LANGUAGE_ZH: "速度类型",
	},
	"settings.speed_type.description": {
		LANGUAGE_EN: "Scroll math mode: HiSpeed follows BPM, xRSpeed varies each lane, WSpeed waves over time, RegulSpeed uses a fixed 150 BPM baseline.",
		LANGUAGE_ZH: "滚动计算模式: HiSpeed 跟随 BPM, xRSpeed 为每个轨道增加变化, WSpeed 随时间波动, RegulSpeed 使用固定 150 BPM 基线.",
	},
	"settings.speed_multiplier.label": {
		LANGUAGE_EN: "Speed multiplier",
		LANGUAGE_ZH: "速度倍率",
	},
	"settings.speed_multiplier.description": {
		LANGUAGE_EN: "Base scroll multiplier from 0.5 to 10.0. Higher values move notes faster toward the judgment line.",
		LANGUAGE_ZH: "基础滚动倍率, 范围 0.5 到 10.0. 值越高, 音符越快接近判定线.",
	},
	"settings.visibility_modifier.label": {
		LANGUAGE_EN: "Visibility modifier",
		LANGUAGE_ZH: "可见性修饰符",
	},
	"settings.visibility_modifier.description": {
		LANGUAGE_EN: "Lane mask mode: Hidden covers lower lanes, Sudden covers upper lanes, Dark masks both ends, None leaves lanes visible.",
		LANGUAGE_ZH: "轨道遮罩模式: 隐藏覆盖下方, 突现覆盖上方, 黑暗覆盖两端, 无保持可见.",
	},
	"settings.judgment_type.label": {
		LANGUAGE_EN: "Judgment type",
		LANGUAGE_ZH: "判定类型",
	},
	"settings.judgment_type.description": {
		LANGUAGE_EN: "Judgment window mode: beat scales with BPM; time uses fixed millisecond windows.",
		LANGUAGE_ZH: "判定窗口模式: 节拍随 BPM 缩放, 时间使用固定毫秒窗口.",
	},
	"settings.option.autosync.off": {
		LANGUAGE_EN: "Off",
		LANGUAGE_ZH: "关闭",
	},
	"settings.option.autosync.display": {
		LANGUAGE_EN: "Display",
		LANGUAGE_ZH: "显示",
	},
	"settings.option.autosync.audio": {
		LANGUAGE_EN: "Audio",
		LANGUAGE_ZH: "音频",
	},
	"settings.option.autosync.off.description": {
		LANGUAGE_EN: "Off: keeps audio and display latency fixed during play.",
		LANGUAGE_ZH: "关闭: 游玩时保持固定的音频和显示延迟.",
	},
	"settings.option.autosync.display.description": {
		LANGUAGE_EN: "Display: updates display latency from tap hit offsets using the Java autosync rule.",
		LANGUAGE_ZH: "显示: 使用 Java autosync 规则, 根据 tap 命中偏移更新显示延迟.",
	},
	"settings.option.autosync.audio.description": {
		LANGUAGE_EN: "Audio: updates audio latency from tap hit offsets using the Java autosync rule.",
		LANGUAGE_ZH: "音频: 使用 Java autosync 规则, 根据 tap 命中偏移更新音频延迟.",
	},
	"settings.option.channel.none": {
		LANGUAGE_EN: "None",
		LANGUAGE_ZH: "无",
	},
	"settings.option.channel.mirror": {
		LANGUAGE_EN: "Mirror",
		LANGUAGE_ZH: "镜像",
	},
	"settings.option.channel.shuffle": {
		LANGUAGE_EN: "Shuffle",
		LANGUAGE_ZH: "洗牌",
	},
	"settings.option.channel.random": {
		LANGUAGE_EN: "Random",
		LANGUAGE_ZH: "随机",
	},
	"settings.option.channel.none.description": {
		LANGUAGE_EN: "None: keeps the chart's exported lane order.",
		LANGUAGE_ZH: "无: 保持谱面导出的轨道顺序.",
	},
	"settings.option.channel.mirror.description": {
		LANGUAGE_EN: "Mirror: reverses lane order, so lane 1 becomes lane 7.",
		LANGUAGE_ZH: "镜像: 反转轨道顺序, 轨道 1 变为轨道 7.",
	},
	"settings.option.channel.shuffle.description": {
		LANGUAGE_EN: "Shuffle: picks one randomized lane map and keeps it for the whole chart.",
		LANGUAGE_ZH: "洗牌: 生成一个随机轨道映射, 并在整首谱面中保持不变.",
	},
	"settings.option.channel.random.description": {
		LANGUAGE_EN: "Random: remaps lanes again for each measure while keeping held long notes on their active remapped lane.",
		LANGUAGE_ZH: "随机: 每个小节重新映射轨道, 同时让正在按住的长音符保持在当前映射轨道.",
	},
	"settings.option.speed.hispeed": {
		LANGUAGE_EN: "HiSpeed",
		LANGUAGE_ZH: "HiSpeed",
	},
	"settings.option.speed.xrspeed": {
		LANGUAGE_EN: "xRSpeed",
		LANGUAGE_ZH: "xRSpeed",
	},
	"settings.option.speed.wspeed": {
		LANGUAGE_EN: "WSpeed",
		LANGUAGE_ZH: "WSpeed",
	},
	"settings.option.speed.regulspeed": {
		LANGUAGE_EN: "RegulSpeed",
		LANGUAGE_ZH: "RegulSpeed",
	},
	"settings.option.speed.hispeed.description": {
		LANGUAGE_EN: "HiSpeed: follows chart BPM, so BPM changes affect note travel distance.",
		LANGUAGE_ZH: "HiSpeed: 跟随谱面 BPM, 因此 BPM 变化会影响音符移动距离.",
	},
	"settings.option.speed.xrspeed.description": {
		LANGUAGE_EN: "xRSpeed: applies Java xRSpeed lane variation on top of the base speed multiplier.",
		LANGUAGE_ZH: "xRSpeed: 在基础速度倍率之上应用 Java xRSpeed 轨道变化.",
	},
	"settings.option.speed.wspeed.description": {
		LANGUAGE_EN: "WSpeed: waves scroll distance over time using the Java WSpeed rule.",
		LANGUAGE_ZH: "WSpeed: 使用 Java WSpeed 规则, 让滚动距离随时间波动.",
	},
	"settings.option.speed.regulspeed.description": {
		LANGUAGE_EN: "RegulSpeed: uses a fixed 150 BPM baseline so scroll distance does not follow chart BPM changes.",
		LANGUAGE_ZH: "RegulSpeed: 使用固定 150 BPM 基线, 因此滚动距离不跟随谱面 BPM 变化.",
	},
	"settings.option.visibility.none": {
		LANGUAGE_EN: "None",
		LANGUAGE_ZH: "无",
	},
	"settings.option.visibility.hidden": {
		LANGUAGE_EN: "Hidden",
		LANGUAGE_ZH: "隐藏",
	},
	"settings.option.visibility.sudden": {
		LANGUAGE_EN: "Sudden",
		LANGUAGE_ZH: "突现",
	},
	"settings.option.visibility.dark": {
		LANGUAGE_EN: "Dark",
		LANGUAGE_ZH: "黑暗",
	},
	"settings.option.visibility.none.description": {
		LANGUAGE_EN: "None: leaves the playfield lanes fully visible.",
		LANGUAGE_ZH: "无: 保持游玩区域轨道完全可见.",
	},
	"settings.option.visibility.hidden.description": {
		LANGUAGE_EN: "Hidden: covers the lower part of the lanes so notes disappear before the judgment line.",
		LANGUAGE_ZH: "隐藏: 遮住轨道下方, 让音符在到达判定线前消失.",
	},
	"settings.option.visibility.sudden.description": {
		LANGUAGE_EN: "Sudden: covers the upper part of the lanes so notes appear later.",
		LANGUAGE_ZH: "突现: 遮住轨道上方, 让音符更晚出现.",
	},
	"settings.option.visibility.dark.description": {
		LANGUAGE_EN: "Dark: covers both upper and lower lane areas.",
		LANGUAGE_ZH: "黑暗: 同时遮住轨道上方和下方区域.",
	},
	"settings.option.judgment.beat": {
		LANGUAGE_EN: "beat",
		LANGUAGE_ZH: "节拍",
	},
	"settings.option.judgment.time": {
		LANGUAGE_EN: "time",
		LANGUAGE_ZH: "时间",
	},
	"settings.option.judgment.beat.description": {
		LANGUAGE_EN: "beat: scales judgment windows with BPM, matching the Java beat-based mode.",
		LANGUAGE_ZH: "节拍: 判定窗口随 BPM 缩放, 对齐 Java 的 beat-based 模式.",
	},
	"settings.option.judgment.time.description": {
		LANGUAGE_EN: "time: uses fixed millisecond judgment windows regardless of BPM.",
		LANGUAGE_ZH: "时间: 使用固定毫秒判定窗口, 不受 BPM 影响.",
	},
	"settings.section.input.title": {
		LANGUAGE_EN: "Input",
		LANGUAGE_ZH: "输入",
	},
	"settings.section.input.description": {
		LANGUAGE_EN: "Keys used for the seven gameplay lanes and in-game adjustment hotkeys.",
		LANGUAGE_ZH: "七个游戏轨道和游戏内调整热键使用的按键.",
	},
	"settings.lane_bindings.label": {
		LANGUAGE_EN: "Lane key bindings",
		LANGUAGE_ZH: "轨道键位绑定",
	},
	"settings.lane_bindings.description": {
		LANGUAGE_EN: "Seven lane inputs, left to right. Focus a key button, press Enter, then press one keyboard key to bind it.",
		LANGUAGE_ZH: "七个轨道输入, 从左到右. 聚焦某个按键按钮, 按 Enter, 再按下一个键盘按键完成绑定.",
	},
	"settings.misc_bindings.label": {
		LANGUAGE_EN: "Misc key bindings",
		LANGUAGE_ZH: "其他热键绑定",
	},
	"settings.misc_bindings.description": {
		LANGUAGE_EN: "In-game adjustment hotkeys for speed and volume. Focus a key button, press Enter, then press one keyboard key to bind it.",
		LANGUAGE_ZH: "游戏内调整速度和音量的热键. 聚焦某个按键按钮, 按 Enter, 再按下一个键盘按键完成绑定.",
	},
	"settings.available_values": {
		LANGUAGE_EN: "Available values",
		LANGUAGE_ZH: "可用值",
	},
	"settings.back": {
		LANGUAGE_EN: "Back",
		LANGUAGE_ZH: "返回",
	},
	"settings.input.lane_description": {
		LANGUAGE_EN: "Triggers gameplay lane %d in the 7K layout. Use a single recognized keyboard key.",
		LANGUAGE_ZH: "触发 7K 布局中的第 %d 个游戏轨道. 使用一个 Godot 可识别的键盘按键.",
	},
	"settings.input.lane_label": {
		LANGUAGE_EN: "Lane %d",
		LANGUAGE_ZH: "轨道 %d",
	},
	"settings.input.lane_placeholder": {
		LANGUAGE_EN: "Lane %d keyboard key",
		LANGUAGE_ZH: "轨道 %d 键盘按键",
	},
	"settings.input.misc_placeholder": {
		LANGUAGE_EN: "%s key",
		LANGUAGE_ZH: "%s 按键",
	},
	"settings.input.press_key": {
		LANGUAGE_EN: "Press a key...",
		LANGUAGE_ZH: "按下按键...",
	},
	"settings.misc.speed_up.label": {
		LANGUAGE_EN: "Speed up",
		LANGUAGE_ZH: "加速",
	},
	"settings.misc.speed_down.label": {
		LANGUAGE_EN: "Speed down",
		LANGUAGE_ZH: "减速",
	},
	"settings.misc.main_volume_up.label": {
		LANGUAGE_EN: "Master volume up",
		LANGUAGE_ZH: "主音量增加",
	},
	"settings.misc.main_volume_down.label": {
		LANGUAGE_EN: "Master volume down",
		LANGUAGE_ZH: "主音量降低",
	},
	"settings.misc.key_volume_up.label": {
		LANGUAGE_EN: "Key volume up",
		LANGUAGE_ZH: "按键音量增加",
	},
	"settings.misc.key_volume_down.label": {
		LANGUAGE_EN: "Key volume down",
		LANGUAGE_ZH: "按键音量降低",
	},
	"settings.misc.bgm_volume_up.label": {
		LANGUAGE_EN: "BGM volume up",
		LANGUAGE_ZH: "BGM 音量增加",
	},
	"settings.misc.bgm_volume_down.label": {
		LANGUAGE_EN: "BGM volume down",
		LANGUAGE_ZH: "BGM 音量降低",
	},
	"settings.misc.speed_up.description": {
		LANGUAGE_EN: "During gameplay, raises note scroll speed by 0.5.",
		LANGUAGE_ZH: "游戏中将音符滚动速度提高 0.5.",
	},
	"settings.misc.speed_down.description": {
		LANGUAGE_EN: "During gameplay, lowers note scroll speed by 0.5.",
		LANGUAGE_ZH: "游戏中将音符滚动速度降低 0.5.",
	},
	"settings.misc.main_volume_up.description": {
		LANGUAGE_EN: "During gameplay, raises master volume by 0.05.",
		LANGUAGE_ZH: "游戏中将主音量提高 0.05.",
	},
	"settings.misc.main_volume_down.description": {
		LANGUAGE_EN: "During gameplay, lowers master volume by 0.05.",
		LANGUAGE_ZH: "游戏中将主音量降低 0.05.",
	},
	"settings.misc.key_volume_up.description": {
		LANGUAGE_EN: "During gameplay, raises keysound volume by 0.05.",
		LANGUAGE_ZH: "游戏中将 keysound 音量提高 0.05.",
	},
	"settings.misc.key_volume_down.description": {
		LANGUAGE_EN: "During gameplay, lowers keysound volume by 0.05.",
		LANGUAGE_ZH: "游戏中将 keysound 音量降低 0.05.",
	},
	"settings.misc.bgm_volume_up.description": {
		LANGUAGE_EN: "During gameplay, raises background music volume by 0.05.",
		LANGUAGE_ZH: "游戏中将背景音乐音量提高 0.05.",
	},
	"settings.misc.bgm_volume_down.description": {
		LANGUAGE_EN: "During gameplay, lowers background music volume by 0.05.",
		LANGUAGE_ZH: "游戏中将背景音乐音量降低 0.05.",
	},
}


static func supported_languages() -> Array[String]:
	return LANGUAGE_ORDER.duplicate()


static func is_supported_language(language: String) -> bool:
	return LANGUAGE_ORDER.has(language)


static func language_label(language: String) -> String:
	return str(LANGUAGE_LABELS.get(language, language))


static func normalized_language(language: String) -> String:
	if is_supported_language(language):
		return language
	return DEFAULT_LANGUAGE


static func text(language: String, key: String, fallback: String = "") -> String:
	var raw_entry: Variant = TRANSLATIONS.get(key, {})
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		var normalized := normalized_language(language)
		if entry.has(normalized):
			return str(entry.get(normalized, ""))
		if entry.has(DEFAULT_LANGUAGE):
			return str(entry.get(DEFAULT_LANGUAGE, ""))
	if not fallback.is_empty():
		return fallback
	return key


static func format(language: String, key: String, values: Array, fallback: String = "") -> String:
	return text(language, key, fallback) % values


static func key_for_english(english: String) -> String:
	for raw_key: Variant in TRANSLATIONS.keys():
		var key := str(raw_key)
		var raw_entry: Variant = TRANSLATIONS.get(key, {})
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if str(entry.get(LANGUAGE_EN, "")) == english:
			return key
	return ""
