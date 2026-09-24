;;; tod-sun-test.el --- Tests for tod-sun and tod-moment -*- lexical-binding: t; -*-

;;; Commentary:

;; Reference instants were cross-checked against an independent NOAA
;; implementation (agreement within a minute) when tod was designed.
;; Zones are named explicitly so the suite does not depend on the
;; machine's TZ.

;;; Code:

(require 'ert)
(require 'tod-sun)
(require 'tod-moment)

(defconst tod-sun-test--fortaleza '(-3.73 -38.52))
(defconst tod-sun-test--copenhagen '(55.68 12.57))
(defconst tod-sun-test--longyearbyen '(78.22 15.65))

(defun tod-sun-test--crossing-strings (date place height zone)
  "Format the crossings of DATE at PLACE for HEIGHT in ZONE."
  (mapcar (lambda (tm) (and tm (format-time-string "%F %T" tm zone)))
          (tod-sun-crossings date (nth 0 place) (nth 1 place) height)))

(defun tod-sun-test--at (spec zone)
  "Encode the local SPEC (SEC MIN HOUR DAY MONTH YEAR) in ZONE."
  (encode-time (append spec (list nil -1 zone))))

(ert-deftest tod-sun-crossings-match-reference-instants ()
  (should (equal (tod-sun-test--crossing-strings '(9 23 2026) tod-sun-test--fortaleza -0.833 "America/Fortaleza")
                 '("2026-09-23 05:23:16" "2026-09-23 17:29:36")))
  (should (equal (tod-sun-test--crossing-strings '(9 23 2026) tod-sun-test--fortaleza -18.0 "America/Fortaleza")
                 '("2026-09-23 04:14:22" "2026-09-23 18:38:30")))
  (should (equal (tod-sun-test--crossing-strings '(12 21 2026) tod-sun-test--copenhagen -0.833 "Europe/Copenhagen")
                 '("2026-12-21 08:37:12" "2026-12-21 15:38:22"))))

(ert-deftest tod-sun-polar-day-has-no-crossing-but-twilight-still-does ()
  (should (equal (tod-sun-crossings '(6 21 2026) 78.22 15.65 -0.833) '(nil nil)))
  (should (equal (tod-sun-test--crossing-strings '(12 21 2026) tod-sun-test--longyearbyen -18.0 "Europe/Oslo")
                 '("2026-12-21 07:37:03" "2026-12-21 16:13:51"))))

(ert-deftest tod-sun-position-at-noon ()
  (let ((noon (tod-sun-test--at '(0 0 12 23 9 2026) "America/Fortaleza")))
    (should (< (abs (- (tod-sun-altitude noon -3.73 -38.52) 80.911)) 0.01))
    (should (< (abs (- (tod-sun-azimuth noon -3.73 -38.52) 292.38)) 0.05))
    (should-not (tod-sun-rising-p noon -3.73 -38.52))
    (should (tod-sun-rising-p (tod-sun-test--at '(0 0 9 23 9 2026) "America/Fortaleza") -3.73 -38.52))))

(ert-deftest tod-sun-seasons-flip-by-hemisphere ()
  (let ((after-equinox (tod-sun-test--at '(0 0 12 23 9 2026) "UTC"))
        (before-equinox (tod-sun-test--at '(0 0 12 22 9 2026) "UTC"))
        (december (tod-sun-test--at '(0 0 12 30 12 2026) "UTC")))
    (should (eq (tod-sun-season after-equinox 55.68) 'autumn))
    (should (eq (tod-sun-season after-equinox -3.73) 'spring))
    (should (eq (tod-sun-season before-equinox 55.68) 'summer))
    (should (eq (tod-sun-season before-equinox -3.73) 'winter))
    (should (eq (tod-sun-season december 55.68) 'winter))
    (should (eq (tod-sun-season december -33.9) 'summer))
    (let ((p (tod-sun-season-progress after-equinox 55.68)))
      (should (and (>= p 0.0) (< p 0.05))))))

(ert-deftest tod-sun-next-event-is-the-next-boundary ()
  (let* ((evening (tod-sun-test--at '(0 50 20 23 9 2026) "America/Fortaleza"))
         (e (tod-sun-next-event evening -3.73 -38.52 '(6.0 -0.833 -6.0 -12.0 -18.0))))
    (should (equal (format-time-string "%F %H:%M" (alist-get :time e) "America/Fortaleza")
                   "2026-09-24 04:14"))
    (should (= (alist-get :height e) -18.0))
    (should (alist-get :rising e))))

(ert-deftest tod-moment-phase-ladder ()
  (let ((ladder tod-moment-default-ladder))
    (should (eq (tod-moment-phase-for-altitude ladder 45.0) 'day))
    (should (eq (tod-moment-phase-for-altitude ladder 6.0) 'day))
    (should (eq (tod-moment-phase-for-altitude ladder 3.0) 'golden-hour))
    (should (eq (tod-moment-phase-for-altitude ladder -3.0) 'civil-twilight))
    (should (eq (tod-moment-phase-for-altitude ladder -9.0) 'nautical-twilight))
    (should (eq (tod-moment-phase-for-altitude ladder -15.0) 'astronomical-twilight))
    (should (eq (tod-moment-phase-for-altitude ladder -50.0) 'night))
    (should (eq (tod-moment-phase-for-altitude ladder -95.0) 'night))
    (should (equal (tod-moment-ladder-heights ladder) '(6.0 -0.833 -6.0 -12.0 -18.0)))))

(ert-deftest tod-moment-spans-wrap-the-new-year ()
  (should (tod-moment-in-span-p '(12 28 2026) '(12 19) '(1 3)))
  (should (tod-moment-in-span-p '(1 2 2027) '(12 19) '(1 3)))
  (should-not (tod-moment-in-span-p '(1 4 2027) '(12 19) '(1 3)))
  (should (tod-moment-in-span-p '(7 1 2026) '(6 21) '(9 22)))
  (should (equal (tod-moment-span-names '(12 24 2026) '(("Juleferie" (12 19) (1 3)) ("Summer" (6 21) (9 22))))
                 '("Juleferie"))))

(ert-deftest tod-moment-holidays-come-from-calendar-lists ()
  (let ((hols '((holiday-fixed 12 25 "Christmas") (holiday-easter-etc 0 "Easter"))))
    (should (equal (tod-moment-holiday-names '(12 25 2026) hols) '("Christmas")))
    (should (equal (tod-moment-holiday-names '(4 5 2026) hols) '("Easter")))
    (should-not (tod-moment-holiday-names '(7 1 2026) hols))))

(ert-deftest tod-moment-at-assembles-everything ()
  (let* ((time (tod-sun-test--at '(0 50 20 23 9 2026) "America/Fortaleza"))
         (m (let ((process-environment (cons "TZ=America/Fortaleza" process-environment)))
              (set-time-zone-rule "America/Fortaleza")
              (unwind-protect
                  (tod-moment-at time -3.73 -38.52 tod-moment-default-ladder nil
                                 '(("Spring break" (9 20) (9 27))))
                (set-time-zone-rule nil)))))
    (should (eq (alist-get :phase m) 'night))
    (should (eq (alist-get :season m) 'spring))
    (should (= (alist-get :month m) 9))
    (should (= (alist-get :hour m) 20))
    (should (equal (alist-get :periods m) '("Spring break")))
    (should (< (alist-get :altitude m) -18.0))))

(ert-deftest tod-moment-next-change-and-polar-silence ()
  (let ((evening (tod-sun-test--at '(0 50 20 23 9 2026) "America/Fortaleza")))
    (should (equal (format-time-string "%H:%M" (tod-moment-next-change evening -3.73 -38.52 tod-moment-default-ladder)
                                       "America/Fortaleza")
                   "04:14")))
  (should-not (tod-moment-next-change (tod-sun-test--at '(0 0 12 21 6 2026) "UTC")
                                      85.0 0.0 tod-moment-default-ladder)))

;;; tod-sun-test.el ends here
