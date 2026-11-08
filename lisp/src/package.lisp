(defpackage #:pdpa-sg
  (:use #:cl)
  (:export
   ;; Entry points
   #:main
   #:scan-target
   #:scan-lines
   #:scan-records
   #:scan-file
   #:classify-line
   #:line-to-finding
   #:make-scan-result
   ;; Reports
   #:scan-result-to-json
   #:scan-result-to-sarif
   #:scan-result-to-sarif-string
   #:evaluate-policy
   #:load-config
   ;; Metadata
   #:toolkit-version
   #:pdpa-rule-stamp
   #:banner
   ;; Rules
   #:rule
   #:make-rule
   #:make-rule-pack
   #:rule-pack
   #:*rule-table*
   #:pdpa-rule-id
   #:pdpa-rule-label
   #:pdpa-rule-severity
   #:pdpa-rule-kind
   #:pdpa-rule-tier
   #:pdpa-rule-matcher
   #:pdpa-rule-triggers
   #:severity-tier
   ;; Strainer
   #:strainer
   #:default-strainer
   #:*default-strainer*
   #:screen-line
   #:strainer-screen
   #:strainer-begin-pass
   #:strainer-end-pass
   #:strainer-settle-batch
   #:strainer-account
   #:strainer-note-finding
   #:strainer-adapt
   #:strainer-classify-velocity
   #:strainer-install-rules
   #:strainer-add-rule
   #:strainer-remove-rule
   #:strainer-telemetry
   #:strainer-predicates
   #:strainer-batch-size
   #:strainer-min-batch-size
   #:strainer-max-batch-size
   #:strainer-inspection-depth
   #:strainer-max-inspection-depth
   #:strainer-target-velocity
   #:strainer-adaptations
   #:strainer-mesh-rebuilds
   #:strainer-last-signal
   #:strainer-monitor
   ;; Telemetry
   #:velocity-monitor
   #:monitor-reset
   #:monitor-observe
   #:monitor-velocity
   #:monitor-peak-velocity
   #:monitor-overall-velocity
   #:monitor-records
   #:monitor-batches
   #:monitor-report
   ;; NRIC
   #:valid-nric-p
   #:nric-check-digit
   #:find-valid-nrics
   #:nric-candidates
   ;; JSON
   #:json-parse
   #:json-encode
   #:json-encode-to-string
   #:read-file-string))
(in-package #:pdpa-sg)
