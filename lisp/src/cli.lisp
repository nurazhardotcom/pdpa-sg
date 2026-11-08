(in-package #:pdpa-sbcl)

;;;; cli.lisp -- command line interface.

(defun cli-usage ()
  "Return the usage text."
  (format nil "Usage: pdpa-sbcl --target <path> [options]~%~
Options:~%~
  --target <path>          File or directory to scan (required).~%~
  --config <path>          JSON config with maxCritical, maxHigh, excludes.~%~
  --format <json|sarif>    Output format. Default is json.~%~
  --out <path>             Write payload to a file.~%~
  --batch <n>              Initial telemetry batch size. Default is 256.~%~
  --depth <n>              Inspection depth, 1 or 2. Default is 2.~%~
  --velocity <n>           Target records per second. Default is 20000.~%~
  --help, -h               Show this text.~%~
  --version, -V            Show the version banner.~%"))

(defun split-eq (argument)
  "Split ARGUMENT at the first equals sign."
  (let ((position (position #\= argument)))
    (if position
        (values (subseq argument 0 position) (subseq argument (1+ position)))
        (values argument nil))))

(defun take-value (arguments flag)
  "Return a flag value from ARGUMENTS and the remaining arguments."
  (if (null arguments)
      (values nil nil)
      (values (first arguments) (rest arguments))))

(defun parse-nonneg-integer (text)
  "Return TEXT as a non-negative integer, or NIL."
  (when (and (stringp text)
             (plusp (length text))
             (every #'digit-char-p text))
    (parse-integer text)))

(defun parse-positive-float (text)
  "Return TEXT as a positive float, or NIL."
  (when (stringp text)
    (handler-case
        (let ((value (read-from-string text)))
          (when (and (realp value) (plusp value))
            (coerce value 'double-float)))
      (error () nil))))


(defun parse-cli-args (argv)
  "Parse ARGV into a plist of options."
  (let ((target nil)
        (config nil)
        (format nil)
        (out nil)
        (batch nil)
        (depth nil)
        (velocity nil)
        (help nil)
        (version nil)
        (error nil))
    (loop with rest = argv
          while rest
          do (let ((argument (pop rest)))
               (multiple-value-bind (name value) (split-eq argument)
                 (cond
                   ((or (string= name "--help") (string= name "-h"))
                    (setf help t))
                   ((or (string= name "--version") (string= name "-V"))
                    (setf version t))
                   ((or (string= name "--target") (string= name "-t"))
                    (if value
                        (setf target value)
                        (multiple-value-bind (next tail) (take-value rest name)
                          (setf target next rest tail))))
                   ((string= name "--config")
                    (if value
                        (setf config value)
                        (multiple-value-bind (next tail) (take-value rest name)
                          (setf config next rest tail))))
                   ((string= name "--format")
                    (if value
                        (setf format value)
                        (multiple-value-bind (next tail) (take-value rest name)
                          (setf format next rest tail))))
                   ((string= name "--out")
                    (if value
                        (setf out value)
                        (multiple-value-bind (next tail) (take-value rest name)
                          (setf out next rest tail))))
                   ((string= name "--batch")
                    (multiple-value-bind (next tail)
                        (if value (values value rest) (take-value rest name))
                      (setf batch (parse-nonneg-integer next) rest tail)))
                   ((string= name "--depth")
                    (multiple-value-bind (next tail)
                        (if value (values value rest) (take-value rest name))
                      (setf depth (parse-nonneg-integer next) rest tail)))
                   ((string= name "--velocity")
                    (multiple-value-bind (next tail)
                        (if value (values value rest) (take-value rest name))
                      (setf velocity (parse-positive-float next) rest tail)))
                   ((and (plusp (length name)) (char= (char name 0) #\-))
                    (setf error (format nil "unknown flag: ~A" name)))
                   (t
                    (unless target (setf target argument)))))))
    (list :target target :config config :format format :out out
          :batch batch :depth depth :velocity velocity
          :help help :version version :error error)))

(defun valid-format-p (format)
  "Return true when FORMAT is a supported output format."
  (and (stringp format) (or (string= format "json") (string= format "sarif"))))

(defun write-string-to-file (path content)
  "Write CONTENT to PATH as UTF-8."
  (with-open-file (stream path :direction :output :if-exists :supersede
                               :if-does-not-exist :create :external-format :utf-8)
    (write-string content stream)))

(defun cli-diagnostic (target scan-result policy)
  "Return the diagnostic text for one run."
  (let ((counts (or (getf scan-result :counts) '()))
        (telemetry (getf scan-result :telemetry)))
    (format nil "~A~%target: ~A~%counts: critical=~A high=~A medium=~A low=~A~%~
velocity: ~,1F/s peak=~,1F/s batches=~A batch=~A depth=~A adaptations=~A signal=~A~%~
policy: ~A~%"
            (banner)
            target
            (or (getf counts :critical) 0)
            (or (getf counts :high) 0)
            (or (getf counts :medium) 0)
            (or (getf counts :low) 0)
            (or (and telemetry (getf telemetry :velocity)) 0.0d0)
            (or (and telemetry (getf telemetry :peak-velocity)) 0.0d0)
            (or (and telemetry (getf telemetry :batches)) 0)
            (or (and telemetry (getf telemetry :batch-size)) 0)
            (or (and telemetry (getf telemetry :inspection-depth)) 0)
            (or (and telemetry (getf telemetry :adaptations)) 0)
            (or (and telemetry (getf telemetry :last-signal)) :steady)
            (or (getf policy :verdict) "UNKNOWN"))))

(defun %apply-tuning (strainer options)
  "Apply the command line tuning options to STRAINER."
  (let ((batch (getf options :batch))
        (depth (getf options :depth))
        (velocity (getf options :velocity)))
    (when batch
      (setf (strainer-batch-size strainer) (max 1 batch)))
    (when (and depth (<= 1 depth 2))
      (setf (strainer-inspection-depth strainer) depth))
    (when velocity
      (setf (strainer-target-velocity strainer) velocity))
    strainer))

(defun run-cli (argv)
  "Run the command line and return an exit code."
  (let* ((options (parse-cli-args argv))
         (reported-error (getf options :error)))
    (when reported-error
      (format *error-output* "error: ~A~%~A" reported-error (cli-usage))
      (return-from run-cli 2))
    (when (getf options :help)
      (format *standard-output* "~A" (cli-usage))
      (return-from run-cli 0))
    (when (getf options :version)
      (format *standard-output* "~A~%" (banner))
      (return-from run-cli 0))
    (let ((target (getf options :target))
          (config-path (getf options :config))
          (format (or (getf options :format) "json"))
          (out (getf options :out)))
      (unless (and (stringp target) (plusp (length target)))
        (format *error-output* "error: missing --target <path>~%~A" (cli-usage))
        (return-from run-cli 2))
      (unless (valid-format-p format)
        (format *error-output* "error: bad --format ~A, use json or sarif~%" format)
        (return-from run-cli 2))
      (let ((config nil))
        (when (and config-path (plusp (length config-path)))
          (handler-case (setf config (load-config config-path))
            (error (condition)
              (format *error-output* "error: bad config ~A: ~A~%" config-path condition)
              (return-from run-cli 1))))
        (let ((scan-result nil))
          (handler-case
              (let ((strainer (default-strainer)))
                (%apply-tuning strainer options)
                (setf scan-result
                      (scan-target target
                                   :excludes (and config (getf config :excludes))
                                   :strainer strainer)))
            (error (condition)
              (format *error-output* "error: cannot scan ~A: ~A~%" target condition)
              (return-from run-cli 1)))
          (let* ((policy (evaluate-policy scan-result :config config))
                 (payload (if (string= format "sarif")
                              (scan-result-to-sarif-string scan-result)
                              (scan-result-to-json scan-result))))
            (format *error-output* "~A" (cli-diagnostic target scan-result policy))
            (if (and out (plusp (length out)))
                (handler-case
                    (progn
                      (write-string-to-file out payload)
                      (format *error-output* "wrote ~A (~A)~%" out format)
                      0)
                  (error (condition)
                    (format *error-output* "error: cannot write ~A: ~A~%" out condition)
                    1))
                (progn
                  (write-string payload *standard-output*)
                  (terpri *standard-output*)
                  0))))))))

(defun main ()
  "Process entry point."
  (with-simple-restart (abort "Abort pdpa-sbcl.")
    (let* ((argv (rest sb-ext:*posix-argv*))
           (code (handler-case (run-cli argv)
                   (error (condition)
                     (format *error-output* "error: ~A~%" condition)
                     1))))
      (sb-ext:exit :code code))))
