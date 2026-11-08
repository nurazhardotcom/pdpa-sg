(in-package #:pdpa-sg)

;;;; match.lisp -- zero-dependency matchers for the rule pack.
;;;;
;;;; Every matcher takes one lower-case string and returns a boolean.
;;;; The callers pass the ASCII-downcased line, so case-insensitive
;;;; rules need no per-rule folding.

;;; ---------------------------------------------------------------------
;;; Shared scans

(defun %assignment-value-start (text keyword &key (start 0))
  "Return the index after KEYWORD, a separator and an opening quote.
TEXT is lower case.  Return NIL when the assignment shape is absent."
  (let ((position (search keyword text :start2 start)))
    (when position
      (let* ((length (length text))
             (index (+ position (length keyword))))
        (setf index (%skip-space text index))
        (when (and (< index length)
                   (or (char= (char text index) #\:)
                       (char= (char text index) #\=)))
          (incf index)
          (setf index (%skip-space text index))
          (when (and (< index length)
                     (or (char= (char text index) #\')
                         (char= (char text index) #\")))
            (1+ index)))))))

(defun %has-word-run (text start length)
  "Return true when TEXT holds LENGTH word characters at START."
  (and (<= (+ start length) (length text))
       (loop for index from start below (+ start length)
             always (%word-char-p (char text index)))))

(defun %has-run (text start length predicate)
  "Return true when TEXT holds LENGTH characters at START that satisfy PREDICATE."
  (and (<= (+ start length) (length text))
       (loop for index from start below (+ start length)
             always (funcall predicate (char text index)))))

(defun %scan-after (text needle &key (start 0) (test #'char=))
  "Return the index just after NEEDLE in TEXT at or after START, or NIL."
  (let ((position (search needle text :start2 start :test test)))
    (when position
      (+ position (length needle)))))

;;; ---------------------------------------------------------------------
;;; PII rules

(defun match-nric-live-p (text)
  "Return true when TEXT holds a checksum-valid NRIC or FIN."
  (not (null (find-valid-nrics text))))

(defun match-phone-p (text)
  "Return true for a Singapore mobile number written with the +65 prefix."
  (let ((length (length text))
        (start 0))
    (loop
      (let ((position (search "+65" text :start2 start)))
        (unless position (return nil))
        (let ((index (+ position 3)))
          (when (and (< index length) (%space-p (char text index)))
            (incf index))
          (when (and (< index length)
                     (or (char= (char text index) #\8)
                         (char= (char text index) #\9))
                     (%has-run text (1+ index) 7 #'digit-char-p))
            (return t))
          (setf start (1+ position)))))))

(defun %example-domain-p (text)
  "Return true when TEXT carries an example.com, .org or .net address."
  (or (search "@example.com" text)
      (search "@example.org" text)
      (search "@example.net" text)))

(defun match-email-p (text)
  "Return true for an email address that is not an example domain."
  (unless (%example-domain-p text)
    (let ((length (length text))
          (start 0))
      (loop
        (let ((at (position #\@ text :start start)))
          (unless at (return nil))
          (let ((left at)
                (right (1+ at)))
            (loop while (and (plusp left)
                             (or (alphanumericp (char text (1- left)))
                                 (find (char text (1- left)) "._%+-" :test #'char=)))
                  do (decf left))
            (loop while (and (< right length)
                             (or (alphanumericp (char text right))
                                 (find (char text right) ".-" :test #'char=)))
                  do (incf right))
            (let* ((domain (subseq text (1+ at) right))
                   (dot (position #\. domain :from-end t)))
              (when (and (< left at)
                         dot
                         (plusp dot)
                         (<= (+ dot 3) (length domain))
                         (loop for index from (1+ dot) below (length domain)
                               always (alpha-char-p (char domain index))))
                (return t))))
          (setf start (1+ at)))))))

;;; ---------------------------------------------------------------------
;;; Secret rules

(defun match-aws-key-p (text)
  "Return true for an AWS access key id."
  (let ((start 0))
    (loop
      (let ((position (search "akia" text :start2 start)))
        (unless position (return nil))
        (when (%has-word-run text (+ position 4) 16)
          (return t))
        (setf start (1+ position))))))

(defun match-aws-session-p (text)
  "Return true for an AWS temporary session key id."
  (let ((start 0))
    (loop
      (let ((position (search "asia" text :start2 start)))
        (unless position (return nil))
        (when (%has-word-run text (+ position 4) 16)
          (return t))
        (setf start (1+ position))))))

(defun match-aws-secret-p (text)
  "Return true for an AWS secret access key assignment."
  (let ((start 0))
    (loop
      (let ((index (%assignment-value-start text "aws_secret_access_key" :start start)))
        (unless index (return nil))
        (when (%has-run text index 40 #'%base64-p)
          (return t))
        (setf start (1+ index))))))

(defun match-jwt-p (text)
  "Return true for a three-segment JSON Web Token."
  (let ((start 0))
    (loop
      (let ((position (search "eyj" text :start2 start)))
        (unless position (return nil))
        (let* ((head (+ position 3))
               (first-length (%count-run text head #'%token-char-p)))
          (when (>= first-length 10)
            (let ((first-dot (+ head first-length)))
              (when (and (< first-dot (length text))
                         (char= (char text first-dot) #\.))
                (let ((second-length (%count-run text (1+ first-dot) #'%token-char-p)))
                  (when (>= second-length 10)
                    (let ((second-dot (+ first-dot 1 second-length)))
                      (when (and (< second-dot (length text))
                                 (char= (char text second-dot) #\.))
                        (let ((third-length (%count-run text (1+ second-dot)
                                                        (lambda (character)
                                                          (or (%token-char-p character)
                                                              (char= character #\=))))))
                          (when (>= third-length 10) (return t)))))))))))
        (setf start (1+ position))))))

(defun match-conjur-p (text)
  "Return true for a CyberArk Conjur API key assignment."
  (let ((start 0))
    (loop
      (let ((position (search "conjur" text :start2 start)))
        (unless position (return nil))
        (let ((api (search "api" text :start2 (+ position 6))))
          (when (and api (<= (- api (+ position 6)) 80))
            (let* ((length (length text))
                   (index (+ api 3)))
              (when (and (< index length)
                         (or (char= (char text index) #\_)
                             (char= (char text index) #\-)))
                (incf index))
              (when (and (<= (+ index 3) length)
                         (string= "key" text :start1 0 :start2 index :end2 (+ index 3)))
                (setf index (%skip-space text (+ index 3)))
                (when (and (< index length)
                           (or (char= (char text index) #\:)
                               (char= (char text index) #\=)))
                  (setf index (%skip-space text (1+ index)))
                  (when (and (< index length)
                             (or (char= (char text index) #\')
                                 (char= (char text index) #\")))
                    (let ((closing (%quoted-region text index)))
                      (when (and closing (>= (- closing index) 9))
                        (return t)))))))))
        (setf start (1+ position))))))

(defun match-slack-p (text)
  "Return true for a Slack token."
  (let ((start 0))
    (loop
      (let ((position (search "xox" text :start2 start)))
        (unless position (return nil))
        (let ((index (+ position 3)))
          (when (and (< index (length text))
                     (find (char text index) "bpas" :test #'char=)
                     (< (1+ index) (length text))
                     (char= (char text (1+ index)) #\-))
            (when (>= (%count-run text (+ index 2) #'%token-char-p) 10)
              (return t))))
        (setf start (1+ position))))))

(defun %prefixed-token-p (text prefix length)
  "Return true when TEXT holds PREFIX followed by LENGTH token characters."
  (let ((index (%scan-after text prefix)))
    (when (and index (>= (%count-run text index #'%token-char-p) length))
      t)))

(defun match-openai-key-p (text)
  "Return true for an OpenAI project key."
  (%prefixed-token-p text "sk-proj-" 20))

(defun match-anthropic-key-p (text)
  "Return true for an Anthropic key."
  (%prefixed-token-p text "sk-ant-" 20))

(defun match-gcp-key-p (text)
  "Return true for a Google Cloud API key."
  (%prefixed-token-p text "aiza" 35))

(defun match-azure-connection-p (text)
  "Return true for an Azure storage connection string."
  (let ((index (%scan-after text "defaultendpointsprotocol=")))
    (when index
      (let ((scheme-end (%scan-after text "http" :start index)))
        (when scheme-end
          (let ((length (length text)))
            (when (and (< scheme-end length)
                       (char= (char text scheme-end) #\s))
              (incf scheme-end))
            (when (and (< scheme-end length)
                       (char= (char text scheme-end) #\;))
              (let ((value-start (1+ scheme-end)))
                (when (and (< value-start length)
                           (not (%space-p (char text value-start)))
                           (not (find (char text value-start) "'\"" :test #'char=)))
                  t)))))))))

(defun match-azure-account-key-p (text)
  "Return true for an Azure storage account key assignment."
  (let ((start 0))
    (loop
      (let ((position (search "account" text :start2 start)))
        (unless position (return nil))
        (let ((index (+ position 7))
              (length (length text)))
          (when (and (< index length)
                     (or (char= (char text index) #\_)
                         (char= (char text index) #\-)))
            (incf index))
          (when (and (<= (+ index 3) length)
                     (string= "key" text :start1 0 :start2 index :end2 (+ index 3)))
            (setf index (%skip-space text (+ index 3)))
            (when (and (< index length)
                       (or (char= (char text index) #\:)
                           (char= (char text index) #\=)))
              (setf index (%skip-space text (1+ index)))
              (setf index (%skip-chars text index "'\""))
              (when (>= (%count-run text index #'%base64-p) 44)
                (return t)))))
        (setf start (1+ position))))))

(defun match-stripe-p (text)
  "Return true for a Stripe live secret key."
  (let ((start 0))
    (loop
      (let ((position (search "sk_live_" text :start2 start)))
        (unless position (return nil))
        (when (>= (%count-run text (+ position 8) #'alphanumericp) 16)
          (return t))
        (setf start (1+ position))))))

(defun match-github-token-p (text)
  "Return true for a GitHub token."
  (or (loop for prefix in '("ghp_" "gho_" "ghu_" "ghs_" "ghr_")
            for index = (%scan-after text prefix)
            when (and index (>= (%count-run text index #'alphanumericp) 36))
            return t)
      (%prefixed-token-p text "github_pat_" 20)))

(defun match-private-key-p (text)
  "Return true for a PEM private key header."
  (let ((begin (%scan-after text "-----begin")))
    (when begin
      (let ((subject (%scan-after text "private key" :start begin)))
        (when subject
          (search "-----" text :start2 subject))))))

(defun match-django-key-p (text)
  "Return true for the Django insecure placeholder secret."
  (when (%assignment-value-start text "secret_key")
    (search "django-insecure-" text)))

;;; ---------------------------------------------------------------------
;;; Credential assignments

(defun %has-any (text needles)
  "Return true when TEXT holds one of NEEDLES."
  (loop for needle in needles
        thereis (search needle text)))

(defun %password-value-start (text start)
  "Return the value start of the first password assignment at START."
  (loop for keyword in '("password" "passwd" "pwd")
        for index = (%assignment-value-start text keyword :start start)
        when index
        return index))

(defun match-password-assignment-p (text)
  "Return true for a hard-coded password literal."
  (unless (%has-any text '("test" "fake" "example"))
    (let ((start 0))
      (loop
        (let ((index (%password-value-start text start)))
          (unless index (return nil))
          (let ((length (%count-run
                         text index
                         (lambda (character)
                           (and (not (%space-p character))
                                (not (find character ".'\"{" :test #'char=)))))))
            (when (>= length 6)
              (return t))))
        (incf start)))))

(defun %secret-value-start (text start)
  "Return the value start of the first secret assignment at START."
  (loop for keyword in '("api_key" "api-key" "apikey" "secret" "token")
        for index = (%assignment-value-start text keyword :start start)
        when index
        return index))

(defun match-secret-assignment-p (text)
  "Return true for a generic hard-coded API secret literal."
  (let ((start 0))
    (loop
      (let ((index (%secret-value-start text start)))
        (unless index (return nil))
        (when (>= (%count-run text index #'%token-char-p) 16)
          (return t))
        (incf start)))))
