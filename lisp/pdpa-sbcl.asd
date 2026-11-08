(asdf:defsystem "pdpa-sbcl"
  :description "PDPA SBCL standalone engine: scan, detect, SARIF."
  :version "0.3.0"
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

(asdf:defsystem "pdpa-sbcl/tests"
  :description "Self-contained tests for the pdpa-sbcl engine."
  :depends-on ("pdpa-sbcl")
  :components ((:file "test/test")))
