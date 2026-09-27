#!/bin/bash
# ThinkPad T14 Gen 1: platform::micmute follows the HDA audio-micmute trigger,
# but the microphone PipeWire uses is the AMD ACP DMIC. The LED never tracks
# wpctl, so drive it from the default source mute flag (1 = muted = lit).
set -u

led_dir=/sys/class/leds/platform::micmute
led=$led_dir/brightness

ensure_led() {
    [[ -e $led ]] || return 1
    if [[ ! -w $led ]]; then
        sudo -n chmod 0666 "$led" 2>/dev/null || true
    fi
    if grep -q '\[audio-micmute\]' "$led_dir/trigger" 2>/dev/null; then
        printf 'none\n' | sudo -n tee "$led_dir/trigger" >/dev/null || true
    fi
    [[ -w $led ]]
}

sync_led() {
    ensure_led || return 0
    local val=0
    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q '\[MUTED\]'; then
        val=1
    fi
    [[ $(<"$led") == "$val" ]] && return 0
    printf '%s\n' "$val" >"$led"
}

notify_avizo() {
    local line volume image=mic_unmuted progress
    line=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
    volume=${line#Volume: }
    volume=${volume%% *}
    [[ $line == *'[MUTED]'* ]] && image=mic_muted
    if darkman get 2>/dev/null | grep -qx dark; then
        image=${image}_dark
    fi
    progress=$(awk -v v="$volume" 'BEGIN { if (v+0 > 1) v = 1; printf "%.2f", v+0 }')
    avizo-client --image-resource="$image" --progress="$progress"
}

case ${1:-sync} in
    toggle)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        sync_led
        notify_avizo || true
        ;;
    watch)
        sync_led
        stdbuf -oL pactl subscribe | while IFS= read -r event; do
            case $event in
                *source*|*server*) sync_led ;;
            esac
        done
        ;;
    sync)
        sync_led
        ;;
    *)
        echo "usage: $0 {toggle|sync|watch}" >&2
        exit 2
        ;;
esac
