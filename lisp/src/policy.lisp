(in-package #:pdpa-sg)

(defun get-count (counts key)
  (or (getf counts key) 0))

(defun evaluate-policy (scan-result &key (max-critical 0) (max-high 0) config)
  (let* ((counts (or (getf scan-result :counts) '()))
         (critical (get-count counts :critical))
         (high (get-count counts :high))
         (medium (get-count counts :medium))
         (low (get-count counts :low))
         (limit-critical (if (and config (getf config :max-critical))
                             (getf config :max-critical)
                             max-critical))
         (limit-high (if (and config (getf config :max-high))
                         (getf config :max-high)
                         max-high))
         (compliant (and (<= critical limit-critical)
                         (<= high limit-high))))
    (list :compliant compliant
          :critical critical
          :high high
          :medium medium
          :low low
          :verdict (if compliant "PASS" "FAIL")
          :clean? compliant)))
