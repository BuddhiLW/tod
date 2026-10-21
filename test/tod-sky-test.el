;;; tod-sky-test.el --- Tests for tod-sky, tod-gradient and the sky criteria -*- lexical-binding: t; -*-

;;; Commentary:

;; Lunar reference instants are the published new and full moons of
;; January 2024; the longitude check is Meeus, Astronomical Algorithms,
;; example 47.a.  Zones are named explicitly so the suite does not depend
;; on the machine's TZ.

;;; Code:

(require 'ert)
(require 'tod-sky)
(require 'tod-gradient)
(require 'tod-look)
(require 'tod-moment)
(require 'tod-color)

(defun tod-sky-test--utc (spec)
  "Encode the UTC SPEC (SEC MIN HOUR DAY MONTH YEAR)."
  (encode-time (append spec (list nil nil t))))

(defmacro tod-sky-test--in-zone (zone &rest body)
  "Run BODY with the local time zone set to ZONE."
  (declare (indent 1))
  `(progn (set-time-zone-rule ,zone)
          (unwind-protect (progn ,@body) (set-time-zone-rule nil))))

(ert-deftest tod-sky-moon-longitude-matches-meeus ()
  (let ((pos (tod-sky-moon-ecliptic (tod-sky-test--utc '(0 0 0 12 4 1992)))))
    (should (< (abs (- (nth 0 pos) 133.163)) 0.3))
    (should (< (abs (- (nth 1 pos) -3.229)) 0.3))))

(ert-deftest tod-sky-phases-at-new-and-full-moon ()
  (let ((full (tod-sky-test--utc '(0 54 17 25 1 2024)))
        (new (tod-sky-test--utc '(0 57 11 11 1 2024))))
    (should (eq (tod-sky-moon-phase full) 'full-moon))
    (should (> (tod-sky-illumination full) 0.99))
    (should (eq (tod-sky-moon-phase new) 'new-moon))
    (should (< (tod-sky-illumination new) 0.01))
    (should (eq (tod-sky-phase-for-elongation 90.0) 'first-quarter))
    (should (eq (tod-sky-phase-for-elongation 300.0) 'waning-crescent))))

(ert-deftest tod-sky-signs-elements-and-rulers ()
  (should (eq (tod-sky-sign 0.5) 'aries))
  (should (eq (tod-sky-sign 215.0) 'scorpio))
  (should (eq (tod-sky-sign 359.9) 'pisces))
  (should (eq (tod-sky-element 215.0) 'water))
  (should (eq (tod-sky-modality 215.0) 'fixed))
  (should (eq (tod-sky-sign-ruler 125.0) 'sun))
  (should (= (tod-sky-decan 215.0) 1))
  (should (= (tod-sky-decan 228.0) 2))
  (let ((equinox-week (tod-sky-test--utc '(0 0 12 25 3 2026))))
    (should (eq (tod-sky-sign (tod-sun-ecliptic-longitude equinox-week)) 'aries))))

(ert-deftest tod-sky-planetary-hours-follow-chaldean-order ()
  (should (eq (tod-sky-hour-ruler 'sun 0) 'sun))
  (should (eq (tod-sky-hour-ruler 'sun 1) 'venus))
  (should (eq (tod-sky-hour-ruler 'saturn 7) 'saturn))
  ;; The first hour of the next day is that day's ruler.
  (should (eq (tod-sky-hour-ruler 'sun 24) 'moon))
  (tod-sky-test--in-zone "America/Fortaleza"
    (let* ((noon (encode-time '(0 0 12 21 10 2026 nil -1 "America/Fortaleza")))
           (h (tod-sky-planetary-hour noon -3.73 -38.52)))
      (should (eq (alist-get :day-ruler h) 'mercury))
      (should (= (alist-get :hour h) 7))
      (should (eq (alist-get :planet h) 'venus))
      (should (alist-get :daytime h))
      (should (time-less-p (alist-get :start h) noon))
      (should (time-less-p noon (alist-get :end h))))
    (let* ((night (encode-time '(0 0 22 21 10 2026 nil -1 "America/Fortaleza")))
           (h (tod-sky-planetary-hour night -3.73 -38.52)))
      (should-not (alist-get :daytime h))
      (should (eq (alist-get :day-ruler h) 'mercury))
      (should (> (alist-get :hour h) 12)))))

(ert-deftest tod-sky-polar-day-falls-back-to-clock-hours ()
  (tod-sky-test--in-zone "UTC"
    (let ((h (tod-sky-planetary-hour (tod-sky-test--utc '(0 30 12 21 6 2026)) 85.0 0.0)))
      (should (= (alist-get :hour h) 7))
      (should (eq (alist-get :day-ruler h) 'sun)))))

(ert-deftest tod-sky-look-criteria ()
  (let ((m '((:moon-phase . full-moon) (:illumination . 0.98) (:zodiac . libra)
             (:moon-sign . aries) (:element . air) (:planet . venus) (:day-ruler . mercury))))
    (should (tod-look-rule-matches-p '(:moon full-moon :planet (venus mars)) m tod-look-criteria))
    (should (tod-look-rule-matches-p '(:illumination (0.9 nil) :element air) m tod-look-criteria))
    (should-not (tod-look-rule-matches-p '(:zodiac scorpio) m tod-look-criteria))
    (should-not (tod-look-rule-matches-p '(:day-ruler saturn) m tod-look-criteria))
    (should (tod-look-rule-matches-p '(:moon-sign aries) m tod-look-criteria))))

(defun tod-sky-test--sky (altitude &rest more)
  "Return a moment at sun ALTITUDE with the extra alist entries MORE."
  (append (list (cons :altitude altitude) (cons :rising t)) more))

(ert-deftest tod-gradient-interpolates-between-keyframes ()
  (let ((frames '((0.0 "#000000") (10.0 "#ffffff"))))
    (should (equal (tod-gradient-interpolate frames -5.0) "#000000"))
    (should (equal (tod-gradient-interpolate frames 5.0) "#808080"))
    (should (equal (tod-gradient-interpolate frames 20.0) "#ffffff"))))

(ert-deftest tod-gradient-darkness-follows-the-horizon ()
  (should (tod-color-dark-p (tod-gradient-background (tod-sky-test--sky -30.0) 0.06)))
  (should (tod-color-dark-p (tod-gradient-background (tod-sky-test--sky -3.0) 0.06)))
  (should-not (tod-color-dark-p (tod-gradient-background (tod-sky-test--sky 2.0) 0.06)))
  (should-not (tod-color-dark-p (tod-gradient-background (tod-sky-test--sky 60.0) 0.06))))

(ert-deftest tod-gradient-repaints-every-five-minutes ()
  ;; Walk one day in Fortaleza in 300-second steps, the default
  ;; `tod-sky-interval'; nearly every step must give a new palette.
  (tod-sky-test--in-zone "America/Fortaleza"
    (let ((start (encode-time '(0 0 0 21 10 2026 nil -1 "America/Fortaleza")))
          (prev nil)
          (same 0))
      (dotimes (i 288)
        (let* ((time (time-add start (* 300 i)))
               (m (tod-moment-at time -3.73 -38.52 tod-moment-default-ladder nil nil))
               (p (tod-gradient-generate m 0.06 4.5)))
          (when (equal p prev) (setq same (1+ same)))
          (setq prev p)))
      (should (< same 15)))))

(ert-deftest tod-gradient-afternoon-is-warmer-than-morning ()
  (let ((morning (tod-gradient-background '((:altitude . 40.0) (:rising . t) (:azimuth . 95.0)) 0.06))
        (afternoon (tod-gradient-background '((:altitude . 40.0) (:rising) (:azimuth . 265.0)) 0.06)))
    (should (> (nth 0 (tod-color-hex-to-rgb afternoon)) (nth 0 (tod-color-hex-to-rgb morning))))
    (should (< (nth 2 (tod-color-hex-to-rgb afternoon)) (nth 2 (tod-color-hex-to-rgb morning))))))

(ert-deftest tod-gradient-moonlight-and-sunset-tint ()
  (let ((dark (tod-sky-test--sky -40.0)))
    (should-not (equal (tod-gradient-background dark 0.06)
                       (tod-gradient-background
                        (append dark '((:moon-altitude . 40.0) (:illumination . 1.0))) 0.06))))
  (should-not (equal (tod-gradient-background '((:altitude . -3.0) (:rising . t)) 0.06)
                     (tod-gradient-background '((:altitude . -3.0) (:rising)) 0.06))))

(ert-deftest tod-gradient-palette-is-readable-everywhere ()
  (dolist (alt '(-60.0 -15.0 -7.0 -1.0 0.5 4.0 10.0 45.0 85.0))
    (let* ((p (tod-gradient-generate (tod-sky-test--sky alt '(:planet . mars) '(:element . fire))
                                     0.06 4.5))
           (bg (alist-get :bg p)))
      (should (>= (tod-color-contrast (alist-get :fg p) bg) 7.0))
      (dolist (k '(:red :orange :yellow :green :cyan :blue :magenta :comment))
        (should (>= (tod-color-contrast (alist-get k p) bg) 4.5))))))

;;; tod-sky-test.el ends here
