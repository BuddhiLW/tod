;;; tod-palette-test.el --- Tests for tod-palette and tod-theme -*- lexical-binding: t; -*-

;;; Commentary:

;; The fixture is the pywal palette that was live on the author's
;; machine: its slot 1 is a blue and its grey fails WCAG, which is what
;; tod-palette exists to repair.

;;; Code:

(require 'ert)
(require 'tod-palette)
(require 'tod-theme)

(defconst tod-palette-test--fixture
  (expand-file-name "fixtures/wal-colors.json"
                    (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest tod-palette-reads-pywal-json ()
  (let ((wal (tod-palette-read-wal tod-palette-test--fixture)))
    (should (equal (alist-get :background wal) "#090404"))
    (should (equal (alist-get :foreground wal) "#c1c0c0"))
    (should (= (length (alist-get :colors wal)) 16))
    (should (equal (nth 1 (alist-get :colors wal)) "#347196"))
    (should-not (tod-palette-read-wal "/no/such/colors.json"))
    (should-not (tod-palette-read-wal nil))))

(ert-deftest tod-palette-semantic-reaches-contrast-everywhere ()
  (let* ((wal (tod-palette-read-wal tod-palette-test--fixture))
         (p (tod-palette-semantic wal 4.5))
         (bg (alist-get :bg p)))
    (should (equal bg "#090404"))
    (should (>= (tod-color-contrast (alist-get :fg p) bg) 7.0))
    (dolist (key '(:comment :red :orange :yellow :green :cyan :blue :magenta))
      (should (>= (tod-color-contrast (alist-get key p) bg) 4.5)))
    (should (>= (tod-color-contrast (alist-get :cursor p) bg) 3.0))))

(ert-deftest tod-palette-maps-by-hue-not-by-slot ()
  (let* ((wal (tod-palette-read-wal tod-palette-test--fixture))
         (p (tod-palette-semantic wal 4.5)))
    (should (< (tod-color-hue-distance (tod-color-hue-degrees (alist-get :red p)) 0.0) 40.0))
    (should (< (tod-color-hue-distance (tod-color-hue-degrees (alist-get :blue p)) 220.0) 40.0))
    (should (< (tod-color-hue-distance (tod-color-hue-degrees (alist-get :green p)) 120.0) 40.0))
    (should (< (tod-color-hue-distance (tod-color-hue-degrees (alist-get :magenta p)) 295.0) 40.0))))

(ert-deftest tod-palette-nearest-accent-respects-the-window ()
  (should (equal (tod-palette-nearest-accent '("#ff0000" "#00ff00") 10.0) "#ff0000"))
  (should-not (tod-palette-nearest-accent '("#00ff00") 0.0)))

(ert-deftest tod-palette-tint-warms-only-low-sun ()
  (let ((wal (list (cons :background "#101010"))))
    (should (equal (tod-palette-tint wal 'night 0.1) wal))
    (should (equal (tod-palette-tint wal 'golden-hour 0.0) wal))
    (let ((warm (alist-get :background (tod-palette-tint wal 'golden-hour 0.1))))
      (should-not (equal warm "#101010"))
      (should (> (nth 0 (tod-color-hex-to-rgb warm)) (nth 2 (tod-color-hex-to-rgb warm)))))))

(ert-deftest tod-palette-wal-commands-isolate-by-default ()
  (let ((iso (car (tod-palette-wal-commands "/w/a.png" "/c" t nil)))
        (sys (car (tod-palette-wal-commands "/w/a.png" "/c" nil t))))
    (should (equal (seq-take iso 4) '("env" "PYWAL_CACHE_DIR=/c/wal" "NO_FUN=1" "wal")))
    (dolist (flag '("-n" "-s" "-t" "-e" "-q" "-l"))
      (should (member flag iso)))
    (should (equal sys '("wal" "-i" "/w/a.png" "-n" "-q")))
    (should (equal (tod-palette-wal-colors-file "/c" nil) "/c/wal/colors.json"))))

(ert-deftest tod-palette-generate-reads-what-pywal-wrote ()
  (let* ((cache (make-temp-file "tod-pal" t))
         (tod-process-runner
          (lambda (_slot _commands done)
            (make-directory (expand-file-name "wal" cache) t)
            (copy-file tod-palette-test--fixture (expand-file-name "wal/colors.json" cache) t)
            (funcall done t "")))
         (got nil))
    (unwind-protect
        (progn
          (tod-palette-generate "/w/a.png" cache nil nil (lambda (wal err) (setq got (list wal err))))
          (should (equal (alist-get :background (car got)) "#090404"))
          (should-not (cadr got)))
      (delete-directory cache t)))
  (let ((tod-process-runner (lambda (_slot _commands done) (funcall done nil "wal exited 1: boom")))
        (got nil))
    (tod-palette-generate "/w/a.png" "/nonexistent" nil nil (lambda (wal err) (setq got (list wal err))))
    (should (equal got '(nil "wal exited 1: boom")))))

(ert-deftest tod-theme-switch-keeps-one-colour-scheme ()
  (let ((custom-enabled-themes custom-enabled-themes))
    (unwind-protect
        (progn
          (tod-theme-switch 'modus-vivendi)
          (should (equal (seq-filter #'tod-theme-color-scheme-p custom-enabled-themes) '(modus-vivendi)))
          (tod-theme-switch 'modus-operandi)
          (should (equal (seq-filter #'tod-theme-color-scheme-p custom-enabled-themes) '(modus-operandi)))
          (should (tod-theme-enabled-alone-p 'modus-operandi))
          (should (eq (tod-theme-switch 'modus-operandi) 'modus-operandi)))
      (mapc #'disable-theme custom-enabled-themes))))

(ert-deftest tod-theme-settings-bundles-are-not-colour-schemes ()
  (custom-declare-theme 'tod-test-bundle 'tod-test-bundle-theme "Bundle."
                        '(:kind user-options))
  (custom-theme-set-variables 'tod-test-bundle '(tod-test-bundle-var 1))
  (unwind-protect
      (progn
        (should-not (tod-theme-color-scheme-p 'tod-test-bundle))
        (should (tod-theme-color-scheme-p 'modus-operandi))
        (enable-theme 'tod-test-bundle)
        (tod-theme-switch 'modus-operandi)
        (should (memq 'tod-test-bundle custom-enabled-themes))
        (should (memq 'modus-operandi custom-enabled-themes)))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest tod-theme-availability ()
  (should (tod-theme-available-p 'modus-operandi))
  (should-not (tod-theme-available-p 'tod-no-such-theme))
  (should-not (tod-theme-available-p "modus-operandi")))

(ert-deftest tod-theme-palette-faces-are-legible ()
  (let* ((p (tod-palette-semantic (tod-palette-read-wal tod-palette-test--fixture) 4.5))
         (faces (tod-theme-palette-faces p))
         (attr (lambda (face key) (plist-get (cdr (car (cadr (assq face faces)))) key))))
    (should (equal (funcall attr 'default :background) "#090404"))
    (dolist (face '(region hl-line show-paren-match isearch))
      (should (>= (tod-color-contrast (alist-get :fg p) (funcall attr face :background)) 4.5)))))

(ert-deftest tod-theme-defines-and-enables-a-palette-theme ()
  (let ((p (tod-palette-semantic (tod-palette-read-wal tod-palette-test--fixture) 4.5)))
    (unwind-protect
        (progn
          (should (eq (tod-theme-define-palette-theme 'tod-test-wal p) 'tod-test-wal))
          (should (tod-theme-loaded-p 'tod-test-wal))
          (should (tod-theme-color-scheme-p 'tod-test-wal))
          (tod-theme-switch 'tod-test-wal)
          (should (memq 'tod-test-wal custom-enabled-themes)))
      (mapc #'disable-theme custom-enabled-themes))))

;;; tod-palette-test.el ends here
