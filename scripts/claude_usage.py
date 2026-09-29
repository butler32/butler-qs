#!/usr/bin/env python3
# Оставшийся процент лимитов подписки Claude Code: дёргает встроенную команду
# `claude -p "/usage" --output-format json` — локальная и бесплатная (total_cost_usd
# всегда 0, до модели не доходит), просто отдаёт то же, что показывает /usage в
# интерактивной сессии — и парсит проценты/время сброса из текста ответа.
# Вызывается из services/ClaudeUsage.qml. При любой ошибке печатает null'ы, чтобы
# JSON.parse на стороне QML не падал.
import json
import os
import re
import shutil
import subprocess

FALLBACKS = ["/home/butler/.local/bin/claude", "/usr/local/bin/claude", "/usr/bin/claude"]


def find_claude():
    p = shutil.which("claude")
    if p:
        return p
    for p in FALLBACKS:
        if os.path.isfile(p):
            return p
    return None


def parse(text):
    out = {"session": None, "week": None}
    m = re.search(r"Current session:\s*(\d+)%\s*used\s*·\s*resets\s*(.+)", text)
    if m:
        out["session"] = {"used": int(m.group(1)), "resets": m.group(2).strip()}
    m = re.search(r"Current week \(all models\):\s*(\d+)%\s*used\s*·\s*resets\s*(.+)", text)
    if m:
        out["week"] = {"used": int(m.group(1)), "resets": m.group(2).strip()}
    return out


def main():
    exe = find_claude()
    if not exe:
        print(json.dumps({"session": None, "week": None}))
        return
    try:
        proc = subprocess.run([exe, "-p", "/usage", "--output-format", "json"],
                               capture_output=True, text=True, timeout=20)
        data = json.loads(proc.stdout)
        result = parse(data.get("result", ""))
    except Exception:
        result = {"session": None, "week": None}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
