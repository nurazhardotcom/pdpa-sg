(in-package #:pdpa-sbcl)

;;;; nric.lisp -- Singapore NRIC / FIN shape check and Mod-11 checksum.
;;;;
;;;; A candidate is nine characters: one series letter, seven digits and
;;;; one check letter.  The checksum tables follow the published Mod-11
;;;; scheme.  No regular expression engine is involved.

(defparameter *citizen-chars* "JZIHGFEDCBA"
  "Check letters for the S and T series.")

(defparameter *foreigner-chars* "XWUTRQPNMLK"
  "Check letters for the F and G series.")

(defparameter *m-series-chars* "XWUTRQPNJLK"
  "Check letters for the M series.")

(defparameter *digit-weights* #(2 7 6 5 4 3 2)
  "Digit weights for the Mod-11 sum.")

(declaim (inline nric-prefix-offset))

(defun nric-prefix-offset (prefix)
  "Return the checksum offset of series letter PREFIX."
  (case prefix
    ((#\T #\G) 4)
    ((#\M) 3)
    (otherwise 0)))

(defun nric-check-digit (string)
  "Return the check letter for the nine-character candidate STRING."
  (when (and (stringp string) (= (length string) 9))
    (let ((up (string-upcase string)))
      (when (and (find (char up 0) "STFGM" :test #'char=)
                 (loop for index from 1 to 7
                       always (digit-char-p (char up index)))
                 (alpha-char-p (char up 8)))
        (let ((sum 0))
          (dotimes (index 7)
            (incf sum (* (digit-char-p (char up (1+ index)))
                         (aref *digit-weights* index))))
          (let* ((prefix (char up 0))
                 (offset (nric-prefix-offset prefix))
                 (position (mod (+ sum offset) 11))
                 (table (cond ((char= prefix #\M) *m-series-chars*)
                              ((find prefix "ST" :test #'char=) *citizen-chars*)
                              (t *foreigner-chars*))))
            (char table position)))))))

(defun valid-nric-p (string)
  "Return true when STRING is a checksum-valid NRIC or FIN."
  (when (and (stringp string) (= (length string) 9))
    (let ((computed (nric-check-digit string)))
      (when computed
        (char= computed (char (string-upcase string) 8))))))

(defun nric-candidates (text)
  "Return the nine-character NRIC-shaped candidates in TEXT."
  (when (stringp text)
    (let ((length (length text))
          (out '()))
      (loop for start from 0 to (- length 9)
            do (when (find (char text start) "stfgm" :test #'char=)
                 (when (and (loop for index from 1 to 7
                                  always (digit-char-p (char text (+ start index))))
                            (alpha-char-p (char text (+ start 8)))
                            (or (= start 0)
                                (not (%word-char-p (char text (1- start)))))
                            (or (= (+ start 9) length)
                                (not (%word-char-p (char text (+ start 9))))))
                   (push (string-upcase (subseq text start (+ start 9))) out))))
      (nreverse out))))

(defun find-valid-nrics (text)
  "Return the distinct checksum-valid NRIC and FIN values in TEXT."
  (when (stringp text)
    (let ((candidates (nric-candidates (ascii-downcase text))))
      (remove-duplicates (remove-if-not #'valid-nric-p candidates)
                         :test #'string=))))
