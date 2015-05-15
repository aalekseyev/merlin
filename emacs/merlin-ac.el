;;; merlin-ac.el --- Merlin and auto-complete integration.   -*- coding: utf-8 -*-
;; Licensed under the MIT license.

;; Author: Simon Castellan <simon.castellan(_)iuwt.fr>
;;         Frédéric Bour <frederic.bour(_)lakaban.net>
;;         Thomas Refis <thomas.refis(_)gmail.com>
;; Created: 15 May 2015
;; Version: 0.1
;; Keywords: ocaml languages
;; URL: http://github.com/the-lambda-church/merlin

(require 'merlin)
(require 'auto-complete)

;; Customization group

(defgroup merlin-ac nil
  "Merlin integration to auto-complete"
  :group 'merlin :prefix "merlin-ac-")

(defcustom merlin-ac-setup 'easy
  "Determine how `merlin' integrates with `auto-complete'."
  :group 'merlin-ac
  :type '(choice (const :tag "Integrate with auto-complete" t)
                 (const :tag "Integrate with auto-complete, use sane default options" easy)
                 (const :tag "Don't integrate with auto-complete" nil)))

(defcustom merlin-ac-prefix-size 0
  "If non-nil, specify the minimum number of characters to wait before allowing
auto-complete"
  :group 'merlin-ac :type 'integer)

(defcustom merlin-ac-use-summary t
  "Display types in :summary"
  :group 'merlin-ac :type 'boolean)

(defcustom merlin-ac-use-document nil
  "Display types in :document"
  :group 'merlin-ac :type 'boolean)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; FIXME Some internal functions from merlin are used in this file:
;; - merlin--completion-format-entry
;; - merlin--completion-full-entry-name
;; - merlin--completion-prefix
;; - merlin--completion-data
;; - merlin--locate-pure
;;
;; It would be nice to define a proper (somewhat stable) interface in merlin.el
;; to be used by other modules.


;; Internal variables

(defvar-local merlin-ac--point nil
  "Stores the point of last completion (beginning of the prefix).")

(defvar-local merlin-ac--cache nil
  "Hold a table mapping completion cache for auto-complete.")

(defvar-local merlin-ac--prefix ""
  "The cache of the prefix for completion")

(defvar-local merlin-ac--ac-prefix ""
  "The original value of ac-prefix used when computing merlin-ac--prefix")

;; Internal functions

(defun merlin-ac--make-popup-item (data)
  "Create a popup item from data DATA."
  (let ((typ (merlin--completion-format-entry data)))
    (popup-make-item
     ;; Note: ac refuses to display an item if merlin-ac--ac-prefix is not a
     ;; prefix the item. So "dwim" completion won't work with ac.
     (merlin--completion-full-entry-name merlin-ac--prefix data)
     :summary (when (and merlin-completion-types merlin-ac-use-summary) typ)
     :symbol (format "%c" (elt (cdr (assoc 'kind data)) 0))
     :document (if (and merlin-completion-types merlin-ac-use-document) typ))))

(defun merlin-ac--source-refresh-cache ()
  "Refresh the cache of completion."
  (setq merlin-ac--prefix (merlin--completion-prefix ac-prefix))
  (setq merlin-ac--ac-prefix ac-prefix)
  (setq merlin-ac--cache (mapcar #'merlin-ac--make-popup-item
                                 (merlin--completion-data merlin-ac--prefix))))

(defun merlin-ac--source-init ()
  "Initialize the cache for `auto-complete' completion.
Called at the beginning of a completion to fill the cache (the
variable `merlin-ac--cache')."
  (merlin/sync-to-point ac-point)
  (setq merlin-ac--point ac-point)
  (merlin-ac--source-refresh-cache))

(defun merlin-ac--prefix ()
  "Retrieve the prefix for completion with merlin."
  (let* ((bounds (merlin/completion-bounds))
         (start  (car-safe bounds))
         (end    (cdr-safe bounds)))
    (unless (and bounds (< (- start end) merlin-ac-prefix-size))
      start)))

(defun merlin-ac--fetch-type ()
  "Prints the type of the selected candidate"
  (let ((candidate (merlin/buffer-substring merlin-ac--point (point))))
    (when merlin-completion-types
      (mapc (lambda (item)
              (when (string-equal candidate item)
                (message "%s: %s" candidate (popup-item-summary item))))
            merlin-ac--cache))))

(defun merlin-ac--candidates ()
  "Return the candidates for auto-completion with auto-complete. If the cache is
wrong then recompute it."
  (unless (and (equal (merlin--completion-prefix ac-prefix) merlin-ac--prefix)
               (string-prefix-p merlin-ac--ac-prefix ac-prefix))
    (merlin-ac--source-refresh-cache))
  merlin-ac--cache)

;; Public functions

(defun merlin-ac-setup-easy ()
  "Integrate merlin to auto-complete with sane defaults"
  (auto-complete-mode t)
  (set (make-local-variable 'ac-auto-show-menu) t)
  (set (make-local-variable 'ac-auto-start) nil)
  (set (make-local-variable 'ac-delay) 0.0)
  (set (make-local-variable 'ac-expand-on-auto-complete) nil)
  (set (make-local-variable 'ac-ignore-case) nil)
  (set (make-local-variable 'ac-trigger-commands) nil))

;; I don't like it beginning by "ac" but it is the only way I found to get it
;; working (otherwise the completion menu just closes itself)
(defun ac-merlin-locate ()
  "Locate the identifier currently selected in the ac-completion."
  (interactive)
  (when (ac-menu-live-p)
    (merlin/sync-to-point)
    (when (popup-hidden-p ac-menu)
      (ac-show-menu))
    (let ((merlin-locate-in-new-window 'always))
      (merlin--locate-pure (ac-selected-candidate)))
    (ac-show-menu)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Register into auto-complete and merlin ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar merlin-ac-source '((init . merlin-ac--source-init)
                           (candidates . merlin-ac--candidates)
                           (action . merlin-ac--fetch-type)
                           (prefix . merlin-ac--prefix)))

(ac-define-source "merlin" merlin-ac-source)
(define-key ac-complete-mode-map (kbd "C-c C-l") 'ac-merlin-locate)

(defun merlin-ac--setup ()
  (when merlin-ac-setup
    (if (equal merlin-ac-setup 'easy)
        (merlin-ac-setup-easy)
      (auto-complete-mode t))
    (add-to-list 'ac-sources 'merlin-ac-source)))

(add-hook 'merlin-mode-hook 'merlin-ac--setup)
(when merlin-mode (merlin-ac--setup))

(provide 'merlin-ac)
;;; merlin-ac.el ends here