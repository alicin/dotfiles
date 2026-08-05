pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Current conditions for the calendar popout, from open-meteo (no API key).
//
// Deliberately lazy: nothing is fetched until something asks for it by holding
// `wanted` — opening the calendar. A shell that phones home every 30 minutes
// whether or not you ever look at the weather is not a trade this earns.
//
// Location comes from settings.json (`weatherPlace: "lat,lon"`) when set, and
// otherwise once from a coarse IP lookup, cached on disk so the lookup happens
// at most once per machine rather than once per shell start.
Singleton {
    id: root

    // Held by whatever is displaying it (the calendar menu, via a Binding).
    // Refs, not a bool, so two menus on two monitors don't switch it off for
    // each other.
    property int wanted: 0

    property string place: ""
    property real temp: 0
    property real high: 0
    property real low: 0
    property int code: -1
    property bool day: true
    property bool loading: false
    // "" while fine; a short human line when the fetch failed, so the row says
    // something rather than sitting blank forever.
    property string error: ""

    readonly property bool valid: code >= 0

    // WMO weather interpretation codes (open-meteo's `weather_code`).
    readonly property string label: {
        const c = root.code;
        if (c === 0)
            return "Clear";
        if (c <= 2)
            return "Partly cloudy";
        if (c === 3)
            return "Overcast";
        if (c <= 48)
            return "Fog";
        if (c <= 57)
            return "Drizzle";
        if (c <= 67)
            return "Rain";
        if (c <= 77)
            return "Snow";
        if (c <= 82)
            return "Showers";
        if (c <= 86)
            return "Snow showers";
        return "Thunderstorm";
    }

    readonly property string glyph: {
        const c = root.code;
        if (c === 0)
            return root.day ? "sun_max_fill" : "moon_fill";
        if (c <= 2)
            return root.day ? "cloud_sun_fill" : "cloud_moon_fill";
        if (c === 3)
            return "cloud_fill";
        if (c <= 48)
            return "cloud_fog_fill";
        if (c <= 57)
            return "cloud_drizzle_fill";
        if (c <= 67)
            return "cloud_rain_fill";
        if (c <= 77)
            return "cloud_snow_fill";
        if (c <= 82)
            return "cloud_heavyrain_fill";
        if (c <= 86)
            return "cloud_sleet_fill";
        return "cloud_bolt_fill";
    }

    // Wall-clock of the last successful reading, so a menu opened hours later
    // doesn't show this morning's weather as current.
    property real fetchedAt: 0

    readonly property int maxAge: 20 * 60 * 1000

    function refresh(): void {
        if (!Settings.weather || fetcher.running)
            return;
        root.loading = true;
        fetcher.running = true;
    }

    // Opening fetches when there's nothing, or when what there is has gone
    // stale. The periodic timer only runs while something is watching, so
    // between menus nothing is kept fresh — and shouldn't be.
    onWantedChanged: {
        if (wanted > 0 && (!valid || Date.now() - fetchedAt > root.maxAge))
            refresh();
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: root.wanted > 0
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher

        // One pipeline rather than a chain of QML Processes: the geocode is a
        // one-time prerequisite of the forecast, and splitting them across two
        // stdout handlers only adds states that can disagree.
        //
        // The configured place travels as an *argument*, not interpolated into
        // the script — it comes out of an editable JSON file, and a stray quote
        // in it would otherwise be shell syntax.
        command: ["sh", "-c", `
            set -e
            cache="\${XDG_CACHE_HOME:-$HOME/.cache}/qshell-weather-loc"
            place="$1"
            if [ -n "$place" ]; then
                loc="$(echo "$place" | tr ',' ' ')"
            else
                loc="$(cat "$cache" 2>/dev/null || true)"
                # Three providers, because the free tiers rate-limit and a
                # 429 is indistinguishable from "no network" once curl -f has
                # swallowed it. Whichever answers first is cached, and the
                # lookup then never runs again on this machine.
                for url in https://ipwho.is/ https://ipapi.co/json http://ip-api.com/json/; do
                    [ -n "$loc" ] && break
                    loc="$(curl -sf --max-time 6 "$url" \\
                        | jq -r 'select((.latitude // .lat) != null)
                                 | "\\(.latitude // .lat) \\(.longitude // .lon) \\(.city // "")"' 2>/dev/null)"
                done
                [ -n "$loc" ] && printf '%s\\n' "$loc" > "$cache"
            fi
            [ -n "$loc" ] || { echo '{"err":"no location"}'; exit 0; }
            set -- $loc
            lat=$1
            lon=$2
            shift 2 || true
            city="$*"
            curl -sf --max-time 8 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,is_day&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1" \
                | jq -c --arg city "$city" '{
                    place: $city,
                    t: .current.temperature_2m,
                    code: .current.weather_code,
                    day: .current.is_day,
                    hi: .daily.temperature_2m_max[0],
                    lo: .daily.temperature_2m_min[0]
                  }' || echo '{"err":"fetch failed"}'
        `, "qshell-weather", Settings.weatherPlace]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                let j = null;
                try {
                    j = JSON.parse(text.trim());
                } catch (e) {
                    root.error = "Weather unavailable";
                    return;
                }
                if (!j || j.err || j.code === undefined || j.code === null) {
                    root.error = "Weather unavailable";
                    return;
                }
                root.error = "";
                root.fetchedAt = Date.now();
                root.place = j.place ?? "";
                root.temp = j.t ?? 0;
                root.high = j.hi ?? 0;
                root.low = j.lo ?? 0;
                root.day = (j.day ?? 1) === 1;
                // Last, so `valid` flipping true always finds the rest set.
                root.code = j.code;
            }
        }
    }
}
