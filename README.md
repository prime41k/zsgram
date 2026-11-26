# PRIME-41K — персональный мультиаккаунт-менеджер Telegram

Консольный инструмент для владельца **нескольких СВОИХ** Telegram-аккаунтов:
централизованное управление сессиями, заметки и задачи с напоминаниями,
FSM-диалоги в собственных чатах, шифрованное локальное хранилище и
polyglot-ядро (Python + Rust + Go + Zig + Node.js + Lua).

> **Границы инструмента (важно).** PRIME-41K автоматизирует только ваши
> собственные чаты (Saved Messages, диалоги с самим собой). Массовые
> рассылки, мутация текста «под человека», ротация аккаунтов против
> детекции — сознательно не реализованы. Автоматизация пользовательских
> аккаунтов регулируется Terms of Service Telegram; ответственность за
> соблюдение правил — на владельце.

## Состав

| Файл | Язык | Назначение |
| --- | --- | --- |
| `s.py` | Python | ядро: FSM, шина сообщений, менеджер аккаунтов, shell, SQLite, заметки, напоминания |
| `cs.rs` | Rust | Core Services: AES-256-GCM (чистый Rust), SHA-256/HMAC/HKDF, JSON, Aho-Corasick, энтропия, валидатор session strings |
| `nm.go` | Go | Network Manager: параллельный health-check, пул соединений, метрики, тревоги, HTTP API |
| `tb.js` | Node.js | Text Builder: Markdown→HTML, теги/категории, шаблоны, поиск (plain/fuzzy/boolean) |
| `bu.zig` | Zig | Buffer Utils: LZ4 block, кольцевой буфер, пулы памяти, CRC32, varint, JSON-сканер |
| `lh.lua` | Lua | Logic Hooks: guards/actions для FSM, валидаторы заметок/задач |
| `vocab.json` | JSON | словари: шаблоны заметок, категории, теги, приоритеты, фразы напоминаний |
| `build.sh` | bash | сборка бинарных патчей |
| `modules/` | — | пользовательские модули (загружаются в песочницу) |

## Установка

### Termux (Android)

```bash
pkg update && pkg upgrade -y
pkg install -y python rust go zig nodejs lua54 git binutils
pip install --upgrade pip wheel
pip install -r requirements.txt
./build.sh
```

### Linux / macOS

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
./build.sh
```

Все зависимости Python опциональны: без них ядро работает в оффлайн-режиме
на чистом stdlib. Внешние патчи (`cs`/`nm`/`bu`) тоже опциональны — ядро
честно сообщает, чего не хватает (`.patch_status`).

## Первый запуск

```bash
python s.py --init        # API ID/Hash (my.telegram.org), телефон, код, 2FA
python s.py --shell       # интерактивная консоль
python s.py --selftest    # автономные проверки ядра (без сети)
python s.py --status      # сводка и выход
python s.py --compile-all # пересборка cs/nm/bu
python s.py --no-telegram # оффлайн: только заметки/задачи/FSM
```

Данные живут в `data/` (база SQLite, мастер-ключ `secret.key` — **делайте
резервную копию каталога `data/`**: без ключа зашифрованные сессии не
восстанавливаются).

## Shell-команды (кратко)

- аккаунты: `.add_acc <метка> [--session S]`, `.list_acc`, `.remove_acc`, `.health`
- заметки: `.note <заголовок> :: <текст> #теги`, `.notes`, `.find <текст>`,
  `.mirror <id> [аккаунт]` (в «Избранное»), `.export`, `.import`
- задачи: `.task <название> @YYYY-MM-DD[THH:MM] [#high]`, `.tasks`, `.done <id>`
- FSM: `.show_graph`, `.force_state <chat> <state>`, `.reset_ctx <chat>`
- модули: `.load_mod <путь>`, `.reload_all`, `.modules`
- сборка/логи: `.compile_all [--force]`, `.patch_status`, `.tail_logs <n>`,
  `.audit <n>`, `.log_level LEVEL`, `.rotate_logs`
- обслуживание: `.backup`, `.vacuum`, `.status`, `.help`, `.quit`

Команды из собственных чатов: `.note`, `.task`, `.notes`, `.find`, `.help`,
`.s <путь|reply .py>`, `.m`, `.status`, `.health`, `.cancel` и др.

## Контракт IPC (единый для всех патчей)

```
stdin : {"op": "...", "v": 1, ...параметры}      (одна строка JSON)
stdout: {"ok": true,  "data": {...}}
        {"ok": false, "error": {"code": "...", "message": "..."}}
```

Loop-режим до EOF или `{"op":"quit"}`; прямые команды: `patches/cs selftest`,
`patches/nm --selftest`, `node tb.js --selftest`, `lua lh.lua --selftest`,
`patches/bu --selftest`. Полный список операций — в docstring `s.py`
(Приложение A).

## Пользовательские модули

```python
# modules/my_module.py
def run(api):
    """api: publish/on_event/create_note/find_notes/kv_*/logger."""
    api.logger.info("модуль запущен")
    return "готово"
```

Разрешённые импорты: `json math re time datetime random statistics
collections itertools functools textwrap unicodedata base64 hashlib hmac
uuid decimal string difflib`. Загрузка: `.load_mod modules/my_module.py`.

## Проверка и отладка

```bash
python s.py --selftest            # 16 проверок ядра (оффлайн)
patches/cs selftest               # 18 векторов (OpenSSL-эталон AES-GCM и др.)
patches/nm --selftest             # 12 проверок (loopback TCP/HTTP/пул/тревоги)
node tb.js --selftest             # 35 проверок (Markdown/поиск/IPC)
lua lh.lua --selftest             # 21 проверка (guards/pipeline/IPC)
patches/bu --selftest             # LZ4/буферы/сканер
```

## Тестировалось в сборке

- Python 3.12 (selftest ядра 16/16), Node 24 (tb 35/35)
- Rust 1.83.0 (cs selftest 18/18 + unit 7/7), Go 1.22.10 (nm 12/12)
- Zig 0.13.0, Lua 5.4.6 (lh 21/21)
- Целевая платформа Termux: совместимость API проверялась на stdlib-режимах

## Лицензия и ответственность

Личный инструмент для собственных аккаунтов. Автор кода не несёт
ответственности за использование вне этих границ. Ключ `data/secret.key` и
база с сессиями — конфиденциальные данные; не публикуйте их.
