(in-package #:pdpa-sg)

;;;; detect.lisp -- line screening policy.
;;;;
;;;; This file keeps the marker and path rules.  The pattern work moved to
;;;; the strainer, which screens lower-case lines against a mutable mesh.

(defparameter *ignore-marker* "pdpa:ignore"
  "Marker that suppresses screening on one line.")

(defun ignored-line-p (text)
  "Return true when TEXT carries the ignore marker."
  (when (stringp text)
    (not (null (search *ignore-marker* text)))))

(defun excluded-path-p (path excludes)
  "Return true when PATH matches one entry of EXCLUDES."
  (when path
    (let ((text (if (stringp path) path (princ-to-string path))))
      (some (lambda (entry) (not (null (search entry text)))) excludes))))

(defun classify-line (text &optional path)
  "Return the first rule that matches TEXT, or NIL.  PATH is unused."
  (declare (ignore path))
  (when (and (stringp text) (not (ignored-line-p text)))
    (strainer-screen (default-strainer) text)))

(defun line-to-finding (strainer path line-number text excludes)
  "Return a finding plist for TEXT, or NIL."
  (when (and (stringp text)
             (not (ignored-line-p text))
             (not (excluded-path-p path excludes)))
    (let ((rule (strainer-screen strainer text)))
      (when rule
        (strainer-note-finding strainer)
        (list :severity (pdpa-rule-severity rule)
              :id (pdpa-rule-id rule)
              :label (pdpa-rule-label rule)
              :path path
              :line line-number)))))
