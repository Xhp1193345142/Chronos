SHELL := /bin/sh
.DEFAULT_GOAL := help
export FLUTTER_SUPPRESS_ANALYTICS := true
export ANDROID_USER_HOME ?= $(HOME)/.android

FLUTTER_FOUND := $(or $(shell command -v flutter 2>/dev/null),$(firstword $(wildcard /private/tmp/chronos-flutter-sdk/bin/flutter)))
FLUTTER ?= $(if $(FLUTTER_FOUND),$(FLUTTER_FOUND),flutter)
DART ?= $(if $(filter %/flutter,$(FLUTTER)),$(patsubst %/flutter,%/dart,$(FLUTTER)),dart)
ADB ?= adb
PYTHON ?= python3
PORT ?= 8765
HOST ?= 127.0.0.1
WEB_DIR := $(CURDIR)/build/web
PID_FILE := $(CURDIR)/build/preview-$(PORT).pid
LOG_FILE := $(CURDIR)/build/preview-$(PORT).log
PREVIEW_COMMAND := -m http.server $(PORT) --bind $(HOST) --directory $(WEB_DIR)

.PHONY: help deps devices run-web run-android format format-check analyze test check \
	build-web build-apk build-aab build-ios release-check icons preview-build start stop restart status logs serve doctor

help:
	@printf '%s\n' \
	  'Chronos 常用命令' \
	  '  make start                  构建并启动 Web 演示；缺少 Flutter 时使用现有构建' \
	  '  make status|logs|stop      查看预览状态、日志或停止服务' \
	  '  make restart                重启预览，Flutter 可用时先重建' \
	  '  make serve                  在前台运行 Web 预览' \
	  '  make run-web                用 Flutter 在 Chrome 中调试演示版' \
	  '  make run-android DEVICE=id  安全覆盖安装并启动 Android 调试版' \
	  '  make devices                列出 Flutter 可用设备' \
	  '  make deps                   安装 Flutter 依赖' \
	  '  make format|check           格式化代码或运行格式/分析/测试检查' \
	  '  make build-web|build-apk    构建 Web 演示或 Android 调试 APK' \
	  '  make release-check          查看双端发布准备检查' \
	  '  make build-aab              正式签名 Android App Bundle' \
	  '  make build-ios              构建 iOS archive（需要完整 Xcode）' \
	  '  make icons                  从品牌源图重新生成平台图标' \
	  '可覆盖参数：PORT=8765 HOST=127.0.0.1 FLUTTER=/path/to/flutter'

deps:
	$(FLUTTER) pub get

devices:
	$(FLUTTER) devices

run-web:
	$(FLUTTER) run -d chrome

run-android:
	@if [ -z "$(DEVICE)" ]; then echo '请指定设备：make run-android DEVICE=<device-id>'; exit 2; fi
	@$(MAKE) --no-print-directory build-apk
	$(ADB) -s "$(DEVICE)" install -r "$(CURDIR)/build/app/outputs/flutter-apk/app-debug.apk"
	$(ADB) -s "$(DEVICE)" shell am start -n com.xhp.chronos/.MainActivity

format:
	$(DART) format .

format-check:
	$(DART) format --output=none --set-exit-if-changed lib test

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

check: format-check analyze test

build-web:
	$(FLUTTER) build web

# Keep the last successful preview usable if a temporary Flutter SDK vanished.
preview-build:
	@if command -v "$(FLUTTER)" >/dev/null 2>&1; then \
	  $(MAKE) --no-print-directory build-web FLUTTER="$(FLUTTER)"; \
	elif [ -f "$(WEB_DIR)/index.html" ]; then \
	  echo 'Flutter 未安装；使用上次成功构建的 Web 预览。'; \
	else \
	  echo 'Flutter 未安装且没有 Web 构建。请安装 Flutter 后运行 make start。'; exit 1; \
	fi

build-apk:
	$(FLUTTER) build apk --debug

icons:
	$(PYTHON) tools/generate_icons.py

