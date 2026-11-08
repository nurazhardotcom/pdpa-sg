(in-package #:pdpa-sbcl)

;;;; telemetry.lisp -- throughput and velocity measurement.
;;;;
;;;; The monitor records one velocity sample per batch and keeps a
;;;; short exponential moving average.  The strainer reads the average
;;;; to decide how to adapt.

(defparameter *velocity-smoothing* 0.4d0
  "Weight of the newest sample in the velocity moving average.")

(defun %now ()
  "Return the internal real time counter."
  (get-internal-real-time))

(defun %seconds-since (timestamp)
  "Return the seconds elapsed since TIMESTAMP."
  (/ (float (- (%now) timestamp) 1d0)
     internal-time-units-per-second))

(defclass velocity-monitor ()
  ((records
    :accessor monitor-records
    :initform 0
    :type integer
    :documentation "Total records observed since the last reset.")
   (batches
    :accessor monitor-batches
    :initform 0
    :type integer
    :documentation "Total batches observed since the last reset.")
   (velocity
    :accessor monitor-velocity
    :initform 0.0d0
    :type double-float
    :documentation "Smoothed records per second.")
   (peak-velocity
    :accessor monitor-peak-velocity
    :initform 0.0d0
    :type double-float
    :documentation "Highest smoothed velocity seen since the last reset.")
   (started-at
    :accessor monitor-started-at
    :initform (%now)
    :type integer
    :documentation "Internal time at which the current pass started."))
  (:documentation "Throughput monitor for one strainer pass."))

(defgeneric monitor-reset (monitor)
  (:documentation "Clear MONITOR and start a new measurement pass.")
  (:method ((monitor velocity-monitor))
    (setf (monitor-records monitor) 0
          (monitor-batches monitor) 0
          (monitor-velocity monitor) 0.0d0
          (monitor-peak-velocity monitor) 0.0d0
          (monitor-started-at monitor) (%now))
    monitor))

(defgeneric monitor-observe (monitor records elapsed-seconds)
  (:documentation "Record RECORDS processed in ELAPSED-SECONDS.
Return the instantaneous velocity in records per second.")
  (:method ((monitor velocity-monitor) (records integer) (elapsed-seconds float))
    (let* ((elapsed (max elapsed-seconds 1d-6))
           (instant (/ (float records 1d0) elapsed))
           (previous (monitor-velocity monitor))
           (smoothed (if (zerop previous)
                         instant
                         (+ (* *velocity-smoothing* instant)
                            (* (- 1d0 *velocity-smoothing*) previous)))))
      (incf (monitor-records monitor) records)
      (incf (monitor-batches monitor))
      (setf (monitor-velocity monitor) smoothed)
      (when (> smoothed (monitor-peak-velocity monitor))
        (setf (monitor-peak-velocity monitor) smoothed))
      smoothed)))

(defgeneric monitor-elapsed-seconds (monitor)
  (:documentation "Return the seconds since MONITOR started.")
  (:method ((monitor velocity-monitor))
    (%seconds-since (monitor-started-at monitor))))

(defgeneric monitor-overall-velocity (monitor)
  (:documentation "Return the mean velocity of the whole pass.")
  (:method ((monitor velocity-monitor))
    (let ((elapsed (monitor-elapsed-seconds monitor)))
      (if (zerop elapsed)
          0.0d0
          (/ (float (monitor-records monitor) 1d0) (max elapsed 1d-6))))))

(defgeneric monitor-report (monitor)
  (:documentation "Return a plist that describes MONITOR.")
  (:method ((monitor velocity-monitor))
    (list :records (monitor-records monitor)
          :batches (monitor-batches monitor)
          :velocity (monitor-velocity monitor)
          :peak-velocity (monitor-peak-velocity monitor)
          :mean-velocity (monitor-overall-velocity monitor)
          :elapsed-seconds (monitor-elapsed-seconds monitor))))
