(in-package #:pdpa-sbcl)

;;;; scan.lisp -- batched scanning with live telemetry.

(defun count-findings (findings severity)
  "Count FINDINGS that carry SEVERITY."
  (count severity findings :key (lambda (finding) (getf finding :severity))))

(defun make-scan-result (findings &optional telemetry)
  "Build the result plist from FINDINGS and optional TELEMETRY."
  (let ((critical (count-findings findings :critical))
        (high (count-findings findings :high))
        (medium (count-findings findings :medium))
        (low (count-findings findings :low)))
    (list :findings findings
          :counts (list :critical critical :high high :medium medium :low low)
          :clean? (and (zerop critical) (zerop high))
          :telemetry telemetry)))

(defun %screen-record (strainer path line text excludes findings)
  "Screen one record and push any finding onto FINDINGS."
  (strainer-account strainer)
  (let ((hit (line-to-finding strainer path line text excludes)))
    (when hit
      (push hit findings)))
  findings)

(defun scan-records (records &key excludes (strainer (default-strainer)))
  "Screen a list of records.  Each record is a plist with :path, :line, :text."
  (strainer-begin-pass strainer)
  (let ((findings '()))
    (dolist (record records)
      (setf findings
            (%screen-record strainer
                            (getf record :path)
                            (or (getf record :line) 1)
                            (or (getf record :text) "")
                            (or excludes '())
                            findings)))
    (strainer-end-pass strainer)
    (make-scan-result (nreverse findings) (strainer-telemetry strainer))))

(defun scan-lines (records &key excludes (strainer (default-strainer)))
  "Screen RECORDS, which hold (:path :line :text) plists."
  (scan-records records :excludes excludes :strainer strainer))

(defun %scan-path (strainer path excludes findings)
  "Screen one file and return FINDINGS."
  (call-with-file-lines
   path
   (lambda (number text)
     (setf findings
           (%screen-record strainer path number text excludes findings))))
  findings)

(defun scan-file (file excludes &key (strainer (default-strainer)))
  "Screen one file and return a scan result."
  (let ((path (if (stringp file) file (namestring file))))
    (strainer-begin-pass strainer)
    (let ((findings (%scan-path strainer path (or excludes '()) '())))
      (strainer-end-pass strainer)
      (make-scan-result (nreverse findings) (strainer-telemetry strainer)))))

(defun ensure-target-exists (target)
  "Return the truename of TARGET or signal an error."
  (let ((probe (probe-file target)))
    (unless probe
      (error "target does not exist: ~A" target))
    probe))

(defun scan-target (target &key excludes (strainer (default-strainer)))
  "Scan TARGET and return a scan result with telemetry."
  (let* ((probe (ensure-target-exists target))
         (excludes (or excludes '())))
    (strainer-begin-pass strainer)
    (let ((findings
            (cond
              ((null (pathname-name probe))
               (let ((acc '()))
                 (dolist (file (list-files-recursive probe) acc)
                   (let ((path (namestring file)))
                     (unless (excluded-path-p path excludes)
                       (setf acc (%scan-path strainer path excludes acc)))))))
              (t (%scan-path strainer (namestring probe) excludes '())))))
      (strainer-end-pass strainer)
      (make-scan-result (nreverse findings) (strainer-telemetry strainer)))))
