(require 'js2-mode)
(setq-default js2-allow-rhino-new-expr-initializer nil)
(setq-default js2-auto-indent-p nil)
(setq-default js2-enter-indents-newline nil)
(setq-default js2-global-externs '("define" "module" "require" "jQuery" "$" "_" "buster" "sinon" "assert" "refute" "setTimeout" "clearTimeout" "setInterval" "clearInterval" "location" "__dirname" "console" "JSON"))
(setq-default js2-idle-timer-delay 0.1)
(setq-default js2-indent-on-enter-key nil)
(setq-default js2-mirror-mode nil)
(setq-default js2-strict-inconsistent-return-warning nil)
(setq-default js2-auto-indent-p t)
(setq-default js2-rebind-eol-bol-keys nil)
(setq-default js2-include-rhino-externs nil)
(setq-default js2-include-gears-externs nil)
(setq-default js2-concat-multiline-strings 'eol)
(defadvice js2r-inline-var (after reindent-buffer activate)
  (cleanup-buffer))

;; sensible defaults for indentation
(custom-set-variables
 '(js2-basic-offset 2)
 '(js2-bounce-indent-p nil))

;; js2-mode steals TAB, let's steal it back for yasnippet
(defun js2-tab-properly ()
  (interactive)
  (let ((yas/fallback-behavior 'return-nil))
    (unless (yas/expand)
      (indent-for-tab-command)
      (if (looking-back "^\s*")
          (back-to-indentation)))))

(define-key js2-mode-map (kbd "TAB") 'js2-tab-properly)

;; Don't redefine C-a for me please, js2-mode
(define-key js2-mode-map (kbd "C-a") nil)

;; When renaming/deleting js-files, check for corresponding testfile
(define-key js2-mode-map (kbd "C-x C-r") 'js2r-rename-current-buffer-file)
(define-key js2-mode-map (kbd "C-x C-k") 'js2r-delete-current-buffer-file)

;; Use lambda for anonymous functions
(font-lock-add-keywords
 'js2-mode `(("\\(function\\) *("
              (0 (progn (compose-region (match-beginning 1)
                                        (match-end 1) "\u0192")
                        nil)))))

;; Use right arrow for return in one-line functions
(font-lock-add-keywords
 'js2-mode `(("function *([^)]*) *{ *\\(return\\) "
              (0 (progn (compose-region (match-beginning 1)
                                        (match-end 1) "\u27F6")
                        nil)))))

;; After js2 has parsed a js file, we look for jslint globals decl comment ("/* global Fred, _, Harry */") and
;; add any symbols to a buffer-local var of acceptable global vars
;; Note that we also support the "symbol: true" way of specifying names via a hack (remove any ":true"
;; to make it look like a plain decl, and any ':false' are left behind so they'll effectively be ignored as
;; you can;t have a symbol called "someName:false"
(add-hook 'js2-post-parse-callbacks
          (lambda ()
            (when (> (buffer-size) 0)
              (let ((btext (replace-regexp-in-string
                            ": *true" " "
                            (replace-regexp-in-string "[\n\t ]+" " " (buffer-substring-no-properties 1 (buffer-size)) t t))))
                (mapc (apply-partially 'add-to-list 'js2-additional-externs)
                      (split-string
                       (if (string-match "/\\* *global *\\(.*?\\) *\\*/" btext) (match-string-no-properties 1 btext) "")
                       " *, *" t))
                ))))

(defun cjsp--eldoc-innards (beg)
  (save-excursion
    (goto-char beg)
    (search-forward "=")
    (let ((start (point)))
      (search-forward "*/")
      (forward-char -2)
      (buffer-substring-no-properties start (point)))))

(defun cjsp--indentation-of-html-line (html line-number)
  (with-temp-buffer
    (insert html)
    (html-mode)
    (indent-region (point-min) (point-max))
    (goto-line line-number)
    (back-to-indentation)
    (current-column)))

(defun cjsp--line-number-in-eldoc (p beg)
  (save-excursion
    (goto-char p)
    (let ((l (line-number-at-pos)))
      (goto-char beg)
      (- l (line-number-at-pos) -1))))

(defun js2-lineup-comment (parse-status)
  "Indent a multi-line block comment continuation line."
  (let* ((beg (nth 8 parse-status))
         (first-line (js2-same-line beg))
         (p (point))
         (offset (save-excursion
                   (goto-char beg)
                   (cond

                    ((looking-at "/\\*:DOC ")
                     (+ 2 (current-column)
                        (cjsp--indentation-of-html-line
                         (cjsp--eldoc-innards beg)
                         (cjsp--line-number-in-eldoc p beg))))

                    ((looking-at "/\\*")
                     (+ 1 (current-column)))

                    (:else 0)))))
    (unless first-line
      (indent-line-to offset))))

(autoload 'js2-mode "js2-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.js$" . js2-mode))

(add-hook 'js2-mode-hook
          (lambda ()
            (requirejs-mode)))

(add-hook 'js2-mode-hook 'ac-js2-mode)

(provide 'setup-js2-mode)
