#!/bin/bash
# ============================================================================
#  PRIME-41K — сборка бинарных патчей (Rust / Go / Zig)
#  Проверка окружения Termux: pkg install -y python rust go zig nodejs lua54
# ============================================================================
set -e
cd "$(dirname "$0")"
mkdir -p patches

have() { command -v "$1" >/dev/null 2>&1; }

echo "==> Проверка окружения"
python3 --version || python --version || true
for tool in rustc go zig node lua; do
    if have "$tool"; then echo "  ✓ $tool: $(command -v $tool)"
    else echo "  ✗ $tool: не найден (соответствующий патч будет пропущен)"; fi
done

if have rustc; then
    echo "==> Сборка Rust (cs.rs -> patches/cs)"
    rustc cs.rs -o patches/cs --edition 2021 -O
    ./patches/cs selftest >/dev/null && echo "  ✓ cs: selftest OK"
fi

if have go; then
    echo "==> Сборка Go (nm.go -> patches/nm)"
    go build -trimpath -ldflags='-s -w' -o patches/nm nm.go
    ./patches/nm --selftest >/dev/null && echo "  ✓ nm: selftest OK"
fi

if have zig; then
    echo "==> Сборка Zig (bu.zig -> patches/bu)"
    zig build-exe bu.zig -O ReleaseSafe -femit-bin=patches/bu
    ./patches/bu --selftest >/dev/null && echo "  ✓ bu: selftest OK"
fi

echo "==> Скрипты (tb.js / lh.lua) интерпретируются, сборка не нужна"
have node && node --check tb.js && echo "  ✓ tb.js: синтаксис OK"
have lua && lua -e "assert(loadfile('lh.lua'))" && echo "  ✓ lh.lua: синтаксис OK"

echo "==> Готово. Запуск ядра: python s.py --selftest ; python s.py --shell"
