;;; lint-package.el --- Run package-lint over files named on the command line -*- lexical-binding: t; -*-

;;; Commentary:

;; emacs -Q --batch -l scripts/lint-package.el tod*.el
;; Installs package-lint, and through scripts/deps.el the ClojureElisp
;; runtime clel, from MELPA into .cache/elpa on first use.  Warnings
;; fail the run, as in MELPA review.

;;; Code:

(load (expand-file-name "deps.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(unless (package-installed-p 'package-lint)
  (package-refresh-contents)
  (package-install 'package-lint))

(require 'package-lint)
(setq package-lint-main-file (expand-file-name "tod.el"))
(package-lint-batch-and-exit)

;;; lint-package.el ends here
