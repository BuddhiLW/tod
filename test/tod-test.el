;;; tod-test.el --- Tests for the tod entry points -*- lexical-binding: t; -*-

;;; Commentary:

;; External commands go through a recording stub of `tod-process-runner'
;; and wallpaper setters are stubs, so nothing outside Emacs changes.

;;; Code:

(require 'ert)
(require 'tod)

(defmacro tod-test--with-clean-state (&rest body)
  "Run BODY with tod's settings and state isolated and restored."
  (declare (indent 0))
  `(let ((tod-latitude -3.73)
         (tod-longitude -38.52)
         (tod-looks '((:theme modus-vivendi)))
         (tod-periods nil)
         (tod-holidays '((holiday-fixed 12 25 "Christmas")))
         (tod--timer nil) (tod--moment nil) (tod--look nil) (tod--wallpaper nil)
         (tod--palette-image nil) (tod--override-until nil) (tod--last-error nil)
         (tod-process-runner (lambda (_slot _commands done) (when done (funcall done t ""))))
         (custom-enabled-themes custom-enabled-themes))
     (unwind-protect
         (progn ,@body)
       (when (timerp tod--timer) (cancel-timer tod--timer))
       (when tod-mode (tod-mode -1))
       (mapc #'disable-theme custom-enabled-themes))))

(ert-deftest tod-location-prefers-tod-settings ()
  (let ((tod-latitude 10) (tod-longitude 20))
    (should (equal (tod-location) '(10.0 20.0))))
  (let ((tod-latitude nil) (tod-longitude nil)
        (calendar-latitude 55.68) (calendar-longitude 12.57))
    (should (equal (tod-location) '(55.68 12.57))))
  (let ((tod-latitude nil) (tod-longitude nil)
        (calendar-latitude nil) (calendar-longitude nil))
    (should-not (tod-location))))

(ert-deftest tod-next-wakeup-is-bounded ()
  (tod-test--with-clean-state
    (let* ((tod-refresh-interval 600)
           (now (current-time))
           (wake (tod-next-wakeup now)))
      (should (time-less-p now wake))
      (should (<= (float-time (time-subtract wake now)) 600.0)))))

(ert-deftest tod-refresh-applies-the-theme-and-records-the-moment ()
  (tod-test--with-clean-state
    (tod-refresh)
    (should (memq 'modus-vivendi custom-enabled-themes))
    (should (eq (alist-get :theme tod--look) 'modus-vivendi))
    (should (memq (alist-get :phase tod--moment)
                  '(night astronomical-twilight nautical-twilight civil-twilight golden-hour day)))
    (should-not tod--last-error)))

(ert-deftest tod-refresh-without-location-reports-instead-of-failing ()
  (tod-test--with-clean-state
    (let ((tod-latitude nil) (tod-longitude nil)
          (calendar-latitude nil) (calendar-longitude nil))
      (tod-refresh)
      (should (string-match-p "tod-latitude" tod--last-error)))))

(ert-deftest tod-mode-arms-a-relative-timer-and-cleans-up ()
  (tod-test--with-clean-state
    (tod-mode 1)
    (should (timerp tod--timer))
    (should (memq #'tod--on-enable-theme enable-theme-functions))
    (let ((due (float-time (time-subtract (timer--time tod--timer) nil))))
      (should (> due 0.0))
      (should (<= due (+ 2.0 tod-refresh-interval))))
    (tod-mode -1)
    (should-not tod--timer)
    (should-not (memq #'tod--on-enable-theme enable-theme-functions))))

(ert-deftest tod-mode-refuses-to-start-without-a-location ()
  (tod-test--with-clean-state
    (let ((tod-latitude nil) (tod-longitude nil)
          (calendar-latitude nil) (calendar-longitude nil))
      (should-error (tod-mode 1) :type 'user-error)
      (should-not tod-mode))))

(ert-deftest tod-a-hand-picked-theme-is-respected-until-the-next-boundary ()
  (tod-test--with-clean-state
    (tod-mode 1)
    (should (memq 'modus-vivendi custom-enabled-themes))
    (should-not tod--override-until)
    (load-theme 'modus-operandi t)
    (should tod--override-until)
    (should (tod--theme-overridden-p))
    (tod-apply-look '((:theme . modus-vivendi)) tod--moment)
    (should (memq 'modus-operandi custom-enabled-themes))
    (setq tod--override-until nil)
    (tod-theme-switch 'modus-vivendi)
    (should-not tod--override-until)))

(ert-deftest tod-wallpaper-changes-go-through-the-process-port ()
  (tod-test--with-clean-state
    (let* ((root (make-temp-file "tod-root" t))
           (seen nil)
           (tod-process-runner (lambda (slot commands done) (push (cons slot commands) seen)
                                 (when done (funcall done t ""))))
           (tod-wallpaper-setters (list (list (cons :id 'stub) (cons :kind 'image) (cons :priority 1)
                                              (cons :commands '(("stub-set" "{path}"))))))
           (tod-wallpaper-directory root)
           (tod-looks '((:theme modus-vivendi :wallpaper t))))
      (unwind-protect
          (progn
            (make-directory (expand-file-name "any/any" root) t)
            (write-region "" nil (expand-file-name "any/any/w.png" root))
            (tod-refresh)
            (should (equal seen `((wallpaper ("stub-set" ,(expand-file-name "any/any/w.png" root))))))
            (tod-refresh)
            (should (= (length seen) 1)))
        (delete-directory root t)))))

(ert-deftest tod-diary-sun-lists-the-day-in-agenda-format ()
  (tod-test--with-clean-state
    (let ((process-environment (cons "TZ=America/Fortaleza" process-environment)))
      (set-time-zone-rule "America/Fortaleza")
      (unwind-protect
          (let ((line (dlet ((date '(9 23 2026))) (tod-diary-sun))))
            (should (string-match-p "\\`04:14 Astronomical twilight begins; " line))
            (should (string-match-p "05:23 Sunrise" line))
            (should (string-match-p "17:29 Sunset" line))
            (should (string-match-p "18:38 Night begins\\'" line))
            (should (= (length (split-string line "; ")) 10)))
        (set-time-zone-rule nil)))
    (should-not (tod-diary-sun))))

(ert-deftest tod-event-labels ()
  (let ((tod-phases tod-moment-default-ladder))
    (should (equal (tod-event-label -0.833 t) "Sunrise"))
    (should (equal (tod-event-label -0.833 nil) "Sunset"))
    (should (equal (tod-event-label 6.0 t) "Day begins"))
    (should (equal (tod-event-label 6.0 nil) "Golden hour begins"))
    (should (equal (tod-event-label -18.0 nil) "Night begins"))
    (should (equal (tod-event-label -18.0 t) "Astronomical twilight begins"))))

(ert-deftest tod-describe-renders ()
  (tod-test--with-clean-state
    (tod-describe)
    (with-current-buffer "*tod*"
      (should (string-match-p "^Phase " (buffer-string)))
      (should (string-match-p "^Today" (buffer-string)))
      (should (string-match-p "Wallpaper setters" (buffer-string))))
    (kill-buffer "*tod*")))

;;; tod-test.el ends here
