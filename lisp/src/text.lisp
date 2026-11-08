(in-package #:pdpa-sbcl)

;;;; text.lisp -- ASCII string primitives.
;;;;
;;;; The strainer uses these helpers instead of an external regular
;;;; expression library.  Every helper works on simple strings and has
;;;; no dependency outside the Common Lisp standard.

(declaim (inline %ascii-lower-char))

(defun %ascii-lower-char (character)
  "Return CHARACTER folded to lower case when it is an ASCII letter."
  (let ((code (char-code character)))
    (if (and (>= code 65) (<= code 90))
        (code-char (+ code 32))
        character)))

(defun ascii-downcase (string)
  "Return a lower-case copy of STRING.  Only ASCII letters change."
  (declare (type string string))
  (map 'string #'%ascii-lower-char string))

(defun %find-literal (needle haystack &key (start 0))
  "Return the first position of NEEDLE in HAYSTACK at or after START."
  (declare (type string needle haystack))
  (when (plusp (length needle))
    (search needle haystack :start2 (max 0 start))))

(defun %space-p (character)
  "Return true when CHARACTER is horizontal or vertical white space."
  (or (char= character #\Space)
      (char= character #\Tab)
      (char= character #\Return)
      (char= character #\Newline)))

(defun %word-char-p (character)
  "Return true when CHARACTER can continue a word token."
  (or (alphanumericp character)
      (char= character #\_)))

(defun %upper-alnum-p (character)
  "Return true for an ASCII digit or an upper-case ASCII letter."
  (let ((code (char-code character)))
    (or (and (>= code 48) (<= code 57))
        (and (>= code 65) (<= code 90)))))

(defun %base64-p (character)
  "Return true when CHARACTER belongs to the standard base64 alphabet."
  (or (alphanumericp character)
      (char= character #\/)
      (char= character #\+)
      (char= character #\=)))

(defun %token-char-p (character)
  "Return true for characters allowed inside API key and token bodies."
  (or (alphanumericp character)
      (char= character #\_)
      (char= character #\-)))

(defun %count-run (string start predicate)
  "Count the characters at START that satisfy PREDICATE."
  (declare (type string string)
           (type fixnum start))
  (let ((length (length string))
        (index start))
    (loop while (and (< index length)
                     (funcall predicate (char string index)))
          do (incf index))
    (- index start)))

(defun %skip-space (string index)
  "Return the first index at or after INDEX that is not white space."
  (declare (type string string)
           (type fixnum index))
  (let ((length (length string)))
    (loop while (and (< index length) (%space-p (char string index)))
          do (incf index))
    index))

(defun %skip-chars (string index characters)
  "Return the first index at or after INDEX that is not in CHARACTERS."
  (declare (type string string)
           (type fixnum index))
  (let ((length (length string)))
    (loop while (and (< index length)
                     (find (char string index) characters :test #'char=))
          do (incf index))
    index))

(defun %quoted-region (string quote-index)
  "Return the index of the quote that closes the region at QUOTE-INDEX."
  (declare (type string string)
           (type fixnum quote-index))
  (let ((quote (char string quote-index))
        (length (length string))
        (index (1+ quote-index)))
    (loop while (and (< index length)
                     (not (char= (char string index) quote)))
          do (incf index))
    (when (< index length)
      index)))
