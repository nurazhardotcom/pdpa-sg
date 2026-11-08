(in-package #:pdpa-sbcl)

;;;; strainer.lisp -- mutable, velocity-adaptive screening strainer.
;;;;
;;;; The strainer owns three mutable knobs: the predicate set, the batch
;;;; size and the inspection depth.  A velocity monitor reports records
;;;; per second.  After each batch the strainer classifies the velocity
;;;; and adapts the knobs in memory.  No restart is necessary.
;;;;
;;;; The screening mesh is a generic function with a custom method
;;;; combination.  Each tier is one method.  The combination ranks the
;;;; tiers and skips the deeper tiers when the inspection depth is low.

(defclass strainer ()
  ((predicates
    :accessor strainer-predicates
    :initarg :predicates
    :initform (make-rule-pack)
    :type list
    :documentation "Active rule instances, in screening order.")
   (batch-size
    :accessor strainer-batch-size
    :initarg :batch-size
    :initform 256
    :type integer
    :documentation "Records per telemetry batch.")
   (min-batch-size
    :accessor strainer-min-batch-size
    :initform 32
    :type integer
    :documentation "Lower bound for the adaptive batch size.")
   (max-batch-size
    :accessor strainer-max-batch-size
    :initform 4096
    :type integer
    :documentation "Upper bound for the adaptive batch size.")
   (inspection-depth
    :accessor strainer-inspection-depth
    :initarg :inspection-depth
    :initform 2
    :type integer
    :documentation "Mesh tiers in use: 1 is critical only, 2 is all tiers.")
   (max-inspection-depth
    :accessor strainer-max-inspection-depth
    :initform 2
    :type integer
    :documentation "Highest inspection depth the mesh can reach.")
   (target-velocity
    :accessor strainer-target-velocity
    :initarg :target-velocity
    :initform 20000.0d0
    :type double-float
    :documentation "Expected records per second.")
   (surge-factor
    :accessor strainer-surge-factor
    :initform 1.3d0
    :type double-float
    :documentation "Velocity ratio that counts as a surge.")
   (slow-factor
    :accessor strainer-slow-factor
    :initform 0.7d0
    :type double-float
    :documentation "Velocity ratio that counts as a slowdown.")
   (monitor
    :accessor strainer-monitor
    :initform (make-instance 'velocity-monitor)
    :type velocity-monitor
    :documentation "Throughput monitor for the current pass.")
   (critical-mesh
    :accessor strainer-critical-mesh
    :initform nil
    :documentation "Compiled screening function for the critical tier.")
   (standard-mesh
    :accessor strainer-standard-mesh
    :initform nil
    :documentation "Compiled screening function for the standard tier.")
   (critical-rules
    :accessor strainer-critical-rules
    :initform #()
    :type vector
    :documentation "Critical tier rules, indexed by the compiled mesh.")
   (standard-rules
    :accessor strainer-standard-rules
    :initform #()
    :type vector
    :documentation "Standard tier rules, indexed by the compiled mesh.")
   (mesh-rebuilds
    :accessor strainer-mesh-rebuilds
    :initform 0
    :type integer
    :documentation "Number of in-memory mesh rebuilds.")
   (adaptations
    :accessor strainer-adaptations
    :initform 0
    :type integer
    :documentation "Number of velocity-driven adaptations.")
   (last-signal
    :accessor strainer-last-signal
    :initform :steady
    :type keyword
    :documentation "Last velocity class: :surge, :slow or :steady.")
   (pass-records
    :accessor strainer-pass-records
    :initform 0
    :type integer
    :documentation "Records seen in the current batch.")
   (pass-findings
    :accessor strainer-pass-findings
    :initform 0
    :type integer
    :documentation "Findings produced in the current pass.")
   (batch-started-at
    :accessor strainer-batch-started-at
    :initform (%now)
    :type integer
    :documentation "Internal time at the start of the current batch."))
  (:documentation
   "Mutable screening pipeline with live velocity adaptation."))

(defparameter *mesh-tier-order* '(:critical :standard)
  "Screening tiers, from the shallowest to the deepest.")

(defvar *strainer* nil
  "The strainer that owns the current screening call.")

(defun mesh-depth ()
  "Return the inspection depth of the active strainer."
  (if *strainer*
      (strainer-inspection-depth *strainer*)
      2))

;;; ---------------------------------------------------------------------
;;; Screening mesh

;;; Mesh compilation
(defgeneric screen-line (strainer text)
  (:documentation
   "Screen one lower-case line.  Return the first matching rule or NIL.")
  (:method ((strainer strainer) (text string))
    (flet ((lookup (mesh rules)
             (let ((index (and mesh (funcall mesh text))))
               (when index (aref rules index)))))
      (or (when (>= (mesh-depth) 1)
            (lookup (strainer-critical-mesh strainer)
                    (strainer-critical-rules strainer)))
          (when (>= (mesh-depth) 2)
            (lookup (strainer-standard-mesh strainer)
                    (strainer-standard-rules strainer)))))))

(defun %trigger-form (triggers variable)
  "Return a form that tests whether one of TRIGGERS occurs in VARIABLE."
  (if (null triggers)
      t
      `(or ,@(loop for trigger in triggers
                   collect `(search ,trigger ,variable)))))


