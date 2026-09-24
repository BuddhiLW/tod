;;; tod-look-test.el --- Tests for tod-look -*- lexical-binding: t; -*-

;;; Commentary:

;; Moments here are hand-built alists: resolution is pure, so no sun is
;; involved.

;;; Code:

(require 'ert)
(require 'tod-look)

(defun tod-look-test--moment (&rest pairs)
  "Build a moment alist from the plist PAIRS."
  (let (m)
    (while pairs
      (push (cons (pop pairs) (pop pairs)) m))
    (nreverse m)))

(defun tod-look-test--all-available (_theme)
  "Accept every theme."
  t)

(defconst tod-look-test--rules
  '((:phase night :season winter :theme (ef-winter modus-vivendi))
    (:phase night :theme (ef-night modus-vivendi) :wallpaper "night.png")
    (:phase golden-hour :rising t :theme modus-operandi-tinted)
    (:period "Christmas" :wallpaper "xmas.png")
    (:month (6 7 8) :palette wal)
    (:theme modus-operandi :wallpaper "default.png")))

(ert-deftest tod-look-criteria-registry ()
  (let ((m (tod-look-test--moment :phase 'night :season 'winter :month 12 :rising nil
                                  :periods '("Christmas Eve") :hour 23 :altitude -40.0)))
    (should (tod-look-match-phase 'night m))
    (should (tod-look-match-phase '(day night) m))
    (should-not (tod-look-match-phase 'day m))
    (should (tod-look-match-month '(11 12) m))
    (should (tod-look-match-rising nil m))
    (should-not (tod-look-match-rising t m))
    (should (tod-look-match-period "Christmas" m))
    (should (tod-look-match-period '("Easter" "Eve$") m))
    (should (tod-look-match-hour '(22 6) m))
    (should-not (tod-look-match-hour '(6 22) m))
    (should (tod-look-match-altitude '(nil -18.0) m))
    (should-not (tod-look-match-altitude '(-18.0 nil) m))
    (should (tod-look-match-predicate (lambda (mo) (eq (alist-get :phase mo) 'night)) m))))

(ert-deftest tod-look-rule-keys-and-matching ()
  (should (equal (tod-look-rule-keys '(:phase night :theme x :wallpaper y)) '(:phase :theme :wallpaper)))
  (let ((m (tod-look-test--moment :phase 'night :season 'autumn)))
    (should (tod-look-rule-matches-p '(:phase night :theme x) m tod-look-criteria))
    (should-not (tod-look-rule-matches-p '(:phase night :season winter) m tod-look-criteria))
    (should (tod-look-rule-matches-p '(:theme x) m tod-look-criteria))))

(ert-deftest tod-look-attributes-resolve-independently ()
  (let* ((m (tod-look-test--moment :phase 'night :season 'winter :month 12
                                   :periods '("Christmas") :rising nil))
         (look (tod-look-resolve tod-look-test--rules m tod-look-criteria
                                 #'tod-look-test--all-available)))
    (should (eq (alist-get :theme look) 'ef-winter))
    (should (equal (alist-get :wallpaper look) "night.png"))
    (should-not (alist-get :palette look))))

(ert-deftest tod-look-theme-alternatives-fall-through-to-available ()
  (let* ((m (tod-look-test--moment :phase 'night :season 'winter :month 12 :periods nil))
         (look (tod-look-resolve tod-look-test--rules m tod-look-criteria
                                 (lambda (th) (memq th '(modus-vivendi modus-operandi))))))
    (should (eq (alist-get :theme look) 'modus-vivendi)))
  (let* ((m (tod-look-test--moment :phase 'night :season 'winter :month 12 :periods nil))
         (look (tod-look-resolve tod-look-test--rules m tod-look-criteria
                                 (lambda (th) (eq th 'modus-operandi)))))
    (should (eq (alist-get :theme look) 'modus-operandi))))

(ert-deftest tod-look-later-rules-fill-missing-attributes ()
  (let* ((m (tod-look-test--moment :phase 'day :season 'summer :month 7 :periods nil))
         (look (tod-look-resolve tod-look-test--rules m tod-look-criteria
                                 #'tod-look-test--all-available)))
    (should (eq (alist-get :theme look) 'modus-operandi))
    (should (eq (alist-get :palette look) 'wal))
    (should (equal (alist-get :wallpaper look) "default.png"))))

(ert-deftest tod-look-unknown-keys-are-attributes-and-new-criteria-plug-in ()
  (let* ((criteria (cons (cons :weekday (lambda (v mo) (eql v (alist-get :weekday mo))))
                         tod-look-criteria))
         (rules '((:weekday 5 :theme friday-theme :mood happy) (:theme other)))
         (m (tod-look-test--moment :weekday 5)))
    (should (equal (tod-look-attribute-keys rules criteria) '(:theme :mood)))
    (let ((look (tod-look-resolve rules m criteria #'tod-look-test--all-available)))
      (should (eq (alist-get :theme look) 'friday-theme))
      (should (eq (alist-get :mood look) 'happy)))))

;;; tod-look-test.el ends here
