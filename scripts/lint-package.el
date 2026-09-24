;;; lint-package.el --- Run package-lint over files named on the command line -*- lexical-binding: t; -*-

;;; Commentary:

;; emacs -Q --batch -l scripts/lint-package.el tod*.el
;; Installs package-lint from MELPA into .cache/elpa on first use.  The
;; ClojureElisp runtime is not on a package archive yet, so the copy
;; that `bb runtime' bundles is installed locally for the dependency
;; check to resolve.  Warnings fail the run, as in MELPA review.

;;; Code:

(require 'package)

(setq package-user-dir (expand-file-name ".cache/elpa"))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'package-lint)
  (package-refresh-contents)
  (package-install 'package-lint))

(let ((runtime (car (file-expand-wildcards (expand-file-name ".cache/*.el")))))
  (when (and runtime
             (not (package-installed-p (intern (file-name-base runtime)))))
    (package-install-file runtime)))

(require 'package-lint)
(setq package-lint-main-file (expand-file-name "tod.el"))
(package-lint-batch-and-exit)

;;; lint-package.el ends here