(defun %compile-tier-mesh (rules)
  "Compile RULES into a function that returns a matched index or NIL."
  (when rules
    (compile
     nil
     `(lambda (text)
        (declare (type string text)
                 (optimize (speed 2) (safety 1)))
        (or ,@(loop for rule in rules
                    for index from 0
                    collect `(when (and ,(%trigger-form (pdpa-rule-triggers rule) 'text)
                                        (,(pdpa-rule-matcher rule) text))
                               ,index))
            nil)))))
(defun %rules-in-tier (rules tier)
  "Return the rules in RULES that belong to TIER."
  (remove-if-not (lambda (rule) (eq tier (pdpa-rule-tier rule))) rules))


(defun strainer-rebuild-mesh (strainer)
  "Compile both tier meshes of STRAINER from its current predicates."
  (let* ((rules (strainer-predicates strainer))
         (critical (%rules-in-tier rules :critical))
         (standard (%rules-in-tier rules :standard)))
    (setf (strainer-critical-rules strainer) (coerce critical 'vector)
          (strainer-standard-rules strainer) (coerce standard 'vector)
          (strainer-critical-mesh strainer) (%compile-tier-mesh critical)
          (strainer-standard-mesh strainer) (%compile-tier-mesh standard)
          (strainer-inspection-depth strainer)
          (min (strainer-inspection-depth strainer)
               (strainer-max-inspection-depth strainer)))
    (incf (strainer-mesh-rebuilds strainer))
    strainer))
(defmethod initialize-instance :after ((strainer strainer) &key)
  "Compile the initial mesh."
  (strainer-rebuild-mesh strainer))

(defmethod (setf strainer-predicates) :after (rules (strainer strainer))
  "Recompile the mesh when the predicate set changes."
  (declare (ignore rules))
  (strainer-rebuild-mesh strainer))

;;; ---------------------------------------------------------------------
;;; Adaptation

(defgeneric strainer-classify-velocity (strainer velocity)
  (:documentation "Classify VELOCITY against the target of STRAINER.")
  (:method ((strainer strainer) (velocity float))
    (let ((target (strainer-target-velocity strainer)))
      (cond ((>= velocity (* target (strainer-surge-factor strainer))) :surge)
            ((<= velocity (* target (strainer-slow-factor strainer))) :slow)
            (t :steady)))))

(defgeneric strainer-adapt (strainer signal)
  (:documentation "Adapt STRAINER to a velocity class in memory.")
  (:method ((strainer strainer) (signal (eql :surge)))
    (setf (strainer-batch-size strainer)
          (min (strainer-max-batch-size strainer)
               (* 2 (strainer-batch-size strainer)))
          (strainer-inspection-depth strainer)
          (strainer-max-inspection-depth strainer)
          (strainer-last-signal strainer) :surge)
    (incf (strainer-adaptations strainer))
    strainer)
  (:method ((strainer strainer) (signal (eql :slow)))
    (let ((batch (max (strainer-min-batch-size strainer)
                      (floor (strainer-batch-size strainer) 2))))
      (setf (strainer-batch-size strainer) batch)
      (when (= batch (strainer-min-batch-size strainer))
        (setf (strainer-inspection-depth strainer)
              (max 1 (1- (strainer-inspection-depth strainer))))))
    (setf (strainer-last-signal strainer) :slow)
    (incf (strainer-adaptations strainer))
    strainer)
  (:method ((strainer strainer) (signal (eql :steady)))
    (setf (strainer-last-signal strainer) :steady)
    strainer)
  (:method :after ((strainer strainer) signal)
    (declare (ignore signal))
    strainer))

;;; ---------------------------------------------------------------------
;;; Pass control

(defgeneric strainer-begin-pass (strainer)
  (:documentation "Start a new screening pass on STRAINER.")
  (:method ((strainer strainer))
    (setf (strainer-pass-records strainer) 0
          (strainer-pass-findings strainer) 0
          (strainer-batch-started-at strainer) (%now)
          (strainer-last-signal strainer) :steady)
    (monitor-reset (strainer-monitor strainer))
    strainer))

(defgeneric strainer-screen (strainer text)
  (:documentation "Return the first rule that matches TEXT, or NIL.")
  (:method ((strainer strainer) (text string))
    (let* ((lower (ascii-downcase text))
           (*strainer* strainer))
      (screen-line strainer lower))))

(defgeneric strainer-settle-batch (strainer)
  (:documentation
   "Publish the current batch to the monitor and adapt the strainer.")
  (:method ((strainer strainer))
    (let ((records (strainer-pass-records strainer)))
      (when (plusp records)
        (let* ((elapsed (%seconds-since (strainer-batch-started-at strainer)))
               (velocity (monitor-observe (strainer-monitor strainer)
                                          records
                                          elapsed)))
          (strainer-adapt strainer
                          (strainer-classify-velocity strainer velocity)))))
    (setf (strainer-pass-records strainer) 0
          (strainer-batch-started-at strainer) (%now))
    strainer))

(defgeneric strainer-end-pass (strainer)
  (:documentation "Flush the last partial batch of STRAINER.")
  (:method ((strainer strainer))
    (strainer-settle-batch strainer)
    strainer))

(defun strainer-account (strainer)
  "Count one screened record and settle the batch when it is full."
  (incf (strainer-pass-records strainer))
  (when (>= (strainer-pass-records strainer) (strainer-batch-size strainer))
    (strainer-settle-batch strainer))
  strainer)

(defun strainer-note-finding (strainer)
  "Count one finding on STRAINER."
  (incf (strainer-pass-findings strainer))
  strainer)

;;; ---------------------------------------------------------------------
;;; Live reconfiguration

(defgeneric strainer-install-rules (strainer rules)
  (:documentation
   "Replace the predicate set of STRAINER and recompile the mesh in memory.")
  (:method ((strainer strainer) (rules list))
    (setf (strainer-predicates strainer) rules)
    strainer))

(defgeneric strainer-add-rule (strainer rule)
  (:documentation "Append RULE to the predicate set of STRAINER.")
  (:method ((strainer strainer) (rule rule))
    (setf (strainer-predicates strainer)
          (append (strainer-predicates strainer) (list rule)))
    strainer))

(defgeneric strainer-remove-rule (strainer id)
  (:documentation "Remove the rule named ID from STRAINER.")
  (:method ((strainer strainer) (id string))
    (setf (strainer-predicates strainer)
          (remove id (strainer-predicates strainer)
                  :key #'pdpa-rule-id
                  :test #'string=))
    strainer))

;;; ---------------------------------------------------------------------
;;; Telemetry

(defgeneric strainer-telemetry (strainer)
  (:documentation "Return a plist that describes the state of STRAINER.")
  (:method ((strainer strainer))
    (list :velocity (monitor-velocity (strainer-monitor strainer))
          :peak-velocity (monitor-peak-velocity (strainer-monitor strainer))
          :mean-velocity (monitor-overall-velocity (strainer-monitor strainer))
          :records (monitor-records (strainer-monitor strainer))
          :batches (monitor-batches (strainer-monitor strainer))
          :batch-size (strainer-batch-size strainer)
          :inspection-depth (strainer-inspection-depth strainer)
          :max-inspection-depth (strainer-max-inspection-depth strainer)
          :adaptations (strainer-adaptations strainer)
          :mesh-rebuilds (strainer-mesh-rebuilds strainer)
          :last-signal (strainer-last-signal strainer)
          :degraded (if (< (strainer-inspection-depth strainer)
                           (strainer-max-inspection-depth strainer))
                        t
                        :false))))

;;; ---------------------------------------------------------------------
;;; Default instance

(defvar *default-strainer* nil
  "Strainer used by the convenience entry points.")

(defun default-strainer ()
  "Return the process default strainer, creating it on first use."
  (or *default-strainer*
      (setf *default-strainer* (make-instance 'strainer))))
