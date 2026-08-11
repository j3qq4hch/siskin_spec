#!/usr/bin/env bash
#
# Прогон тестового корпуса по грамматике appendix/siskin-ir.rnc.
#
#   valid/    — обязаны пройти
#   invalid/  — обязаны быть отвергнуты, каждый на одно правило
#
# Нужен jing (github.com/relaxng/jing-trang, релиз V20241231 и новее) и Java.
# Путь к jar задаётся переменной JING; по умолчанию ищется в tools/.
#
#   JING=/path/to/jing.jar test/run.sh
#
# Выход 0 — все вердикты совпали с ожидаемыми, иначе 1.

set -u
cd "$(dirname "$0")/.."

SCHEMA="appendix/siskin-ir.rnc"

JING="${JING:-}"
if [ -z "$JING" ]; then
  for c in tools/jing/bin/jing.jar tools/jing-*/bin/jing.jar ../jing-*/bin/jing.jar; do
    [ -f "$c" ] && { JING="$c"; break; }
  done
fi

if [ -z "$JING" ] || [ ! -f "$JING" ]; then
  echo "jing.jar не найден." >&2
  echo "Скачайте релиз с github.com/relaxng/jing-trang и укажите путь:" >&2
  echo "  JING=/path/to/jing.jar $0" >&2
  exit 2
fi

run_jing() { java -jar "$JING" -c "$SCHEMA" "$@" 2>&1; }

fail=0
total=0

# --- сама схема ------------------------------------------------------
printf '%-42s ' "СХЕМА $SCHEMA"
out=$(run_jing)
if [ -z "$out" ]; then
  echo "ok"
else
  echo "ОШИБКА"
  printf '%s\n' "$out" | sed 's/^/    /'
  echo
  echo "Схема не разбирается — корпус не гонялся."
  exit 1
fi
echo

# --- корпус ----------------------------------------------------------
check() {              # check <файл> <pass|fail>
  local f="$1" want="$2" got out
  total=$((total + 1))
  out=$(run_jing "$f")
  [ -z "$out" ] && got=pass || got=fail
  if [ "$got" = "$want" ]; then
    printf '  %-46s %s\n' "$(basename "$f")" "ok"
  else
    fail=$((fail + 1))
    printf '  %-46s %s\n' "$(basename "$f")" "НЕОЖИДАННО: ждали $want, получили $got"
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/      /'
  fi
}

echo "ДОЛЖНЫ ПРОЙТИ"
for f in test/valid/*.siprj test/valid/*.silib; do
  [ -e "$f" ] && check "$f" pass
done

echo
echo "ДОЛЖНЫ БЫТЬ ОТВЕРГНУТЫ"
for f in test/invalid/*.siprj test/invalid/*.silib; do
  [ -e "$f" ] && check "$f" fail
done

echo
if [ "$fail" -eq 0 ]; then
  echo "Все $total совпали с ожидаемым."
  exit 0
else
  echo "Расхождений: $fail из $total."
  exit 1
fi
