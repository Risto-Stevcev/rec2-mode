;;; rec2-mode.el --- Major mode for viewing/editing rec files  -*- lexical-binding: t; -*-

;; Author: Risto Stevcev <risto1@gmail.com>
;; Package-Requires: ((emacs "28"))
;; Version: 0.1.0


;;(require 'cl)

(defconst rec/keyword-prefix "%"
  "Prefix used to distinguish special fields.")

(defconst rec/keyword-rec (concat rec/keyword-prefix "rec")
  ;; Remember to update `rec/font-lock-keywords' if you change this
  ;; value!!
  "Rec keyword.")

(defconst rec/keyword-key (concat rec/keyword-prefix "key")
  "Key keyword.")

(defconst rec/keyword-mandatory (concat rec/keyword-prefix "mandatory")
  "Mandatory keyword.")

(defconst rec/keyword-summary (concat rec/keyword-prefix "summary")
  "Summary keyword.")

(defconst rec/time-stamp-format "%Y-%m-%d %a %H:%M"
  "Format for `format-time-string' which is used for time stamps.")

(defvar rec/comment-re "^#.*"
  "Regexp denoting a comment line.")

(defvar rec/comment-field-re "^\\(#.*\n\\)*\\([a-zA-Z0-1_%-]+:\\)+"
  "Regexp denoting the beginning of a record.")

(defvar rec/field-name-re
  "^[a-zA-Z%][a-zA-Z0-9_]*:"
  "Regexp matching a field name.")

(defvar rec/field-value-re
  "\\(?:\n\\+ ?\\|\\\\\n\\|\\\\.\\|[^\n\\]\\)*"
  "Regexp matching a field value.")

(defvar rec/type-re
  (concat "^" rec/keyword-rec ":\s+" "\\([[:word:]_]+\\)"))

(defvar rec/field-re
  (concat rec/field-name-re
          rec/field-value-re
          "\n")
  "Regexp matching a field.")

(defvar rec/record-re
  (concat rec/field-re "\\(" rec/field-re "\\|" rec/comment-re "\\)*")
  "Regexp matching a record.")

(defvar rec/constants
  '("yes" "no" "true" "false" "MIN" "MAX")
  "Symbols that are constants, like boolean values or MIN/MAX.")

(defvar rec/field-types
  '("line" "real" "int" "regexp" "enum" "date" "field" "uuid" "email" "bool" "size"
    "rec" "range" ))

(defvar rec/special-fields
  '("%rec" "%mandatory" "%unique" "%key" "%doc" "%typedef" "%type" "%auto" "%sort"
    "%size" "%constraint" "%confidential"))

(defvar rec/mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?# "<" st)   ; Comment start
    (modify-syntax-entry ?\n ">" st)  ; Comment end
    st)
  "Syntax table used in `rec/mode'.")

