# tod — time of day

Themes and wallpapers that follow the sun and the seasons.

tod works out where the sun stands for your location — night, astronomical,
nautical and civil twilight, golden hour or day, and whether it is rising or
setting — together with the astronomical season (flipped south of the equator),
the month and the calendar periods in effect. Ordered rules turn that into a
*look*: an Emacs theme, a desktop wallpaper, and optionally a palette that
[pywal](https://github.com/eylles/pywal16) derives from the wallpaper and tod
repairs to readable contrast. `tod-mode` keeps the look current, waking at each
twilight boundary rather than polling.

tod is written in [ClojureElisp](https://github.com/BuddhiLW/clojure-elisp):
the sources are `src/**/*.cljel` and the `tod*.el` files at the root are
generated from them and committed.

## Setup

```elisp
(setq tod-latitude -3.73          ; or set calendar-latitude / calendar-longitude
      tod-longitude -38.52)
(tod-mode 1)
```

`M-x tod-describe` shows the sun, the season, today's boundaries, the look tod
picked and which wallpaper setters work in your session.

The default looks prefer the seasonal [ef-themes](https://protesilaos.com/emacs/ef-themes)
(`M-x tod-install-themes`) and fall back to the modus themes bundled with Emacs.

### Agenda

Put this in a diary or Org agenda file:

```org
%%(tod-diary-sun)
```

Each boundary becomes its own timed agenda line: astronomical twilight, sunrise,
the start of the day, golden hour, sunset and the dusks.

## Looks

`tod-looks` is an ordered list of rule plists. Criteria select when a rule
applies; every other key is an attribute. Each attribute comes from the first
matching rule that sets it, so a specific rule can pick the theme while a broad
one supplies the wallpaper.

```elisp
(setq tod-looks
      '((:period "Christmas" :wallpaper "~/Pictures/xmas/")
        (:phase night :season winter :theme (ef-winter modus-vivendi))
        (:phase night :theme modus-vivendi)
        (:phase golden-hour :rising t :theme ef-melissa-light)
        (:month (6 7 8) :palette wal)
        (:theme modus-operandi :wallpaper t)))
```

| Criterion   | Value |
|-------------|-------|
| `:phase`    | `night`, `astronomical-twilight`, `nautical-twilight`, `civil-twilight`, `golden-hour`, `day`, or a list |
| `:season`   | `spring`, `summer`, `autumn`, `winter`, or a list |
| `:month`    | 1–12, or a list |
| `:rising`   | `t` while the sun climbs, `nil` while it sinks |
| `:period`   | regexp matched against holiday and `tod-periods` names |
| `:hour`     | `(FROM TO)`, local hours, wrapping at midnight |
| `:altitude` | `(MIN MAX)` degrees, `nil` for an open end |
| `:moon`     | `new-moon`, `waxing-crescent`, `first-quarter`, `waxing-gibbous`, `full-moon`, `waning-gibbous`, `last-quarter`, `waning-crescent`, or a list |
| `:illumination` | `(MIN MAX)`, the moon's lit fraction from 0 to 1 |
| `:zodiac`   | the sun's tropical sign: `aries` … `pisces`, or a list |
| `:moon-sign`| the moon's tropical sign, or a list |
| `:element`  | element of the sun's sign: `fire`, `earth`, `air`, `water` |
| `:planet`   | ruler of the planetary hour: `sun`, `moon`, `mars`, `mercury`, `jupiter`, `venus`, `saturn` |
| `:day-ruler`| ruler of the planetary day, which begins at sunrise |
| `:when`     | a function of the moment |

New criteria are one entry in `tod-look-criteria`. The phase ladder itself is
`tod-phases`.

| Attribute    | Value |
|--------------|-------|
| `:theme`     | a theme, or a list of alternatives tried in order |
| `:wallpaper` | a file, a directory to pick from, or `t` for the layout below |
| `:palette`   | `wal` to build the theme from the wallpaper with pywal, `sky` to paint it from the sky |

## The sky

Every moment also carries the moon, the zodiac and the planetary hour, so
rules can match them and `M-x tod-describe` lists them:

```
Moon       Waxing gibbous, 77% lit, 10.1 days old, down (-25° altitude)
Sun sign   Libra 28°, decan 3, cardinal air
Moon sign  Pisces
Day ruler  Mercury
Hour       Venus, planetary hour 7 of 24 (11:23 to 12:24)
```

The moon follows the main terms of Meeus, *Astronomical Algorithms*,
chapter 47, to a few tenths of a degree. Signs are tropical. Planetary
hours split daylight and darkness into twelve unequal hours each, ruled
in Chaldean order from the planet of the weekday at sunrise; where the
sun neither rises nor sets they fall back to clock hours from 06:00.
`tod-mode` wakes at every planetary hour as well as at every twilight
boundary.

```elisp
(setq tod-looks
      '((:moon full-moon :phase night :theme ef-dream)
        (:planet saturn :phase day :theme ef-frost)
        (:palette sky)))
```

### Sky palette

With `:palette sky` tod paints its own theme, `tod-sky`, from the sky and
repaints it every `tod-sky-interval` seconds (300 by default). The
background follows the sun's altitude through midnight blue, violet
twilight, amber golden hour and clear noon; a setting sun is warmer than a
rising one, morning light is cooler than afternoon light, a high bright
moon silvers the night, and the element of the sun's sign tints it.
Accents grow more vivid as the sun climbs and warm while it is low, and
the cursor takes the colour of the planet ruling the hour. Every colour
is repaired to `tod-minimum-contrast` against the background, body text
to 7:1.

## Wallpapers

With `:wallpaper t`, tod looks under `tod-wallpaper-directory` (default
`~/Pictures/tod`) in this order, using `any` as a wildcard:

```
_period/NAME/PHASE   _period/NAME/any
_month/MM/PHASE      _month/MM/any
SEASON/PHASE         any/PHASE      SEASON/any      any/any
```

Within a directory the choice is stable for a given day and phase and rotates
across days. Stills go to the first ready setter for your session: GNOME
(`picture-uri` and `picture-uri-dark`), Cinnamon, MATE, KDE Plasma, Xfce,
hyprpaper, sway, swww, swaybg, feh, xwallpaper or nitrogen. Videos and GIFs go
to [lazywal](https://github.com/BuddhiLW/lazywal) when it has a ready backend;
otherwise tod shows a still frame. Add a setter without touching tod:

```elisp
(tod-wallpaper-register-setter
 '((:id . wpaperd) (:kind . image) (:session wayland) (:priority . 70)
   (:requires "wpaperctl") (:commands ("wpaperctl" "set" "{path}"))))
```

## Palettes and contrast

With `:palette wal`, pywal derives colours from the wallpaper (a light scheme
while the sun is up) and tod maps them to meanings by hue — red, orange,
yellow, green, cyan, blue, magenta — synthesising any the wallpaper lacks, then
lightens or darkens each one until it reaches `tod-minimum-contrast` (WCAG AA,
4.5:1) against the background; body text reaches 7:1. With modus-themes 5.2 or
later the palette is expanded into a full modus theme.

pywal runs isolated in tod's cache by default. Set `tod-palette-scope` to
`system` to let it recolour terminals and other programs as lazywal does.

## Development

The runtime, [clel](https://melpa.org/#/clel), comes from MELPA like any
other dependency; `scripts/deps.el` installs it into `.cache/elpa` for the
batch runs below and for CI.

```
bb compile          # src/**/*.cljel -> tod*.el
bb runtime          # install clel from MELPA into .cache/elpa
bb test             # ERT suite in emacs -Q --batch
bb lint             # byte-compile (warnings are errors), checkdoc, package-lint
bb check-generated  # fail when the committed tod*.el are stale
```

## License

GPL-3.0-or-later.
