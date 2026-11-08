;;; Tests for the pdpa-sg standalone engine.
;;; Run from the workspace root:
;;;   sbcl --non-interactive --load lisp/test/test.lisp
(in-package #:cl-user)

(require "asdf")

(let* ((this-file (or *load-truename* (truename "lisp/test/test.lisp")))
       (lisp-dir (merge-pathnames "../"
                                  (make-pathname :directory (pathname-directory this-file)
                                                 :name nil :type nil))))
  (pushnew (truename lisp-dir) asdf:*central-registry* :test #'equal)
  (asdf:load-asd (merge-pathnames "pdpa-sg.asd" (truename lisp-dir)))
  (asdf:load-system :pdpa-sg))

(defpackage #:pdpa-sg-tests
  (:use #:cl)
  (:import-from #:pdpa-sg
                #:valid-nric-p
                #:find-valid-nrics
                #:classify-line
                #:scan-lines
                #:scan-target
                #:scan-result-to-json
                #:scan-result-to-sarif-string
                #:evaluate-policy
                #:load-config
                #:json-parse
                #:strainer
                #:strainer-screen
                #:strainer-begin-pass
                #:strainer-end-pass
                #:strainer-telemetry
                #:strainer-install-rules
                #:strainer-adapt
                #:strainer-classify-velocity
                #:strainer-batch-size
                #:strainer-inspection-depth
                #:strainer-adaptations
                #:strainer-mesh-rebuilds
                #:strainer-target-velocity
                #:strainer-last-signal
                #:make-rule
                #:pdpa-rule-id
                #:pdpa-rule-tier))
(in-package #:pdpa-sg-tests)

;;; ---------------------------------------------------------------------
;;; Harness

(defvar *checks* 0)
(defvar *failures* '())
(defvar *tests* '())
(defvar *test-failures* 0)

(defmacro check (form &optional label)
  "Record one assertion."
  `(progn
     (incf *checks*)
     (unless ,form
       (push (or ,label ',form) *failures*))))

(defmacro check-equal (expected form &optional label)
  "Record one equality assertion."
  `(check (equal ,expected ,form) ,(or label (list 'quote form))))

(defmacro check-signals (form)
  "Record that FORM signals an error."
  `(check (handler-case (progn ,form nil)
            (error () t))
          ',form))

(defmacro deftest (name &body body)
  "Register one test."
  `(push (cons ',name (lambda () ,@body)) *tests*))

(defun run-tests ()
  "Run every registered test and return the failure count."
  (dolist (test (reverse *tests*))
    (let ((*failures* '())
          (started (get-internal-real-time)))
      (handler-case (funcall (cdr test))
        (error (condition)
          (push (format nil "error: ~A" condition) *failures*)))
      (let ((elapsed (/ (float (- (get-internal-real-time) started) 1d0)
                        internal-time-units-per-second)))
        (cond
          (*failures*
           (incf *test-failures*)
           (format t "FAIL ~A (~,3Fs)~%" (car test) elapsed)
           (dolist (failure (reverse *failures*))
             (format t "  - ~A~%" failure)))
          (t
           (format t "ok   ~A (~,3Fs)~%" (car test) elapsed))))))
  *test-failures*)

;;; ---------------------------------------------------------------------
;;; NRIC

(deftest nric-valid-vectors
  (check (valid-nric-p "S0100000D"))
  (check (valid-nric-p "F0000002R"))
  (check (valid-nric-p "M5012345J"))
  (check (valid-nric-p "S1234567D"))
  (check-equal '("S0100000D") (find-valid-nrics "identity S0100000D here")))

(deftest nric-invalid-guards
  (check (not (valid-nric-p "S0100000A")))
  (check (not (valid-nric-p "X0100000D")))
  (check (not (valid-nric-p "S010000")))
  (check (valid-nric-p "s0100000d"))
  (check-equal nil (find-valid-nrics "S0100000A")))

;;; ---------------------------------------------------------------------
;;; Detection

(deftest classify-line-rules
  (check-equal "nric-live" (pdpa-rule-id (classify-line "identity S0100000D")))
  (check-equal "aws-key" (pdpa-rule-id (classify-line "key AKIAIOSFODNN7EXAMPLE")))
  (check-equal nil (classify-line "identity S0100000D # pdpa:ignore"))
  (check-equal nil (classify-line "hello world"))
  (check-equal nil (classify-line nil)))

(deftest scan-lines-aggregation
  (let* ((records (list (list :path "a.txt" :line 1 :text "identity S0100000D")
                        (list :path "b.txt" :line 2 :text "key AKIAIOSFODNN7EXAMPLE")
                        (list :path "ignored.txt" :line 2 :text "identity S0100000D # pdpa:ignore")
                        (list :path "clean.txt" :line 1 :text "hello world")))
         (result (scan-lines records)))
    (check (= 1 (getf (getf result :counts) :critical)))
    (check (= 1 (getf (getf result :counts) :high)))
    (check (not (getf result :clean?)))
    (check (= 2 (length (getf result :findings))))))

;;; ---------------------------------------------------------------------
;;; Policy and reports

(deftest policy-evaluation
  (let ((clean (list :findings nil :counts (list :critical 0 :high 0 :medium 1 :low 0) :clean? t))
        (dirty (list :findings nil :counts (list :critical 1 :high 0 :medium 0 :low 0) :clean? nil)))
    (check (getf (evaluate-policy clean) :compliant))
    (check (string= (getf (evaluate-policy clean) :verdict) "PASS"))
    (check (not (getf (evaluate-policy dirty) :compliant)))
    (check (string= (getf (evaluate-policy dirty) :verdict) "FAIL"))))

(deftest json-output-shape
  (let* ((records (list (list :path "nric.txt" :line 4 :text "identity S0100000D")))
         (result (scan-lines records))
         (text (scan-result-to-json result))
         (object (json-parse text)))
    (check (hash-table-p object))
    (check (string= (gethash "tool" object) "pdpa-sg"))
    (check (hash-table-p (gethash "counts" object)))
    (check (= 1 (gethash "critical" (gethash "counts" object))))
    (check (eq :false (gethash "clean" object)))
    (check (vectorp (gethash "findings" object)))
    (check (= 1 (length (gethash "findings" object))))
    (check (hash-table-p (gethash "telemetry" object)))
    (check (integerp (gethash "records" (gethash "telemetry" object))))))

(deftest sarif-schema-2-1-0
  (let* ((records (list (list :path "nric.txt" :line 4 :text "identity S0100000D")
                        (list :path "secret.txt" :line 9 :text "key AKIAIOSFODNN7EXAMPLE here")))
         (result (scan-lines records))
         (text (scan-result-to-sarif-string result))
         (log (json-parse text)))
    (check (string= (gethash "version" log) "2.1.0"))
    (check (string= (gethash "$schema" log) "https://json.schemastore.org/sarif-2.1.0.json"))
    (let* ((runs (gethash "runs" log))
           (run (aref runs 0))
           (driver (gethash "driver" (gethash "tool" run)))
           (rules (gethash "rules" driver))
           (results (gethash "results" run)))
      (check (= 1 (length runs)))
      (check (string= (gethash "name" driver) "pdpa-sg"))
      (check (>= (length rules) 2))
      (check (= 2 (length results)))
      (dotimes (index (length results))
        (let* ((entry (aref results index))
               (locations (gethash "locations" entry))
               (physical (gethash "physicalLocation" (aref locations 0)))
               (artifact (gethash "artifactLocation" physical))
               (region (gethash "region" physical)))
          (check (stringp (gethash "uri" artifact)))
          (check (integerp (gethash "startLine" region))))))))

(deftest config-load-and-missing
  (let ((path "/tmp/pdpa-sg-test-config.json"))
    (with-open-file (stream path :direction :output :if-exists :supersede
                                 :if-does-not-exist :create)
      (write-string "{\"maxCritical\": 1, \"maxHigh\": 2, \"excludes\": [\"fixtures\"]}" stream))
    (let ((config (load-config path)))
      (check (= 1 (getf config :max-critical)))
      (check (= 2 (getf config :max-high)))
      (check-equal '("fixtures") (getf config :excludes)))
    (ignore-errors (delete-file path))
    (check-equal nil (load-config nil))
    (check-signals (load-config "/tmp/pdpa-sg-no-such-config.json"))))

(deftest cli-flags-contract
  (let ((options (pdpa-sg::parse-cli-args
                  '("--target" "src" "--config" "c.json" "--format" "sarif"
                    "--out" "o.sarif" "--batch" "64" "--depth" "1" "--velocity" "5000"))))
    (check (string= (getf options :target) "src"))
    (check (string= (getf options :config) "c.json"))
    (check (string= (getf options :format) "sarif"))
    (check (string= (getf options :out) "o.sarif"))
    (check (= 64 (getf options :batch)))
    (check (= 1 (getf options :depth)))
    (check (= 5000.0d0 (getf options :velocity))))
  (let ((options (pdpa-sg::parse-cli-args '("--target=src" "--format=json"))))
    (check (string= (getf options :target) "src"))
    (check (string= (getf options :format) "json")))
  (let ((options (pdpa-sg::parse-cli-args '("--nope"))))
    (check (stringp (getf options :error)))))

;;; ---------------------------------------------------------------------
;;; Strainer

(deftest strainer-tier-depth
  (let ((strainer (make-instance 'strainer)))
    (check-equal "email-live"
                 (pdpa-rule-id (strainer-screen strainer "contact dev@realcorp.sg")))
    (setf (strainer-inspection-depth strainer) 1)
    (check-equal nil (strainer-screen strainer "contact dev@realcorp.sg"))
    (check-equal "aws-key"
                 (pdpa-rule-id (strainer-screen strainer "key AKIAIOSFODNN7EXAMPLE")))
    (setf (strainer-inspection-depth strainer) 2)
    (check-equal "email-live"
                 (pdpa-rule-id (strainer-screen strainer "contact dev@realcorp.sg")))
    (check (string= "email-live"
                    (pdpa-rule-id (strainer-screen (make-instance 'strainer)
                                                  "contact dev@realcorp.sg"))))))

(deftest strainer-velocity-adaptation
  (let ((strainer (make-instance 'strainer)))
    (check-equal :surge (strainer-classify-velocity strainer 100000.0d0))
    (check-equal :slow (strainer-classify-velocity strainer 100.0d0))
    (check-equal :steady (strainer-classify-velocity strainer 20000.0d0))
    (let ((before (strainer-batch-size strainer)))
      (strainer-adapt strainer :surge)
      (check (= (* 2 before) (strainer-batch-size strainer)))
      (check (= 2 (strainer-inspection-depth strainer)))
      (check-equal :surge (strainer-last-signal strainer))
      (check (= 1 (strainer-adaptations strainer))))
    (setf (strainer-batch-size strainer) 400)
    (strainer-adapt strainer :slow)
    (check (= 200 (strainer-batch-size strainer)))
    (check (= 2 (strainer-inspection-depth strainer)))
    (setf (strainer-batch-size strainer) 64)
    (strainer-adapt strainer :slow)
    (check (= 32 (strainer-batch-size strainer)))
    (check (= 1 (strainer-inspection-depth strainer)))
    (check-equal :slow (strainer-last-signal strainer))
    (strainer-adapt strainer :slow)
    (check (= 32 (strainer-batch-size strainer)))
    (check (= 1 (strainer-inspection-depth strainer)))
    (let ((batch (strainer-batch-size strainer)))
      (strainer-adapt strainer :surge)
      (check (= (* 2 batch) (strainer-batch-size strainer)))
      (check (= 2 (strainer-inspection-depth strainer))))))

(deftest strainer-live-recompile
  (let* ((strainer (make-instance 'strainer))
         (rebuilds (strainer-mesh-rebuilds strainer))
         (rules (list (make-rule :id "only-aws"
                                 :label "Only AWS"
                                 :severity :critical
                                 :kind :secret
                                 :matcher 'pdpa-sg::match-aws-key-p
                                 :triggers '("akia")))))
    (check (= 1 rebuilds))
    (strainer-install-rules strainer rules)
    (check (= (1+ rebuilds) (strainer-mesh-rebuilds strainer)))
    (check-equal "only-aws"
                 (pdpa-rule-id (strainer-screen strainer "key AKIAIOSFODNN7EXAMPLE")))
    (check-equal nil (strainer-screen strainer "contact dev@realcorp.sg"))
    (check-equal :critical (pdpa-rule-tier (first rules)))))

(deftest strainer-batch-telemetry
  (let* ((strainer (make-instance 'strainer))
         (records (loop for index below 10
                        collect (list :path "t.txt" :line (1+ index)
                                      :text (if (evenp index)
                                                "identity S0100000D"
                                                "hello world"))))
         (result (scan-lines records :strainer strainer))
         (telemetry (getf result :telemetry)))
    (check (= 5 (length (getf result :findings))))
    (check (= 10 (getf telemetry :records)))
    (check (= 1 (getf telemetry :batches)))
    (check (plusp (getf telemetry :velocity)))
    (check (member (getf telemetry :last-signal) (list :surge :slow :steady)))
    (check (member (getf telemetry :inspection-depth) '(1 2)))
    (let ((report (pdpa-sg::monitor-report (pdpa-sg::strainer-monitor strainer))))
      (check (= 10 (getf report :records)))
      (check (= 1 (getf report :batches))))))

;;; ---------------------------------------------------------------------
;;; Filesystem

(deftest scan-target-skips-output-trees
  (let ((root "/tmp/pdpa-sg-scan-test/"))
    (ensure-directories-exist (merge-pathnames "src/" root))
    (ensure-directories-exist (merge-pathnames "node_modules/pkg/" root))
    (with-open-file (stream (merge-pathnames "src/app.txt" root)
                            :direction :output :if-exists :supersede
                            :if-does-not-exist :create)
      (write-string "identity S0100000D" stream)
      (terpri stream)
      (write-string "hello world" stream))
    (with-open-file (stream (merge-pathnames "node_modules/pkg/vendor.txt" root)
                            :direction :output :if-exists :supersede
                            :if-does-not-exist :create)
      (write-string "key AKIAIOSFODNN7EXAMPLE" stream)
      (terpri stream))
    (let ((result (scan-target root)))
      (check (= 1 (length (getf result :findings))))
      (check (= 1 (getf (getf result :counts) :critical)))
      (check (= 0 (getf (getf result :counts) :high))))
    (ignore-errors (delete-directory-tree #P"/tmp/pdpa-sg-scan-test/" :validate t))))

;;; ---------------------------------------------------------------------
;;; Dependency surface

(deftest no-external-libraries
  (check (null (find-package "CL-PPCRE")))
  (check (null (find-package "YASON")))
  (check (null (find-package "ALEXANDRIA")))
  (check (null (find-package "FIVEAM"))))

;;; ---------------------------------------------------------------------
;;; Entry point

(let* ((failures (run-tests))
       (total (length *tests*)))
  (format t "~%TESTS DONE checks=~A tests=~A failures=~A~%"
          *checks* total failures)
  (sb-ext:exit :code (if (zerop failures) 0 1)))