(defconst rec/syntax-propertize-function
  (syntax-propertize-rules
   ;; In rec, `#' only starts a comment when at BOL.
   (".\\(#\\)" (1 "."))))

(defface rec/continuation-line-face '((t :foreground "#808080"))
  "Face for line continuations (+).")

(defvar rec/font-lock-keywords
  `((,(regexp-opt rec/special-fields) . 'font-lock-builtin-face)
    (,(regexp-opt rec/constants) . 'font-lock-constant-face)
    (,(regexp-opt rec/field-types) . 'font-lock-type-face)
    (,rec/field-name-re . 'font-lock-variable-name-face)
    ("^\\+" . 'rec/continuation-line-face))
  "Font lock keywords used in `rec/mode'.")

(defun rec/trim-string (string)
  "Remove white spaces in beginning and ending of STRING.
White space here is any of: space, tab, emacs newline (line feed, ASCII 10)."
  (replace-regexp-in-string "\\`[ \t\n]*" "" (replace-regexp-in-string "[ \t\n]*\\'" "" string)))

(defun rec/current-file ()
  (buffer-file-name (window-buffer (minibuffer-selected-window))))

(defun rec/fix ()
  "Runs recfix on the current file."
  (interactive)
  (message
   (rec/trim-string
    (shell-command-to-string (concat "recfix " (rec/current-file))))))

(defun rec/info ()
  "Runs recinf on the current file."
  (interactive)
  (message
   (rec/trim-string
    (shell-command-to-string (concat "recinf " (rec/current-file))))))

(defun rec/current-record ()
  "Gets the current record."
  (re-search-backward "%rec: \\([A-Za-z0-9]+\\)")
  (match-string 1))

(defvar-local rec/field-value-re "^\\([A-Za-z0-9]+\\): *\\(.*\\)")

(defun rec/get-field (field-entry)
  (rec/trim-string
   (replace-regexp-in-string "^\\([A-Za-z0-9]+\\): .*" "\\1" field-entry)))

(defun rec/get-value (field-entry)
  (rec/trim-string
   (replace-regexp-in-string "^\\([A-Za-z0-9]+\\): *" "" field-entry)))

(defun rec/query (s)
  "Query for records with the provided expression."
  (interactive "sQuery: ")
  (let ((buffer-name "*recsel*"))
    (with-output-to-temp-buffer buffer-name
      (display-message-or-buffer
       (rec/trim-string
        (shell-command-to-string
         (format "recsel -t %s -e \"%s\" %s" (rec/current-record) s
                 (rec/current-file))))
       buffer-name)
      (pop-to-buffer buffer-name)
      (rec2-mode))))

(defun rec/filter-at-point ()
  "Query for records that match the given field and value."
  (interactive)
  (let* ((line (thing-at-point 'line))
         (field (rec/get-field line))
         (value (rec/get-value line))
         (buffer-name "*recsel*"))
    (with-output-to-temp-buffer buffer-name
      (display-message-or-buffer
       (rec/trim-string
        (shell-command-to-string
         (format "recsel -t %s -e \"%s = '%s'\" %s" (rec/current-record) field value
                 (rec/current-file))))
       buffer-name)
      (pop-to-buffer buffer-name)
      (rec2-mode))))

(defun rec/filter-keyword ()
  "Filter records by the given field."
  (interactive)
  (let* ((line (thing-at-point 'line))
         (field (rec/get-field line))
         (buffer-name "*recsel*"))
    (with-output-to-temp-buffer buffer-name
      (display-message-or-buffer
       (rec/trim-string
        (shell-command-to-string
         (format "recsel -t %s -P %s %s" (rec/current-record) field (rec/current-file))))
       buffer-name)
      (pop-to-buffer buffer-name)
      (rec2-mode))))

(defun rec/string-nl ()
  (interactive)
  (insert "\n+ "))

(defun rec/to-table ()
  (let ((buffer-name "*rec2csv*"))
    (with-output-to-temp-buffer buffer-name
      (display-message-or-buffer
       (shell-command-to-string
        (format "rec2csv %s" (rec/current-file)))
       buffer-name)
      (pop-to-buffer buffer-name)
      (org-table-convert-region 1 (buffer-size (get-buffer buffer-name)))
      (org-mode))))

(defun rec/first-word (s)
  (car (split-string s)))

(defun rec/first-word-to-list (s l)
  (when s
    (add-to-list 'l (rec/first-word value) t)))

(defun rec/snippet ()
  "Creates a snippet based on the current record"
  (let ((buffer-name "*rec/snippet*")
        (record-point (progn (rec/current-record) (point))))
    (with-output-to-temp-buffer buffer-name
      (display-message-or-buffer
       (string-join
        (pcase-dolist
            (`(record ,_ . ,`(,metadata))
             (car (read-from-string
                   (format "(%s)" (shell-command-to-string
                                   (format "recinf -d -S %s" (rec/current-file)))))))
          (let ((record-name nil)
                (fields '()))
            (pcase-dolist (`(field ,location ,type ,value) metadata)
              (pcase type
                ("%rec" (when (equal location record-point) (setf record-name value)))
                ("%type" (when record-name (add-to-list 'fields (rec/first-word value) t)))
                ("%unique" (when record-name (add-to-list 'fields (rec/first-word value) t)))
                ("%mandatory" (when record-name (add-to-list 'fields (rec/first-word value) t)))))
            (when fields
              (print
               (string-join
                (cons (format "# name: %s\n# --" record-name)
                      (loop for index from 1
                            for field in (cl-delete-duplicates fields)
                            collect
                            (format "%s: $%d" field index)))
                "\n"))))))
       buffer-name)
      (pop-to-buffer buffer-name)
      (text-mode))))

(defun rec/template (s)
  (interactive "sTemplate Path: ")
  (let* ((line (thing-at-point 'line))
        (field (rec/get-field line))
        (value (rec/get-value line))
        (buffer-name "*recfmt*"))
    (with-output-to-temp-buffer buffer-name
      (display-message-or-buffer
       (shell-command-to-string
        (format "recsel -t %s -e \"%s = '%s'\" %s | recfmt -f %s" (rec/current-record) field value
                (rec/current-file) s))
       buffer-name)
      (pop-to-buffer buffer-name))))

(defvar rec/mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-f") 'rec/fix)
    (define-key map (kbd "C-c C-i") 'rec/info)
    (define-key map (kbd "C-c C-s") 'rec/query)
    (define-key map (kbd "C-c C-l") 'rec/filter-at-point)
    (define-key map (kbd "C-c C-k") 'rec/filter-keyword)
    (define-key map (kbd "M-j") 'rec/string-nl)
    map)
  "Keymap for 'rec2-mode'.")

(define-derived-mode rec2-mode fundamental-mode "Recutils"
  "A major mode for editing recutils rec files.
\\{rec/mode-map}"
  :syntax-table rec/mode-syntax-table
  (use-local-map rec/mode-map)
  (setq font-lock-defaults '(rec/font-lock-keywords)))

(easy-menu-define rec-mode-menu rec/mode-map
  "Menu for rec2-mode."
  '("Recutils"
    ["Fix" rec/fix]
    ["Info" rec/info]
    ["Query" rec/query]
    ["Filter-at-point" rec/filter-at-point]
    ["Filter-keyword" rec/filter-keyword]))

;; Automatically choose this mode
(add-to-list 'auto-mode-alist '("\\.rec\\'" . rec2-mode))

(provide 'rec2-mode)
;;; rec2-mode.el ends here
