(in-package #:pdpa-sg)

(defparameter *toolkit-version* "0.5.0")
(defparameter *pdpa-rule-stamp* "2026-06-21")
(defparameter *tool-name* "pdpa-sg")
(defparameter *repo-uri* "https://github.com/nurazhardotcom/pdpa-sg")
(defparameter *sarif-schema-uri* "https://json.schemastore.org/sarif-2.1.0.json")
(defparameter *sarif-version* "2.1.0")

(defun toolkit-version () *toolkit-version*)
(defun pdpa-rule-stamp () *pdpa-rule-stamp*)
(defun banner ()
  (format nil "pdpa-sg ~A / Singapore PDPA ~A" *toolkit-version* *pdpa-rule-stamp*))
