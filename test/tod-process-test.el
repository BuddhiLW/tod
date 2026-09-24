;;; tod-process-test.el --- Tests for tod-process -*- lexical-binding: t; -*-

;;; Commentary:

;; These start real, harmless processes (`true', `false', `sleep' and a
;; program that does not exist) to prove the sentinel chain.

;;; Code:

(require 'ert)
(require 'tod-process)

(defun tod-process-test--wait (cell)
  "Wait until the car of CELL is no longer `pending'."
  (with-timeout (10 (error "Runner did not finish"))
    (while (eq (car cell) 'pending) (accept-process-output nil 0.05))))

(defun tod-process-test--run (commands)
  "Run COMMANDS in a test slot and return (OK MESSAGE)."
  (let ((cell (list 'pending)))
    (tod-process-run-commands 'test commands (lambda (ok msg) (setcar cell (list ok msg))))
    (tod-process-test--wait cell)
    (car cell)))

(ert-deftest tod-process-chains-commands-and-reports-failures ()
  (should (equal (tod-process-test--run '(("true") ("true"))) '(t "")))
  (let ((r (tod-process-test--run '(("true") ("sh" "-c" "echo boom >&2; exit 3") ("true")))))
    (should-not (car r))
    (should (string-match-p "sh exited 3: boom" (cadr r))))
  (let ((r (tod-process-test--run '(("tod-no-such-program-xyz")))))
    (should-not (car r))
    (should (string-match-p "tod-no-such-program-xyz" (cadr r))))
  (should (equal (tod-process-test--run nil) '(t ""))))

(ert-deftest tod-process-newest-run-in-a-slot-wins ()
  (let ((first (list 'pending))
        (second (list 'pending)))
    (tod-process-run-commands 'race '(("sleep" "5")) (lambda (ok msg) (setcar first (list ok msg))))
    (tod-process-run-commands 'race '(("true")) (lambda (ok msg) (setcar second (list ok msg))))
    (tod-process-test--wait second)
    (should (equal (car second) '(t "")))
    (accept-process-output nil 0.2)
    (should (eq (car first) 'pending))))

(ert-deftest tod-process-run-goes-through-the-port ()
  (let* ((seen nil)
         (tod-process-runner (lambda (slot commands done)
                               (push (list slot commands) seen)
                               (when done (funcall done t "")))))
    (tod-process-run 'palette '(("wal" "-i" "x.png")) nil)
    (should (equal seen '((palette (("wal" "-i" "x.png"))))))))

;;; tod-process-test.el ends here
