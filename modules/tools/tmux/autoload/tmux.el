;;; tools/tmux/autoload/tmux.el

;; This library offers:
;;   + A way of communicating with a tmux instance
;;   + TODO A way to manage tmuxifier from emacs

(defvar +tmux-last-command nil
  "The last command ran by `+tmux'. Used by `+tmux/rerun'")

(defvar +tmux-last-retcode nil
  "The last tmux return code.")


;;
;; Commands
;;

;;;###autoload
(defun +tmux (command &rest args)
  "Execute COMMAND in tmux"
  (let ((bin (executable-find "tmux")))
    (unless bin
      (error "Could not find tmux executable"))
    (let* ((args (mapcar #'shell-quote-argument (delq nil args)))
           (cmdstr (format "%s %s" bin (if args (apply #'format command args) command)))
           (output (get-buffer-create " *tmux stdout*"))
           (errors (get-buffer-create " *tmux stderr*"))
           code)
      (unwind-protect
          (if (= 0 (setq code (quiet! (shell-command cmdstr output errors))))
              (with-current-buffer output
                (setq +tmux-last-command `(,cmdstr ,@args))
                (buffer-string))
            (error "[%d] tmux $ %s (%s)"
                   code
                   (with-current-buffer errors
                     (buffer-string))
                   cmdstr))
        (and (kill-buffer output)
             (kill-buffer errors))))))

;;;###autoload
(defun +tmux/run (command &optional noreturn)
  "Run COMMAND in tmux. If NORETURN is non-nil, send the commands as keypresses
but do not execute them."
  (interactive
   (list (read-string "tmux $ ")
         current-prefix-arg))
  (+tmux (concat "send-keys C-u "
                 (shell-quote-argument command)
                 (unless noreturn " Enter"))))

;;;###autoload
(defun +tmux/send-region (beg end &optional noreturn)
  "Send region to tmux."
  (interactive "rP")
  (+tmux/run (string-trim (buffer-substring-no-properties beg end))
             noreturn))

;;;###autoload
(defun +tmux/rerun ()
  "Rerun the last command executed by `+tmux' and `+tmux/run'."
  (interactive "P")
  (unless +tmux-last-command
    (user-error "No last command to run"))
  (apply #'+tmux (car +tmux-last-command) (cdr +tmux-last-command)))

;;;###autoload
(defun +tmux/cd (&optional directory)
  "Change the pwd of the currently active tmux pane to DIRECTORY (defaults to
`default-directory', or to `doom-project-root' with the universal argument)."
  (interactive
   (list
    (when current-prefix-arg
      (read-directory-name
       "cd: " nil
       (if current-prefix-arg (doom-project-root) default-directory) t))))
  (+tmux "cd %s" (or directory default-directory)))

;;;###autoload
(defun +tmux/cd-to-here ()
  "cd into `default-directory' in tmux."
  (interactive)
  (+tmux/cd default-directory))

;;;###autoload
(defun +tmux/cd-to-project ()
  "cd into `doom-project-root' in tmux."
  (interactive)
  (+tmux/cd (doom-project-root)))


;;
;; Data functions
;;

;;;###autoload
(defun +tmux-list-sessions ()
  (let ((lines (+tmux "list-sessions -F '#{session_id};#{session_name};#{session_attached}'")))
    (if lines
        (mapcar (lambda (it)
                  (let ((sess (split-string it ";")))
                    (list (nth 0 sess) :name (nth 1 sess) :attached (equal (nth 2 sess) "1"))))
                (split-string lines "\n" t))
      (error "There are no sessions"))))

;;;###autoload
(defun +tmux-list-windows (&optional session)
  (let* ((flags
          (if session
              (concat "-t " (car session))
            "-a"))
         (lines
          (+tmux (format "list-windows %s -F '#{window_id};#{session_id};#{window_active};#{window_name};#{window_activity_flag}'"
                         flags))))
    (if lines
        (mapcar (lambda (it)
                  (let ((window (string-split it ";")))
                    (list (nth 0 window)
                          :session-id (nth 1 window)
                          :name (nth 3 window)
                          :active (equal (nth 2 window) "1")
                          :activity (equal (nth 4 window) "1"))))
                (string-split lines "\n" t))
      (error "There are no windows"))))

;;;###autoload
(defun +tmux-list-panes (&optional sess-or-win)
  (let* ((flags (if sess-or-win
                    (concat (if (string-prefix-p "$" (car sess-or-win)) "-s ") "-t " (car sess-or-win))
                  "-a"))
         (lines (+tmux (format "list-panes %s -F '#{pane_id};#{window_id};#{session_id};#{pane_active};#{pane_title};#{pane_current_path}'"
                               flags))))
    (if lines
        (mapcar (lambda (it)
                  (let ((pane (s-split it ";")))
                    (list (nth 0 pane)
                          :window-id (nth 1 pane)
                          :session-id (nth 2 pane)
                          :name (nth 4 pane)
                          :active (equal (nth 3 pane) "1")
                          :pwd (nth 5 pane))))
                (string-split lines "\n" t))
      (error "There are no panes"))))

