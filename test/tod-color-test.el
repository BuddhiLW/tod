;;; tod-color-test.el --- Tests for tod-color -*- lexical-binding: t; -*-

;;; Commentary:

;; Contrast figures are WCAG 2 values; the pywal colours are the palette
;; that was live on the author's machine when tod was written.

;;; Code:

(require 'ert)
(require 'tod-color)

(defun tod-color-test--near (a b &optional eps)
  "Return non-nil when A and B differ by less than EPS (default 0.01)."
  (< (abs (- a b)) (or eps 0.01)))

(ert-deftest tod-color-parses-long-and-short-hex ()
  (should (equal (tod-color-hex-to-rgb "#ff0000") '(1.0 0.0 0.0)))
  (should (equal (tod-color-hex-to-rgb "#f00") '(1.0 0.0 0.0)))
  (should (equal (tod-color-hex-to-rgb "#FFFFFF") '(1.0 1.0 1.0)))
  (should-not (tod-color-hex-to-rgb "red"))
  (should-not (tod-color-hex-to-rgb "#12345"))
  (should-not (tod-color-hex-to-rgb nil)))

(ert-deftest tod-color-hex-round-trips ()
  (dolist (hex '("#000000" "#ffffff" "#347196" "#08addd" "#090404"))
    (should (equal (apply #'tod-color-rgb-to-hex (tod-color-hex-to-rgb hex)) hex))))

(ert-deftest tod-color-contrast-extremes-and-symmetry ()
  (should (tod-color-test--near (tod-color-contrast "#000000" "#ffffff") 21.0))
  (should (tod-color-test--near (tod-color-contrast "#777777" "#777777") 1.0))
  (should (= (tod-color-contrast "#347196" "#090404")
             (tod-color-contrast "#090404" "#347196"))))

(ert-deftest tod-color-contrast-matches-measured-pywal-figures ()
  (should (tod-color-test--near (tod-color-contrast "#665353" "#090404") 2.84))
  (should (tod-color-test--near (tod-color-contrast "#347196" "#090404") 3.83)))

(ert-deftest tod-color-dark-p-splits-at-equal-contrast ()
  (should (tod-color-dark-p "#090404"))
  (should (tod-color-dark-p "#000000"))
  (should-not (tod-color-dark-p "#f5f4f4"))
  (should-not (tod-color-dark-p "#ffffff")))

(ert-deftest tod-color-ensure-contrast-repairs-without-moving-hue ()
  (dolist (case '(("#665353" "#090404" 4.5)
                  ("#347196" "#090404" 4.5)
                  ("#347196" "#090404" 7.0)
                  ("#F4F887" "#f5f4f4" 4.5)
                  ("#E2897F" "#f5f4f4" 7.0)))
    (let* ((fg (nth 0 case)) (bg (nth 1 case)) (ratio (nth 2 case))
           (fixed (tod-color-ensure-contrast fg bg ratio)))
      (should (>= (tod-color-contrast fixed bg) ratio))
      (should (< (tod-color-hue-distance (tod-color-hue-degrees fg)
                                         (tod-color-hue-degrees fixed))
                 2.0)))))

(ert-deftest tod-color-ensure-contrast-keeps-colours-that-pass ()
  (should (equal (tod-color-ensure-contrast "#08ADDD" "#090404" 4.5) "#08ADDD")))

(ert-deftest tod-color-ensure-contrast-moves-away-from-the-background ()
  (should (> (nth 2 (tod-color-to-hsl (tod-color-ensure-contrast "#665353" "#090404" 4.5)))
             (nth 2 (tod-color-to-hsl "#665353"))))
  (should (< (nth 2 (tod-color-to-hsl (tod-color-ensure-contrast "#F4F887" "#f5f4f4" 4.5)))
             (nth 2 (tod-color-to-hsl "#F4F887")))))

(ert-deftest tod-color-ensure-contrast-saturates-at-the-extremes ()
  (should (equal (tod-color-ensure-contrast "#101010" "#000000" 22.0) "#ffffff"))
  (should (equal (tod-color-ensure-contrast "#eeeeee" "#ffffff" 22.0) "#000000"))
  (should (equal (tod-color-ensure-contrast "#808080" "#7f7f7f" 21.0) "#000000")))

(ert-deftest tod-color-mix-and-hue-distance ()
  (should (equal (tod-color-mix "#000000" "#ffffff" 0.5) "#808080"))
  (should (equal (tod-color-mix "#000000" "#ffffff" 0.0) "#000000"))
  (should (equal (tod-color-mix "#000000" "#ffffff" 2.0) "#ffffff"))
  (should (tod-color-test--near (tod-color-hue-distance 350.0 10.0) 20.0))
  (should (tod-color-test--near (tod-color-hue-distance 10.0 190.0) 180.0)))

;;; tod-color-test.el ends here
