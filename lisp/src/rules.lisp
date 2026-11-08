(in-package #:pdpa-sbcl)

;;;; rules.lisp -- the rule pack as mutable CLOS instances.
;;;;
;;;; Every rule carries a matcher function and a list of literal
;;;; triggers.  A trigger is a lower-case string that must occur in a
;;;; line before the matcher can fire.  The trigger is a fast reject
;;;; path: a rule with no trigger is always tested.

(defclass rule ()
  ((id
    :accessor pdpa-rule-id
    :initarg :id
    :type string
    :documentation "Stable rule identifier used in reports.")
   (label
    :accessor pdpa-rule-label
    :initarg :label
    :type string
    :documentation "Human-readable finding text.")
   (severity
    :accessor pdpa-rule-severity
    :initarg :severity
    :type keyword
    :documentation "One of :critical, :high, :medium or :low.")
   (kind
    :accessor pdpa-rule-kind
    :initarg :kind
    :type keyword
    :documentation "Finding family, for example :pii or :secret.")
   (tier
    :accessor pdpa-rule-tier
    :initarg :tier
    :type keyword
    :documentation "Mesh tier: :critical or :standard.")
   (matcher
    :accessor pdpa-rule-matcher
    :initarg :matcher
    :type symbol
    :documentation "Name of a function of one lower-case string.")
   (triggers
    :accessor pdpa-rule-triggers
    :initarg :triggers
    :type list
    :documentation "Lower-case literal strings that must precede a match."))
  (:documentation "One compliance screening rule."))

(defun severity-tier (severity)
  "Return the mesh tier for SEVERITY."
  (if (member severity '(:critical :high) :test #'eq)
      :critical
      :standard))

(defun make-rule (&key id label severity kind matcher triggers)
  "Return a rule instance built from the given slots."
  (make-instance 'rule
                 :id id
                 :label label
                 :severity severity
                 :kind kind
                 :tier (severity-tier severity)
                 :matcher matcher
                 :triggers triggers))

(defun %rule-specifications ()
  "Return the rule pack as a list of slot plists."
  (list
   (list :id "nric-live"
         :label "Live Singapore NRIC / FIN (Mod-11 valid)"
         :severity :critical :kind :pii
         :matcher 'match-nric-live-p :triggers '())
   (list :id "phone-sg"
         :label "Singapore phone number with country code (+65)"
         :severity :critical :kind :pii
         :matcher 'match-phone-p :triggers '("+65"))
   (list :id "email-live"
         :label "Email address in source code"
         :severity :low :kind :pii
         :matcher 'match-email-p :triggers '("@"))
   (list :id "aws-key"
         :label "AWS access key id"
         :severity :high :kind :secret
         :matcher 'match-aws-key-p :triggers '("akia"))
   (list :id "aws-secret"
         :label "AWS secret access key assignment"
         :severity :high :kind :secret
         :matcher 'match-aws-secret-p :triggers '("aws_secret"))
   (list :id "aws-session"
         :label "AWS temporary session key id (ASIA)"
         :severity :high :kind :secret
         :matcher 'match-aws-session-p :triggers '("asia"))
   (list :id "jwt-token"
         :label "JSON Web Token (three-segment bearer token)"
         :severity :high :kind :secret
         :matcher 'match-jwt-p :triggers '("eyj"))
   (list :id "cyberark-conjur"
         :label "CyberArk Conjur API key assignment"
         :severity :high :kind :secret
         :matcher 'match-conjur-p :triggers '("conjur"))
   (list :id "slack-token"
         :label "Slack token (xoxb/xoxp/xoxa/xoxs)"
         :severity :high :kind :secret
         :matcher 'match-slack-p :triggers '("xox"))
   (list :id "openai-key"
         :label "OpenAI project API key"
         :severity :high :kind :secret
         :matcher 'match-openai-key-p :triggers '("sk-proj-"))
   (list :id "anthropic-key"
         :label "Anthropic API key"
         :severity :high :kind :secret
         :matcher 'match-anthropic-key-p :triggers '("sk-ant-"))
   (list :id "gcp-key"
         :label "Google Cloud API key"
         :severity :high :kind :secret
         :matcher 'match-gcp-key-p :triggers '("aiza"))
   (list :id "azure-conn-str"
         :label "Azure storage connection string"
         :severity :high :kind :secret
         :matcher 'match-azure-connection-p
         :triggers '("defaultendpointsprotocol="))
   (list :id "azure-account-key"
         :label "Azure storage account key assignment"
         :severity :high :kind :secret
         :matcher 'match-azure-account-key-p :triggers '("account"))
   (list :id "stripe-live"
         :label "Stripe live secret key"
         :severity :high :kind :secret
         :matcher 'match-stripe-p :triggers '("sk_live_"))
   (list :id "pat-token"
         :label "GitHub token (PAT / OAuth / App / user-to-server)"
         :severity :high :kind :secret
         :matcher 'match-github-token-p :triggers '("gh"))
   (list :id "private-key"
         :label "PEM private key block"
         :severity :high :kind :secret
         :matcher 'match-private-key-p :triggers '("-----begin"))
   (list :id "django-insecure-key"
         :label "Django 'django-insecure-' placeholder committed"
         :severity :medium :kind :secret
         :matcher 'match-django-key-p :triggers '("secret_key"))
   (list :id "hardcoded-password"
         :label "Hardcoded password value (non-empty, non-test)"
         :severity :medium :kind :secret
         :matcher 'match-password-assignment-p :triggers '("pass" "pwd"))
   (list :id "hardcoded-secret"
         :label "Generic API secret literal"
         :severity :medium :kind :secret
         :matcher 'match-secret-assignment-p
         :triggers '("api" "secret" "token"))))

(defun make-rule-pack ()
  "Return a fresh list of rule instances."
  (loop for specification in (%rule-specifications)
        collect (apply #'make-rule specification)))

(defparameter *rule-table* (make-rule-pack)
  "Default rule pack.  Rebind or mutate it to change screening policy.")

(defun rule-pack ()
  "Return the current default rule pack."
  *rule-table*)
