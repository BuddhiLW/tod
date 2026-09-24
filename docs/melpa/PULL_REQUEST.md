# MELPA pull request: Add recipe for tod

Recipe file `recipes/tod` in a fork of melpa/melpa (also `tod.recipe` here):

```elisp
(tod :fetcher github :repo "BuddhiLW/tod")
```

---

### Brief summary of what the package does

tod ("time of day") keeps the Emacs theme, and optionally the desktop
wallpaper, in step with the sun and the seasons at your location. It works
out the phase of the day (night, the three twilights, golden hour, day),
whether the sun is rising or setting, the astronomical season (flipped south
of the equator), the month and the calendar periods in effect, and ordered
rules in `tod-looks` turn that into a theme, a wallpaper, or a palette pywal
derives from the wallpaper, checked for WCAG contrast. `tod-mode` wakes at
every twilight boundary and at local midnight; `M-x tod-describe` shows the
sun, today's boundaries and the chosen look.

Similar packages: circadian.el and theme-changer switch between a day and a
night theme at sunrise and sunset; auto-dark follows the desktop's dark mode.
tod adds the twilight phases, seasons, months and holidays, wallpaper setters
for GNOME, KDE, Cinnamon, XFCE, sway, Hyprland and X11, and generated
contrast-checked palettes.

tod is written in ClojureElisp: every `tod*.el` is generated from `src/**/*.cljel`
in the same repository and committed. It depends on `clel`, the ClojureElisp
runtime, submitted first in its own pull request ("Add recipe for clel").

### Direct link to the package repository

https://github.com/BuddhiLW/tod

### Your association with the package

Maintainer.

### Relevant communications with the upstream package maintainer

**None needed**

### Checklist

- [x] The package is released under a GPL-Compatible Free Software License (GPL-3.0-or-later)
- [x] I've read CONTRIBUTING.org
- [ ] LLMs were used to generate some of the code, and if so, I've added an `Assisted-by:` line as described in CONTRIBUTING.org
- [x] I understand the package must have been maintained in a public repository for 1 month or more
- [x] I've used the latest version of package-lint to check for packaging issues, and addressed its feedback
- [x] My elisp byte-compiles cleanly
- [x] I've used `M-x checkdoc` to check the package's documentation strings
- [x] I've built and installed the package using the instructions in CONTRIBUTING.org

The repository has been public since 2026-09-24, so the month runs to
2026-10-24; until then this pull request stays a draft.

### Local checks behind the checklist

- `bb test` (62 ERT tests) and `bb lint` (byte-compile with warnings as
  errors, checkdoc, package-lint).
- melpazoid (Docker) with clel installed from the local clel.el: no findings
  apart from the repository URL, which resolves once it is public.
- `make recipes/clel recipes/tod` in a melpa/melpa clone, then
  `package-install 'tod` from that archive into a fresh `package-user-dir`:
  clel comes in as the dependency, `tod-mode` is autoloaded.

### Order

1. clel on MELPA (see clojure-elisp `docs/melpa/PULL_REQUEST.md`).
2. BuddhiLW/tod public (2026-09-24); CI fetches clel.el from the clojure-elisp
   v0.8.0 tag.
3. This pull request, a draft until clel is in MELPA and the month has passed.
