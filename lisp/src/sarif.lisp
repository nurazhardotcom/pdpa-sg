(in-package #:pdpa-sbcl)

;;;; sarif.lisp -- SARIF 2.1.0 and JSON report payloads.

(defun severity-to-level (severity)
  "Map a rule severity to a SARIF result level."
  (case severity
    ((:critical :high) "error")
    ((:medium) "warning")
    (otherwise "note")))

(defun rule-id-string (id)
  "Return the SARIF rule identifier for ID."
  (format nil "pdpa/~A" id))

(defun %ht (&rest pairs)
  "Build a hash table from PAIRS of keys and values."
  (let ((table (make-hash-table :test #'equal)))
    (loop for (key value) on pairs by #'cddr
          do (setf (gethash key table) value))
    table))

(defun sorted-unique-rules (findings)
  "Return one SARIF rule object per distinct rule in FINDINGS."
  (let ((seen (make-hash-table :test #'equal))
        (rules '()))
    (dolist (finding findings)
      (let ((id (getf finding :id)))
        (unless (gethash id seen)
          (setf (gethash id seen) t)
          (push (%ht "id" (rule-id-string id)
                     "name" id
                     "shortDescription" (%ht "text" (or (getf finding :label) id))
                     "helpUri" (format nil "~A/blob/main/README.md" *repo-uri*))
                rules))))
    (sort rules #'string< :key (lambda (rule) (gethash "id" rule)))))

(defun finding-path-string (finding)
  "Return the artifact path of FINDING as a string."
  (let ((path (getf finding :path)))
    (cond ((stringp path) path)
          ((null path) "")
          (t (princ-to-string path)))))

(defun finding-line-number (finding)
  "Return the positive line number of FINDING."
  (let ((line (getf finding :line)))
    (if (and (integerp line) (plusp line)) line 1)))

(defun %finding-to-result (finding)
  "Return FINDING as one SARIF result object."
  (let* ((artifact (%ht "uri" (finding-path-string finding)))
         (region (%ht "startLine" (finding-line-number finding)))
         (physical (%ht "artifactLocation" artifact "region" region))
         (location (%ht "physicalLocation" physical)))
    (%ht "ruleId" (rule-id-string (getf finding :id))
         "level" (severity-to-level (getf finding :severity))
         "message" (%ht "text" (or (getf finding :label) (getf finding :id)))
         "locations" (vector location))))

(defun scan-result-to-sarif (scan-result)
  "Return SCAN-RESULT as a SARIF object."
  (let* ((findings (or (getf scan-result :findings) '()))
         (rules (sorted-unique-rules findings))
         (results (mapcar #'%finding-to-result findings))
         (driver (%ht "name" *tool-name*
                      "version" *toolkit-version*
                      "informationUri" *repo-uri*
                      "rules" (coerce rules 'vector)))
         (tool (%ht "driver" driver))
         (run (%ht "tool" tool
                   "results" (coerce results 'vector))))
    (%ht "$schema" *sarif-schema-uri*
         "version" *sarif-version*
         "runs" (vector run))))

(defun write-sarif (scan-result stream)
  "Write SCAN-RESULT to STREAM as SARIF."
  (json-encode (scan-result-to-sarif scan-result) stream))

(defun scan-result-to-sarif-string (scan-result)
  "Return SCAN-RESULT as a SARIF string."
  (json-encode-to-string (scan-result-to-sarif scan-result)))

(defun %counts-to-ht (counts)
  "Return COUNTS as a JSON-ready hash table."
  (%ht "critical" (or (getf counts :critical) 0)
       "high" (or (getf counts :high) 0)
       "medium" (or (getf counts :medium) 0)
       "low" (or (getf counts :low) 0)))

(defun %telemetry-to-ht (telemetry)
  "Return TELEMETRY as a JSON-ready hash table, or NIL."
  (when telemetry
    (%ht "velocity" (or (getf telemetry :velocity) 0.0d0)
         "peakVelocity" (or (getf telemetry :peak-velocity) 0.0d0)
         "meanVelocity" (or (getf telemetry :mean-velocity) 0.0d0)
         "records" (or (getf telemetry :records) 0)
         "batches" (or (getf telemetry :batches) 0)
         "batchSize" (or (getf telemetry :batch-size) 0)
         "inspectionDepth" (or (getf telemetry :inspection-depth) 0)
         "adaptations" (or (getf telemetry :adaptations) 0)
         "meshRebuilds" (or (getf telemetry :mesh-rebuilds) 0)
         "lastSignal" (string-downcase (symbol-name (or (getf telemetry :last-signal) :steady)))
         "degraded" (if (eq (getf telemetry :degraded) :false) :false t))))

(defun scan-result-to-json-object (scan-result)
  "Return SCAN-RESULT as a JSON-ready hash table."
  (let ((findings (or (getf scan-result :findings) '())))
    (%ht "tool" *tool-name*
         "version" *toolkit-version*
         "clean" (if (getf scan-result :clean?) t :false)
         "counts" (%counts-to-ht (getf scan-result :counts))
         "telemetry" (%telemetry-to-ht (getf scan-result :telemetry))
         "findings"
         (coerce
          (mapcar (lambda (finding)
                    (%ht "id" (getf finding :id)
                         "severity" (string-downcase
                                     (symbol-name (getf finding :severity)))
                         "label" (or (getf finding :label) "")
                         "path" (finding-path-string finding)
                         "line" (finding-line-number finding)))
                  findings)
          'vector))))

(defun scan-result-to-json (scan-result)
  "Return SCAN-RESULT as a JSON string."
  (json-encode-to-string (scan-result-to-json-object scan-result)))
