(in-package #:pdpa-sg)

;;;; json.lisp -- minimal JSON encoder and parser.
;;;;
;;;; The engine needs JSON only for the config file and for the report
;;;; payloads.  This file keeps that surface inside the standard.

;;; ---------------------------------------------------------------------
;;; Encoding

(defun %json-escape (string stream)
  "Write STRING to STREAM as a quoted JSON string."
  (write-char #\" stream)
  (loop for character across string
        do (case character
             (#\" (write-string "\\\"" stream))
             (#\\ (write-string "\\\\" stream))
             (#\Newline (write-string "\\n" stream))
             (#\Return (write-string "\\r" stream))
             (#\Tab (write-string "\\t" stream))
             (t (if (< (char-code character) 32)
                    (format stream "\\u~4,'0X" (char-code character))
                    (write-char character stream)))))
  (write-char #\" stream))

(defun %json-key-string (key)
  "Return KEY as the string used for a JSON object member name."
  (etypecase key
    (string key)
    (symbol (string-downcase (symbol-name key)))))

(defun %json-object-keys (table)
  "Return the member names of TABLE in sorted order."
  (sort (loop for key being the hash-keys of table collect key)
        #'string<
        :key #'%json-key-string))

(defun json-encode (value &optional (stream *standard-output*))
  "Write VALUE to STREAM in JSON form.  Return VALUE.
Tables become objects, vectors become arrays, T becomes true,
:false becomes false and NIL becomes null."
  (declare (type stream stream))
  (etypecase value
    (hash-table
     (write-char #\{ stream)
     (loop for key in (%json-object-keys value)
           for first = t then nil
           do (unless first (write-char #\, stream))
              (%json-escape (%json-key-string key) stream)
              (write-char #\: stream)
              (json-encode (gethash key value) stream))
     (write-char #\} stream))
    (string (%json-escape value stream))
    (vector
     (write-char #\[ stream)
     (loop for index below (length value)
           do (when (plusp index) (write-char #\, stream))
              (json-encode (aref value index) stream))
     (write-char #\] stream))
    (cons
     (write-char #\[ stream)
     (loop for rest on value
           do (when (rest rest) (write-char #\, stream))
              (json-encode (first rest) stream))
     (write-char #\] stream))
    (integer (format stream "~D" value))
    (float (format stream "~,6F" value))
    ((eql t) (write-string "true" stream))
    ((eql :false) (write-string "false" stream))
    (null (write-string "null" stream)))
  value)

(defun json-encode-to-string (value)
  "Return VALUE as a JSON string."
  (with-output-to-string (stream)
    (json-encode value stream)))

;;; ---------------------------------------------------------------------
;;; Parsing

(defstruct (json-cursor (:constructor make-json-cursor (text)))
  "Position inside a JSON TEXT."
  (text "" :type string)
  (index 0 :type fixnum))

(defun %json-peek (cursor)
  "Return the character at CURSOR, or NIL at the end of the text."
  (let ((index (json-cursor-index cursor))
        (text (json-cursor-text cursor)))
    (when (< index (length text))
      (char text index))))

(defun %json-advance (cursor)
  "Move CURSOR past one character and return it."
  (prog1 (%json-peek cursor)
    (incf (json-cursor-index cursor))))

(defun %json-skip-whitespace (cursor)
  "Move CURSOR past JSON white space."
  (loop for character = (%json-peek cursor)
        while (and character (%space-p character))
        do (incf (json-cursor-index cursor))))

(defun %json-error (cursor message)
  "Signal a parse error at CURSOR with MESSAGE."
  (error "JSON parse error at ~D: ~A"
         (json-cursor-index cursor)
         message))

(defun %json-expect (cursor character)
  "Consume CHARACTER at CURSOR or signal an error."
  (unless (char= (or (%json-peek cursor) #\Nul) character)
    (%json-error cursor (format nil "expected ~S" character)))
  (%json-advance cursor))

(defun %json-read-unicode-escape (cursor)
  "Read four hexadecimal digits at CURSOR and return the code point."
  (let ((value 0))
    (dotimes (index 4 value)
      (declare (ignore index))
      (let ((character (%json-advance cursor)))
        (unless character
          (%json-error cursor "truncated unicode escape"))
        (let ((digit (digit-char-p character 16)))
          (unless digit
            (%json-error cursor "invalid unicode escape"))
          (setf value (+ (* value 16) digit)))))))

(defun %json-read-string (cursor)
  "Read a JSON string at CURSOR."
  (%json-expect cursor #\")
  (let ((output (make-string-output-stream)))
    (loop for character = (%json-advance cursor)
          do (cond
               ((null character)
                (%json-error cursor "unterminated string"))
               ((char= character #\")
                (return (get-output-stream-string output)))
               ((char= character #\\)
                (let ((escape (%json-advance cursor)))
                  (case escape
                    (#\" (write-char #\" output))
                    (#\\ (write-char #\\ output))
                    (#\/ (write-char #\/ output))
                    (#\b (write-char #\Backspace output))
                    (#\f (write-char #\Page output))
                    (#\n (write-char #\Newline output))
                    (#\r (write-char #\Return output))
                    (#\t (write-char #\Tab output))
                    (#\u (write-char (code-char (%json-read-unicode-escape cursor))
                                    output))
                    (t (%json-error cursor "invalid escape")))))
               (t (write-char character output))))))

(defun %json-read-number (cursor)
  "Read a JSON number at CURSOR."
  (let ((start (json-cursor-index cursor))
        (text (json-cursor-text cursor)))
    (loop for character = (%json-peek cursor)
          while (and character
                     (or (digit-char-p character)
                         (find character "-+.eE" :test #'char=)))
          do (incf (json-cursor-index cursor)))
    (let ((token (subseq text start (json-cursor-index cursor))))
      (handler-case
          (if (or (find #\. token) (find #\e token) (find #\E token))
              (let ((*read-default-float-format* 'double-float) (*read-eval* nil))
                (read-from-string token))
              (parse-integer token))
        (error () (%json-error cursor "invalid number"))))))

(defun %json-read-literal (cursor literal value)
  "Consume LITERAL at CURSOR and return VALUE."
  (let ((start (json-cursor-index cursor)))
    (unless (and (<= (+ start (length literal)) (length (json-cursor-text cursor)))
                 (string= literal
                          (json-cursor-text cursor)
                          :start1 0
                          :start2 start
                          :end2 (+ start (length literal))))
      (%json-error cursor (format nil "expected ~A" literal)))
    (incf (json-cursor-index cursor) (length literal))
    value))

(defun %json-read-array (cursor)
  "Read a JSON array at CURSOR as a vector."
  (%json-expect cursor #\[)
  (%json-skip-whitespace cursor)
  (if (char= (or (%json-peek cursor) #\Nul) #\])
      (progn (%json-advance cursor) #())
      (let ((items '()))
        (loop
          (push (%json-read-value cursor) items)
          (%json-skip-whitespace cursor)
          (let ((character (%json-advance cursor)))
            (cond ((null character)
                   (%json-error cursor "unterminated array"))
                  ((char= character #\]) (return (coerce (nreverse items) 'vector)))
                  ((char= character #\,) (%json-skip-whitespace cursor))
                  (t (%json-error cursor "expected , or ]"))))))))

(defun %json-read-object (cursor)
  "Read a JSON object at CURSOR as a hash table."
  (%json-expect cursor #\{)
  (%json-skip-whitespace cursor)
  (let ((table (make-hash-table :test #'equal)))
    (if (char= (or (%json-peek cursor) #\Nul) #\})
        (progn (%json-advance cursor) table)
        (loop
          (%json-skip-whitespace cursor)
          (let ((key (%json-read-string cursor)))
            (%json-skip-whitespace cursor)
            (%json-expect cursor #\:)
            (setf (gethash key table) (%json-read-value cursor)))
          (%json-skip-whitespace cursor)
          (let ((character (%json-advance cursor)))
            (cond ((null character)
                   (%json-error cursor "unterminated object"))
                  ((char= character #\}) (return table))
                  ((char= character #\,) nil)
                  (t (%json-error cursor "expected , or }"))))))))

(defun %json-read-value (cursor)
  "Read one JSON value at CURSOR."
  (%json-skip-whitespace cursor)
  (let ((character (%json-peek cursor)))
    (case character
      (#\{ (%json-read-object cursor))
      (#\[ (%json-read-array cursor))
      (#\" (%json-read-string cursor))
      (#\t (%json-read-literal cursor "true" t))
      (#\f (%json-read-literal cursor "false" :false))
      (#\n (%json-read-literal cursor "null" nil))
      ((#\- #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
       (%json-read-number cursor))
      (t (%json-error cursor "unexpected character")))))

(defun json-parse (text)
  "Parse TEXT as JSON.  Objects become hash tables, arrays become vectors."
  (let* ((cursor (make-json-cursor text))
         (value (%json-read-value cursor)))
    (%json-skip-whitespace cursor)
    (when (%json-peek cursor)
      (%json-error cursor "trailing data"))
    value))

(defun read-file-string (path)
  "Return the contents of PATH as a string."
  (with-open-file (stream path :direction :input :external-format :utf-8)
    (let ((text (make-string (file-length stream))))
      (subseq text 0 (read-sequence text stream)))))
