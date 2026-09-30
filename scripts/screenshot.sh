#!/bin/sh
# Скриншот через grim. Вызывается из services/Screenshot.qml.
#   screenshot.sh <area|screen|window> <save 0|1> <copy 0|1> <notify 0|1> <title> <text-saved> <text-copied>
# window: список окон-областей "x,y wxh" передаётся в $REGIONS; screen: монитор в $OUTPUT.
mode=$1 save=$2 copy=$3 notify=$4 title=$5 text_saved=$6 text_copied=$7
[ "$save" = 1 ] || [ "$copy" = 1 ] || copy=1

dir=$(xdg-user-dir PICTURES 2>/dev/null)
[ -n "$dir" ] || dir=$HOME/Pictures
dir=$dir/Screenshots

geom=
case $mode in
    area) geom=$(slurp -d </dev/null) || exit 0 ;;
    window) geom=$(printf '%s\n' "$REGIONS" | slurp -r -d) || exit 0 ;;
esac

if [ "$save" = 1 ]; then
    mkdir -p "$dir" || exit 1
    out=$dir/$(date +%Y-%m-%d_%H-%M-%S).png
else
    out=$(mktemp --suffix=.png)
fi

if [ -n "$geom" ]; then grim -g "$geom" "$out" || exit 1
elif [ -n "$OUTPUT" ]; then grim -o "$OUTPUT" "$out" || exit 1
else grim "$out" || exit 1
fi

[ "$copy" = 1 ] && wl-copy --type image/png < "$out"

if [ "$notify" = 1 ]; then
    if [ "$save" = 1 ]; then body="$text_saved: $out"; else body=$text_copied; fi
    notify-send -a Quickshell -i "$out" "$title" "$body"
fi
[ "$save" = 1 ] || rm -f "$out"
