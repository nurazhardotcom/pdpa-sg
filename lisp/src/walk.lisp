(in-package #:pdpa-sg)

;;;; walk.lisp -- directory traversal and line reading.

(defparameter *skip-dir-names*
  '(".git" "node_modules" "target" "out" ".cpcache")
  "Directory names that are never scanned.")

(defun skip-dir-p (pathname)
  "Return true when PATHNAME names a skipped directory."
  (let ((name (car (last (pathname-directory pathname)))))
    (when (stringp name)
      (member name *skip-dir-names* :test #'string=))))

(defun list-files-recursive (root)
  "Return every regular file below ROOT, skipping native output trees."
  (let ((result '()))
    (labels ((walk (dir)
               (dolist (entry (ignore-errors (directory (merge-pathnames (make-pathname :name :wild :type :wild) dir))))
                 (cond
                   ((null entry) nil)
                   ((and (pathname-name entry) (pathname-type entry))
                    (push entry result))
                   ((null (pathname-name entry))
                    (unless (skip-dir-p entry)
                      (when (probe-file entry)
                        (walk entry))))
                   (t (push entry result))))))
      (walk (truename root)))
    (nreverse result)))

(defun call-with-file-lines (path function)
  "Call FUNCTION with each line number and line text of PATH."
  (with-open-file (stream path :direction :input :if-does-not-exist nil
                               :external-format :utf-8)
    (when stream
      (loop for text = (read-line stream nil nil)
            for number from 1
            while text
            do (funcall function number text))))
  path)

(defun read-file-lines (path)
  "Return a list of (LINE-NUMBER TEXT) pairs for PATH."
  (let ((lines '()))
    (call-with-file-lines path
                          (lambda (number text)
                            (push (list number text) lines)))
    (nreverse lines)))
