(asdf:defsystem "pdpa-sg"
  :description "PDPA SG Common Lisp scanner: scan, detect, JSON, SARIF."
  :version "0.5.1"
  :author "Nur Azhar <dev@nurazhar.com>"
  :licence "MIT"
  :serial t
  :components ((:file "src/package")
               (:file "src/version")
               (:file "src/text")
               (:file "src/json")
               (:file "src/nric")
               (:file "src/match")
               (:file "src/rules")
               (:file "src/telemetry")
               (:file "src/strainer")
               (:file "src/walk")
               (:file "src/detect")
               (:file "src/scan")
               (:file "src/sarif")
               (:file "src/policy")
               (:file "src/config")
               (:file "src/cli")))

(asdf:defsystem "pdpa-sg/tests"
  :description "Self-contained tests for the pdpa-sg engine."
  :depends-on ("pdpa-sg")
  :components ((:file "test/test")))
