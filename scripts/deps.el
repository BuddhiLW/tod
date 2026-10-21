;;; deps.el --- Activate tod's dependencies from MELPA in batch Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; emacs -Q --batch -l scripts/deps.el ...
;; Installs clel, the ClojureElisp runtime, from MELPA into .cache/elpa
;; on first use and activates it, exactly as `package-install' of tod
;; would for a user.  Load it before tod or its tests.

;;; Code:

(require 'package)

(setq package-user-dir (expand-file-name ".cache/elpa")
      package-archives '(("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless (package-installed-p 'clel)
  (package-refresh-contents)
  (package-install 'clel))

;;; deps.el ends here
