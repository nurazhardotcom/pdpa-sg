;;; Build script for the pdpa-sbcl standalone engine.
;;; Run from the workspace root:
;;;   sbcl --non-interactive --load lisp/build.lisp
(in-package #:cl-user)

(setf sb-ext:*evaluator-mode* :compile)
(declaim (optimize (speed 3) (safety 1) (debug 0) (space 0)))

(require "asdf")

(let* ((this-file (or *load-truename* (truename "lisp/build.lisp")))
       (lisp-dir (make-pathname :directory (pathname-directory this-file)
                                :name nil :type nil))
       (root-dir (merge-pathnames "../" lisp-dir))
       (out-path (merge-pathnames "bin/pdpa-sbcl" root-dir)))
  (pushnew lisp-dir asdf:*central-registry* :test #'equal)
  (asdf:load-asd (merge-pathnames "pdpa-sbcl.asd" lisp-dir))
  (asdf:load-system :pdpa-sbcl)
  (ensure-directories-exist out-path)
  (format t "BUILD: loaded pdpa-sbcl ~A~%"
          (symbol-value (find-symbol "*TOOLKIT-VERSION*" "PDPA-SBCL")))
  (format t "BUILD: writing ~A~%" (namestring out-path))
  (sb-ext:save-lisp-and-die (namestring out-path)
                             :toplevel (find-symbol "MAIN" "PDPA-SBCL")
                             :executable t
                             :purify t
                             :compression t))
