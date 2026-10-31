;;; reference.el --- Send file references to AI agents in Emacs terminals -*- lexical-binding: t; -*-

;; This file lives in $DOOMDIR so the integration travels with the rest of the
;; Doom configuration.  It intentionally has no third-party dependencies.

(require 'cl-lib)
(require 'project)
(require 'subr-x)

(defgroup reference nil
  "Send file references to AI agents running in Emacs terminals."
  :group 'tools)

(defcustom reference-agent-process-names '("claude" "opencode" "pi")
  "Process names used to identify AI agents."
  :type '(repeat string)
  :group 'reference)

(defun reference--terminal-kind ()
  "Return the terminal kind of the current buffer, or nil."
  (cond ((derived-mode-p 'ghostel-mode) 'ghostel)
        ((derived-mode-p 'vterm-mode) 'vterm)
        ((derived-mode-p 'eat-mode) 'eat)
        ((derived-mode-p 'term-mode) 'term)
        ((derived-mode-p 'comint-mode) 'comint)))

(defun reference--terminal-pid ()
  "Return the operating-system PID for the current terminal buffer."
  (let ((pid
         (cond
          ;; Ghostel's lifecycle process can be an event pipe when its native
          ;; PTY is enabled; `ghostel--pid' is the actual shell PID.
          ((and (eq (reference--terminal-kind) 'ghostel)
                (boundp 'ghostel--pid))
           ghostel--pid)
          ((get-buffer-process (current-buffer))
           (process-id (get-buffer-process (current-buffer)))))))
    (and (integerp pid) (> pid 0) pid)))

(defun reference--live-terminal-p ()
  "Return non-nil when the current buffer is a usable terminal."
  (and (reference--terminal-kind)
       (reference--terminal-pid)
       (let ((process (get-buffer-process (current-buffer))))
         (or (null process) (process-live-p process)))))

(defun reference--processes ()
  "Return local processes as (PID PPID COMMAND ARGS) lists."
  (when (executable-find "ps")
    (condition-case nil
        (mapcar
         (lambda (line)
           (when (string-match
                  "^[[:space:]]*\\([0-9]+\\)[[:space:]]+\\([0-9]+\\)[[:space:]]+\\([^[:space:]]+\\)[[:space:]]*\\(.*\\)$"
                  line)
             (list (string-to-number (match-string 1 line))
                   (string-to-number (match-string 2 line))
                   (match-string 3 line)
                   (match-string 4 line))))
         (process-lines "ps" "-eo" "pid=,ppid=,comm=,args="))
      (error nil))))

(defun reference--descendant-pids (root processes)
  "Return ROOT and all of its descendants found in PROCESSES."
  (let ((seen (list root))
        (pending (list root)))
    (while pending
      (let ((parent (pop pending)))
        (dolist (process processes)
          (let ((pid (nth 0 process))
                (ppid (nth 1 process)))
            (when (and (= ppid parent) (not (memq pid seen)))
              (push pid seen)
              (push pid pending))))))
    seen))

(defun reference--agent-name (process)
  "Return the configured agent name matched by PROCESS, or nil."
  (let ((command (file-name-nondirectory (nth 2 process)))
        (arguments (nth 3 process)))
    (cl-find-if
     (lambda (name)
       (or (string= command name)
           ;; This finds agents launched through wrappers such as Node, while
           ;; avoiding accidental partial matches like "compile" for "pi".
           (string-match-p
            (format "\\(?:\\`\\|[^[:alnum:]_]\\)%s\\(?:\\'\\|[^[:alnum:]_]\\)"
                    (regexp-quote name))
            arguments)))
     reference-agent-process-names)))

(defun reference--agents ()
  "Discover AI agents running in local Emacs terminal buffers."
  (let ((processes (delq nil (reference--processes)))
        agents)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        (when (reference--live-terminal-p)
          (let ((descendants
                 (reference--descendant-pids
                  (reference--terminal-pid) processes)))
            (cl-loop for process in processes
                     for pid = (nth 0 process)
                     for name = (and (memq pid descendants)
                                     (reference--agent-name process))
                     when name
                     do (push (list :buffer buffer
                                    :agent name
                                    :pid pid
                                    :kind (reference--terminal-kind))
                              agents)
                     and return t)))))
    (nreverse agents)))

(defun reference--project-root ()
  "Return the current file's project root, if it has one."
  (when-let* ((project (project-current nil
                                        (and buffer-file-name
                                             (file-name-directory
                                              buffer-file-name)))))
    (expand-file-name (project-root project))))

(defun reference--path ()
  "Return a portable path for the current buffer's file."
  (unless buffer-file-name
    (user-error "The current buffer is not visiting a file"))
  (let* ((file (expand-file-name buffer-file-name))
         (root (reference--project-root)))
    (if (and root (file-in-directory-p file root))
        (file-relative-name file root)
      (abbreviate-file-name file))))

(defun reference--region-lines ()
  "Return the inclusive line range of the active region, or nil."
  (when (use-region-p)
    (let* ((start (region-beginning))
           (end (region-end))
           ;; A region ending at column zero does not include that line.
           (inclusive-end (if (and (> end start)
                                   (= end (reference--line-beginning-at end)))
                              (1- end)
                            end)))
      (cons (line-number-at-pos start t)
            (line-number-at-pos inclusive-end t)))))

(defun reference--line-beginning-at (position)
  "Return the beginning of the line containing POSITION."
  (save-excursion
    (goto-char position)
    (line-beginning-position)))

(defun reference--text ()
  "Build an agent file reference for the current buffer and region."
  (let ((path (reference--path))
        (lines (reference--region-lines)))
    (if lines
        (format "@%s#L%d-%d" path (car lines) (cdr lines))
      (format "@%s" path))))

(defun reference--send (buffer text)
  "Send TEXT as a bracketed paste to terminal BUFFER."
  (with-current-buffer buffer
    (pcase (reference--terminal-kind)
      ('ghostel
       (unless (fboundp 'ghostel-paste-string)
         (user-error "Ghostel's paste function is unavailable"))
       (ghostel-paste-string text))
      ('vterm
       (unless (fboundp 'vterm-send-string)
         (user-error "vterm's send function is unavailable"))
       (vterm-send-string text t))
      ('eat
       (unless (and (fboundp 'eat-term-send-string)
                    (boundp 'eat--terminal))
         (user-error "Eat's send function is unavailable"))
       (eat-term-send-string eat--terminal text))
      ('term
       (term-send-raw-string text))
      ('comint
       (comint-send-string (get-buffer-process buffer) text))
      (_ (user-error "Buffer %s is not a supported terminal"
                     (buffer-name buffer))))))

(defun reference--choose-agent (agents)
  "Return one agent from AGENTS, prompting when necessary."
  (if (= (length agents) 1)
      (car agents)
    (let* ((choices
            (mapcar
             (lambda (agent)
               (cons (format "%s — %s (%s, pid %d)"
                             (plist-get agent :agent)
                             (buffer-name (plist-get agent :buffer))
                             (plist-get agent :kind)
                             (plist-get agent :pid))
                     agent))
             agents))
           (choice (completing-read "Send reference to: " choices nil t)))
      (cdr (assoc choice choices)))))

;;;###autoload
(defun reference-send ()
  "Send the current file reference to an AI agent in an Emacs terminal.

With an active region, include its inclusive line range.  When several agents
are running, prompt for the destination; when exactly one is running, use it
directly.  The reference is pasted but not submitted."
  (interactive)
  (let* ((text (reference--text))
         (agents (reference--agents)))
    (unless agents
      (user-error "No claude, opencode, or pi process found in an Emacs terminal"))
    (let* ((agent (reference--choose-agent agents))
           (buffer (plist-get agent :buffer)))
      (reference--send buffer text)
      (message "Sent %s to %s in %s"
               text (plist-get agent :agent) (buffer-name buffer)))))

(provide 'reference)
;;; reference.el ends here
