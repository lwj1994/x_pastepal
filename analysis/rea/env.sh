#!/bin/sh
# 当前机器 REA 原生分析环境；用 . ./analysis/rea/env.sh 载入。
# 将真实 Node 放在 mise shim 前，避免 shim 把 JAVA_HOME 重置为项目的 Java 17。
export PATH="/Users/luwenjie/.local/share/mise/installs/node/26.0.0/bin:/opt/homebrew/opt/openjdk@21/bin:$PATH"
export GHIDRA_INSTALL_DIR="/opt/homebrew/opt/ghidra/libexec"
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export REA_GHIDRA_STARTUP_TIMEOUT_MS="1200000"