doctor:
	$(FLUTTER) doctor -v

# Store the PID under build/ so stopping the preview only targets this checkout.
start: preview-build
	@mkdir -p "$(CURDIR)/build"; \
	if [ -f "$(PID_FILE)" ]; then \
	  pid=$$(cat "$(PID_FILE)"); \
	  command=$$(ps -p "$$pid" -o command= 2>/dev/null || true); \
	  if printf '%s' "$$command" | grep -Fq -- '$(PREVIEW_COMMAND)'; then \
	    echo '预览已运行：http://$(HOST):$(PORT)/'; exit 0; \
	  fi; \
	  rm -f "$(PID_FILE)"; \
	fi; \
	if lsof -nP -iTCP:$(PORT) -sTCP:LISTEN -t >/dev/null 2>&1; then \
	  echo '端口 $(PORT) 已被其他进程占用；没有停止该进程。'; exit 1; \
	fi; \
	pid=$$($(PYTHON) -c 'import subprocess, sys; log = open(sys.argv[1], "ab", buffering=0); server = subprocess.Popen([sys.executable, "-m", "http.server", sys.argv[2], "--bind", sys.argv[3], "--directory", sys.argv[4]], stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, start_new_session=True); print(server.pid)' "$(LOG_FILE)" "$(PORT)" "$(HOST)" "$(WEB_DIR)"); \
	echo "$$pid" >"$(PID_FILE)"; \
	i=0; while [ $$i -lt 30 ]; do \
	  if curl --noproxy '*' -fsS -o /dev/null "http://127.0.0.1:$(PORT)/" 2>/dev/null; then \
	    echo '预览已启动：http://$(HOST):$(PORT)/'; exit 0; \
	  fi; \
	  i=$$((i + 1)); sleep 0.2; \
	done; \
	echo '预览启动失败，请运行 make logs 查看原因。'; exit 1

stop:
	@if [ ! -f "$(PID_FILE)" ]; then echo '没有由 Makefile 启动的预览服务。'; exit 0; fi; \
	pid=$$(cat "$(PID_FILE)"); \
	command=$$(ps -p "$$pid" -o command= 2>/dev/null || true); \
	if printf '%s' "$$command" | grep -Fq -- '$(PREVIEW_COMMAND)'; then \
	  kill "$$pid"; echo '预览已停止。'; \
	else \
	  echo '预览进程已退出；已清理过期 PID 文件。'; \
	fi; \
	rm -f "$(PID_FILE)"

restart:
	@$(MAKE) --no-print-directory stop PORT=$(PORT) HOST=$(HOST)
	@$(MAKE) --no-print-directory start PORT=$(PORT) HOST=$(HOST)

status:
	@if [ -f "$(PID_FILE)" ]; then \
	  pid=$$(cat "$(PID_FILE)"); \
	  command=$$(ps -p "$$pid" -o command= 2>/dev/null || true); \
	  if printf '%s' "$$command" | grep -Fq -- '$(PREVIEW_COMMAND)'; then \
	    echo "预览运行中（PID $${pid}）：http://$(HOST):$(PORT)/"; exit 0; \
	  fi; \
	fi; \
	if lsof -nP -iTCP:$(PORT) -sTCP:LISTEN -t >/dev/null 2>&1; then \
	  echo '端口 $(PORT) 有其他进程监听，非此 Makefile 管理。'; exit 1; \
	fi; \
	echo '预览未运行。'; exit 1

logs:
	@if [ ! -f "$(LOG_FILE)" ]; then echo '暂无预览日志。'; exit 1; fi
	@tail -n 50 -f "$(LOG_FILE)"

serve: preview-build
	$(PYTHON) $(PREVIEW_COMMAND)

# Production artifacts require real signing credentials; no debug fallback.
build-aab:
	$(FLUTTER) build appbundle --release

build-ios:
	$(FLUTTER) build ipa --release

release-check:
	$(PYTHON) tools/release_check.py
