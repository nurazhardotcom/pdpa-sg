(in-package #:pdpa-sg)

;;;; config.lisp -- JSON configuration loading.

(defun %ht-get-string (table key)
  "Look KEY up in TABLE, trying the usual case variants."
  (cond
    ((hash-table-p table)
     (or (gethash key table)
         (gethash (string-downcase key) table)
         (gethash (string-upcase key) table)))
    ((listp table)
     (or (getf table (intern (string-upcase key) :keyword))
         (cdr (assoc key table :test #'equal))
         (cdr (assoc (string-downcase key) table :test #'equal))))
    (t nil)))

(defun %as-list-of-strings (value)
  "Return VALUE as a list of strings."
  (cond
    ((null value) '())
    ((vectorp value) (map 'list #'princ-to-string value))
    ((listp value) (mapcar #'princ-to-string value))
    ((stringp value) (list value))
    (t (list (princ-to-string value)))))

(defun %as-nonneg-int (value default)
  "Return VALUE as a non-negative integer, or DEFAULT."
  (cond
    ((integerp value) (max 0 value))
    ((stringp value)
     (handler-case (max 0 (parse-integer value))
       (error () default)))
    ((floatp value) (max 0 (truncate value)))
    (t default)))

(defun load-config (path)
  "Load the JSON config at PATH into a plist."
  (when (and path (not (equal path "")))
    (let ((probe (probe-file path)))
      (unless probe
        (error "config file does not exist: ~A" path))
      (let* ((text (read-file-string probe))
             (data (handler-case (json-parse text)
                     (error (condition)
                       (error "malformed config file ~A: ~A" path condition)))))
        (unless (hash-table-p data)
          (error "malformed config file ~A: top level must be a JSON object" path))
        (let ((max-critical (%ht-get-string data "maxCritical"))
              (max-high (%ht-get-string data "maxHigh"))
              (kebab-critical (%ht-get-string data "max-critical"))
              (kebab-high (%ht-get-string data "max-high"))
              (excludes (or (%ht-get-string data "excludes")
                            (%ht-get-string data "exclude"))))
          (list :max-critical (%as-nonneg-int (or max-critical kebab-critical 0) 0)
                :max-high (%as-nonneg-int (or max-high kebab-high 0) 0)
                :excludes (%as-list-of-strings excludes)))))))
