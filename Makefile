# flare-core-android-app — 开发/运行命令
#
# 用法: make <target>   (不带参数 = make help)
# 覆盖变量示例: make run WS=ws://10.0.2.2:60099/ws
#
# 依赖: JDK17(Lombok/AGP 需要)、Android SDK、已提交的 gradlew、模拟器 AVD。

# ---- 可覆盖变量 ----------------------------------------------------------
JAVA_HOME    ?= $(shell /usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home)
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
AVD          ?= Pixel_9_API_35
APP_ID       ?= com.flare.im.app
ACTIVITY     ?= $(APP_ID)/.MainActivity
APK          := app/build/outputs/apk/debug/app-debug.apk

# 后端联调用 flare_chat_server(flare-core 示例),默认空闲端口 60099
CHAT_PORT    ?= 60099
CHAT_BIN     ?= $(abspath ../../../../target/debug/examples/flare_chat_server)
CHAT_SRC     ?= $(abspath ../../../../flare-transport)

# 工具
ADB       := $(ANDROID_HOME)/platform-tools/adb
EMULATOR  := $(ANDROID_HOME)/emulator/emulator
# WS= 覆盖默认服务地址(注入 BuildConfig.DEFAULT_WS_URL)。例: make run WS=ws://10.0.2.2:60099/ws
WS        ?=
WS_PROP   := $(if $(WS),-PwsUrl=$(WS),)
GRADLE    := JAVA_HOME="$(JAVA_HOME)" ANDROID_HOME="$(ANDROID_HOME)" ./gradlew $(WS_PROP)
SHOT_DIR  ?= /tmp

export ANDROID_HOME

.DEFAULT_GOAL := help
.PHONY: help env compile build test check install run launch stop uninstall \
        emulator emulator-cold emulator-classic emulator-kill reverse \
        chat-server chat-server-stop chat-build logcat screenshot clean

help: ## 列出所有命令
	@echo "flare-core-android-app — make 目标:"
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "常用流程: make emulator-classic  →  make chat-server  →  make run"
	@echo "覆盖服务地址:   make run WS=ws://10.0.2.2:$(CHAT_PORT)/ws"

# ---- 构建门禁 ------------------------------------------------------------
env: ## 打印生效的工具链路径
	@echo "JAVA_HOME=$(JAVA_HOME)"; echo "ANDROID_HOME=$(ANDROID_HOME)"; echo "AVD=$(AVD)"
	@$(ADB) version | head -1

compile: ## 快速门禁: 只编译 Kotlin(最快, 抓编译错)
	$(GRADLE) :app:compileDebugKotlin --console=plain

build: ## 出包: assembleDebug -> $(APK)
	$(GRADLE) :app:assembleDebug --console=plain

test: ## 单元测试: testDebugUnitTest
	$(GRADLE) :app:testDebugUnitTest --console=plain

check: compile test ## 编译 + 单测(提交前)

clean: ## gradle clean
	$(GRADLE) :app:clean --console=plain

# ---- 部署/运行 -----------------------------------------------------------
install: build ## 构建并安装到当前模拟器/设备
	$(ADB) install -r -t -d $(APK)

run: install launch ## 构建+安装+启动 (推荐)

launch: ## 仅启动已安装的 app
	$(ADB) shell am force-stop $(APP_ID) || true
	$(ADB) shell am start -n $(ACTIVITY)

stop: ## 强制停止 app
	$(ADB) shell am force-stop $(APP_ID)

uninstall: ## 卸载 app
	$(ADB) uninstall $(APP_ID) || true

# ---- 模拟器 --------------------------------------------------------------
# 注意: VPN(默认路由走 utun)会让模拟器连不上宿主服务; 联调前请断开 VPN。
emulator: ## 普通启动模拟器(读快照)
	nohup $(EMULATOR) -avd $(AVD) -no-boot-anim >/tmp/emu.log 2>&1 & \
	$(ADB) wait-for-device

emulator-cold: ## 冷启动(不读快照, 干净网络状态)
	nohup $(EMULATOR) -avd $(AVD) -no-snapshot-load -no-boot-anim >/tmp/emu.log 2>&1 & \
	$(ADB) wait-for-device

emulator-classic: ## 冷启动 + 关 virtio-wifi(经典 slirp, 10.0.2.2 更可靠)
	-pkill -f 'qemu-system' 2>/dev/null; sleep 2
	nohup $(EMULATOR) -avd $(AVD) -no-snapshot-load -no-boot-anim -feature -VirtioWifi >/tmp/emu.log 2>&1 & \
	$(ADB) wait-for-device

emulator-kill: ## 关闭所有模拟器进程
	-$(ADB) emu kill 2>/dev/null; pkill -f 'qemu-system' 2>/dev/null; true

reverse: ## adb reverse 端口(绕过宿主 NAT/VPN, 配合 ws://127.0.0.1:$(CHAT_PORT))
	$(ADB) reverse tcp:$(CHAT_PORT) tcp:$(CHAT_PORT)
	@echo "已映射 模拟器 127.0.0.1:$(CHAT_PORT) -> 宿主 $(CHAT_PORT)"

# ---- 联调后端: flare_chat_server -----------------------------------------
chat-build: ## 编译 flare_chat_server 示例(flare-core)
	cd $(CHAT_SRC) && cargo build --example flare_chat_server

chat-server: ## 启动 flare_chat_server(WS-only, None 加密, 双栈), 端口 $(CHAT_PORT)
	@test -x "$(CHAT_BIN)" || $(MAKE) chat-build
	WS_BIND_ADDRESS='[::]:$(CHAT_PORT)' FLARE_WS_ONLY=1 RUST_LOG=info \
	  nohup "$(CHAT_BIN)" >/tmp/flare_chat_server.log 2>&1 & \
	  echo "flare_chat_server 起在 :$(CHAT_PORT) (日志 /tmp/flare_chat_server.log)"

chat-server-stop: ## 停止 flare_chat_server
	-pkill -f 'examples/flare_chat_server' 2>/dev/null; true

# ---- 观测 ----------------------------------------------------------------
logcat: ## 跟踪本 app 的日志
	$(ADB) logcat --pid=$$($(ADB) shell pidof $(APP_ID))

screenshot: ## 截屏到 $(SHOT_DIR)/android.png
	$(ADB) exec-out screencap -p > $(SHOT_DIR)/android.png
	@echo "已保存 $(SHOT_DIR)/android.png"
