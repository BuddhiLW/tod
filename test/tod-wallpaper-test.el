;;; tod-wallpaper-test.el --- Tests for tod-wallpaper -*- lexical-binding: t; -*-

;;; Commentary:

;; Setters here are stubs: data with harmless commands, so no desktop is
;; touched.  The runner tests start real processes (`true', `false' and a
;; missing program) to prove the sentinel chain.

;;; Code:

(require 'ert)
(require 'tod-wallpaper)

(defun tod-wallpaper-test--setter (id kind priority &rest more)
  "Return a stub setter ID of KIND with PRIORITY and MORE alist pairs."
  (append (list (cons :id id) (cons :kind kind) (cons :priority priority)
                (cons :commands (list (list "echo" (symbol-name id) "{path}"))))
          (let (acc) (while more (push (cons (pop more) (pop more)) acc)) (nreverse acc))))

(ert-deftest tod-wallpaper-file-kinds ()
  (should (eq (tod-wallpaper-file-kind "/a/b.PNG") 'image))
  (should (eq (tod-wallpaper-file-kind "x.webp") 'image))
  (should (eq (tod-wallpaper-file-kind "x.mp4") 'video))
  (should (eq (tod-wallpaper-file-kind "x.gif") 'video))
  (should-not (tod-wallpaper-file-kind "notes.txt"))
  (should-not (tod-wallpaper-file-kind "README")))

(ert-deftest tod-wallpaper-uri-escapes-reserved-characters ()
  (should (equal (tod-wallpaper-file-uri "/w/Winter Night/star #1 (ç).jpg")
                 "file:///w/Winter%20Night/star%20%231%20(%C3%A7).jpg")))

(ert-deftest tod-wallpaper-templates-expand-path-and-uri ()
  (should (equal (tod-wallpaper-expand-template '("set" "{path}" "--uri={uri}") "/p q.png")
                 '("set" "/p q.png" "--uri=file:///p%20q.png")))
  (let ((s (tod-wallpaper-test--setter 'fn 'image 1)))
    (setf (alist-get :commands s) (lambda (p) (list (list "f" p))))
    (should (equal (tod-wallpaper-setter-commands s "/x.png") '(("f" "/x.png"))))))

(ert-deftest tod-wallpaper-rules-respect-session-desktop-and-exclusions ()
  (let ((gnome (tod-wallpaper-test--setter 'g 'image 100 :session '(wayland x11) :desktops '("gnome" "ubuntu")))
        (x11 (tod-wallpaper-test--setter 'x 'image 20 :session '(x11)))
        (wl (tod-wallpaper-test--setter 'w 'image 60 :session '(wayland) :exclude '("gnome"))))
    (should (tod-wallpaper-setter-applies-p gnome 'wayland '("ubuntu" "gnome")))
    (should-not (tod-wallpaper-setter-applies-p gnome 'wayland '("kde")))
    (should-not (tod-wallpaper-setter-applies-p x11 'wayland '("gnome")))
    (should-not (tod-wallpaper-setter-applies-p wl 'wayland '("ubuntu" "gnome")))
    (should (tod-wallpaper-setter-applies-p wl 'wayland '("hyprland")))
    (should (equal (mapcar (lambda (s) (alist-get :id s))
                           (tod-wallpaper-candidates (list x11 wl gnome) 'image 'wayland '("hyprland")))
                   '(w)))
    (should (equal (mapcar (lambda (s) (alist-get :id s))
                           (tod-wallpaper-candidates (list x11 gnome) 'image 'x11 '("gnome")))
                   '(g x)))))

(ert-deftest tod-wallpaper-select-skips-setters-that-are-not-ready ()
  (let ((broken (tod-wallpaper-test--setter 'broken 'image 100 :requires '("tod-no-such-program")))
        (probed (tod-wallpaper-test--setter 'probed 'image 90 :probe (lambda () "daemon not running")))
        (fine (tod-wallpaper-test--setter 'fine 'image 10)))
    (should (equal (tod-wallpaper-missing broken) '("program tod-no-such-program")))
    (should (equal (tod-wallpaper-missing probed) '("daemon not running")))
    (should-not (tod-wallpaper-missing fine))
    (should (eq (alist-get :id (tod-wallpaper-select (list broken probed fine) 'image 'x11 '("any")))
                'fine))))

(ert-deftest tod-wallpaper-session-detection-prefers-wayland ()
  (let ((process-environment '("XDG_SESSION_TYPE=wayland" "DISPLAY=:0")))
    (should (eq (tod-wallpaper-session-type) 'wayland)))
  (let ((process-environment '("WAYLAND_DISPLAY=wayland-0" "DISPLAY=:0")))
    (should (eq (tod-wallpaper-session-type) 'wayland)))
  (let ((process-environment '("DISPLAY=:0")))
    (should (eq (tod-wallpaper-session-type) 'x11)))
  (let ((process-environment '("XDG_CURRENT_DESKTOP=ubuntu:GNOME" "SWAYSOCK=/s")))
    (should (equal (tod-wallpaper-desktop-names) '("ubuntu" "gnome" "sway")))))

(ert-deftest tod-wallpaper-register-replaces-by-id ()
  (let ((tod-wallpaper-setters (list (tod-wallpaper-test--setter 'a 'image 1)
                                     (tod-wallpaper-test--setter 'b 'image 1))))
    (tod-wallpaper-register-setter (tod-wallpaper-test--setter 'a 'image 99))
    (should (= (length tod-wallpaper-setters) 2))
    (should (= (alist-get :priority (seq-find (lambda (s) (eq (alist-get :id s) 'a)) tod-wallpaper-setters))
               99))))

(ert-deftest tod-wallpaper-layout-and-stable-picks ()
  (let* ((root (make-temp-file "tod-wp" t))
         (moment (list (cons :phase 'night) (cons :season 'winter) (cons :month 12)
                       (cons :periods '("Christmas")) (cons :date '(12 24 2026)))))
    (unwind-protect
        (progn
          (should (equal (mapcar (lambda (d) (file-relative-name d root))
                                 (tod-wallpaper-layout-directories root moment))
                         '("_period/Christmas/night" "_period/Christmas/any" "_month/12/night"
                           "_month/12/any" "winter/night" "any/night" "winter/any" "any/any")))
          (make-directory (expand-file-name "winter/night" root) t)
          (make-directory (expand-file-name "any/any" root) t)
          (dolist (f '("winter/night/a.jpg" "winter/night/b.png" "winter/night/notes.txt" "any/any/z.png"))
            (write-region "" nil (expand-file-name f root)))
          (let ((pick (tod-wallpaper-choose-file t moment root)))
            (should (member (file-name-nondirectory pick) '("a.jpg" "b.png")))
            (should (equal pick (tod-wallpaper-choose-file t moment root))))
          (let ((day (list (cons :phase 'day) (cons :season 'summer) (cons :month 7)
                           (cons :periods nil) (cons :date '(7 1 2026)))))
            (should (equal (file-name-nondirectory (tod-wallpaper-choose-file t day root)) "z.png")))
          (should (equal (tod-wallpaper-choose-file (expand-file-name "any/any/z.png" root) moment root)
                         (expand-file-name "any/any/z.png" root)))
          (should-not (tod-wallpaper-choose-file "/no/such/file.png" moment root)))
      (delete-directory root t))))

(ert-deftest tod-wallpaper-plans-images-and-videos ()
  (let* ((image (tod-wallpaper-test--setter 'img 'image 10))
         (video (tod-wallpaper-test--setter 'vid 'video 10))
         (cache "/tmp/tod-cache"))
    (let ((p (tod-wallpaper-plan "/w/a.png" (list image) cache)))
      (should (eq (alist-get :setter p) 'img))
      (should (equal (alist-get :commands p) '(("echo" "img" "/w/a.png"))))
      (should (equal (alist-get :image p) "/w/a.png")))
    (should (string-match-p "no ready image" (alist-get :error (tod-wallpaper-plan "/w/a.png" nil cache))))
    (should (string-match-p "not a wallpaper" (alist-get :error (tod-wallpaper-plan "/w/a.txt" (list image) cache))))
    (when (executable-find "ffmpeg")
      (let ((p (tod-wallpaper-plan "/w/clip.mp4" (list image video) cache)))
        (should (eq (alist-get :setter p) 'vid))
        (should (equal (car (alist-get :commands p)) '("echo" "vid" "/w/clip.mp4")))
        (should (string-prefix-p "/tmp/tod-cache/frames/" (alist-get :image p))))
      (let ((p (tod-wallpaper-plan "/w/clip.mp4" (list image) cache)))
        (should (eq (alist-get :setter p) 'img))
        (should (equal (car (last (alist-get :commands p)))
                       (list "echo" "img" (alist-get :image p))))))))

(ert-deftest tod-wallpaper-apply-uses-the-runner-port ()
  (let* ((seen nil)
         (tod-process-runner (lambda (slot commands done)
                               (push (cons slot commands) seen)
                               (funcall done t "")))
         (result nil))
    (tod-wallpaper-apply-file "/w/a.png" (list (tod-wallpaper-test--setter 'img 'image 1)) "/tmp"
                              (lambda (ok msg) (setq result (list ok msg))))
    (should (equal seen '((wallpaper ("echo" "img" "/w/a.png")))))
    (should (equal result '(t "")))))

;;; tod-wallpaper-test.el ends here
