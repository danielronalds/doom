;;; github-dashboard.el --- Dashboard of open GitHub PRs and issues -*- lexical-binding: t; -*-

;; This file lives in $DOOMDIR and is loaded from config.el.  It depends only on
;; the `gh' CLI and has no third-party Emacs packages.

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'shr)

(defconst github-dashboard--buffer-name "*GitHub Dashboard*")

(defconst github-dashboard--query
  "query {
  prs: search(query: \"is:pr is:open author:@me archived:false\", type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        number title url bodyHTML isDraft reviewDecision mergeable updatedAt
        repository { nameWithOwner }
        commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
      }
    }
  }
  issues: search(query: \"is:issue is:open assignee:@me archived:false\", type: ISSUE, first: 100) {
    nodes {
      ... on Issue {
        number title url bodyHTML updatedAt
        repository { nameWithOwner }
        labels(first: 10) { nodes { name } }
      }
    }
  }
}"
  "GraphQL query for open PRs you authored and open issues assigned to you.")

(defvar github-dashboard--process nil
  "The in-flight `gh' process for the dashboard, if any.")

(defvar-local github-dashboard--data nil
  "The last decoded dashboard data, so the buffer can be redrawn without fetching.")

(defvar-local github-dashboard--expanded nil
  "URLs of the items whose descriptions are shown.")

;;; Fetching

(defun github-dashboard--fetch (callback)
  "Run the dashboard query asynchronously.
CALLBACK is called with (OK OUTPUT ERRORS) when the process exits."
  (when (process-live-p github-dashboard--process)
    (delete-process github-dashboard--process))
  (let* ((default-directory (expand-file-name "~/"))
         (out (generate-new-buffer " *github-dashboard-out*"))
         (err (generate-new-buffer " *github-dashboard-err*")))
    (setq github-dashboard--process
          (make-process
           :name "github-dashboard"
           :buffer out
           :stderr err
           :noquery t
           ;; A pty makes gh pretty-print and colour its output, which breaks
           ;; JSON parsing.
           :connection-type 'pipe
           :command (list "gh" "api" "graphql"
                          "-f" (concat "query=" github-dashboard--query))
           :sentinel
           (lambda (process _event)
             (unless (process-live-p process)
               (let ((ok (zerop (process-exit-status process)))
                     (output (with-current-buffer out (buffer-string)))
                     (errors (with-current-buffer err (string-trim (buffer-string)))))
                 (kill-buffer out)
                 (kill-buffer err)
                 (funcall callback ok output errors))))))))

;;; Parsing

(defun github-dashboard--nodes (search)
  "Return the non-empty nodes of the GraphQL SEARCH result."
  (delq nil (alist-get 'nodes search)))

(defun github-dashboard--parse-pr (node)
  "Convert a GraphQL PullRequest NODE into a plist."
  (let* ((commit-nodes (alist-get 'nodes (alist-get 'commits node)))
         (commit (alist-get 'commit (car commit-nodes)))
         (rollup (alist-get 'statusCheckRollup commit)))
    (list :number (alist-get 'number node)
          :title (alist-get 'title node)
          :url (alist-get 'url node)
          :html (alist-get 'bodyHTML node)
          :repo (alist-get 'nameWithOwner (alist-get 'repository node))
          :draft (alist-get 'isDraft node)
          :review (alist-get 'reviewDecision node)
          :checks (alist-get 'state rollup)
          :merge (alist-get 'mergeable node)
          :updated (date-to-time (alist-get 'updatedAt node)))))

(defun github-dashboard--parse-issue (node)
  "Convert a GraphQL Issue NODE into a plist."
  (list :number (alist-get 'number node)
        :title (alist-get 'title node)
        :url (alist-get 'url node)
        :html (alist-get 'bodyHTML node)
        :repo (alist-get 'nameWithOwner (alist-get 'repository node))
        :labels (mapcar (lambda (label) (alist-get 'name label))
                        (alist-get 'nodes (alist-get 'labels node)))
        :updated (date-to-time (alist-get 'updatedAt node))))

(defun github-dashboard--decode (output)
  "Parse the JSON OUTPUT of the dashboard query into a plist of PRs and issues."
  (let* ((json (json-parse-string output
                                  :object-type 'alist
                                  :array-type 'list
                                  :null-object nil
                                  :false-object nil))
         (data (alist-get 'data json)))
    (list :prs (mapcar #'github-dashboard--parse-pr
                       (github-dashboard--nodes (alist-get 'prs data)))
          :issues (mapcar #'github-dashboard--parse-issue
                          (github-dashboard--nodes (alist-get 'issues data))))))

;;; Formatting

(defun github-dashboard--ago (time)
  "Return a short relative description of TIME."
  (let ((seconds (floor (float-time (time-subtract (current-time) time)))))
    (cond ((< seconds 3600) (format "%dm ago" (max 0 (/ seconds 60))))
          ((< seconds 86400) (format "%dh ago" (/ seconds 3600)))
          ((< seconds (* 30 86400)) (format "%dd ago" (/ seconds 86400)))
          (t (format-time-string "%Y-%m-%d" time)))))

(defun github-dashboard--title (title draft)
  "Return TITLE truncated for display, prefixed when DRAFT is non-nil."
  (let ((text (truncate-string-to-width title 60 nil nil "...")))
    (if draft
        (concat (propertize "✎ " 'face 'font-lock-comment-face) text)
      text)))

(defun github-dashboard--review-cell (review)
  "Return a propertized cell for the PR review decision REVIEW."
  (pcase review
    ("APPROVED" (propertize "approved" 'face 'success))
    ("CHANGES_REQUESTED" (propertize "changes requested" 'face 'error))
    ("REVIEW_REQUIRED" (propertize "review required" 'face 'warning))
    (_ "-")))

(defun github-dashboard--checks-cell (state)
  "Return a propertized cell for the CI status STATE."
  (pcase state
    ("SUCCESS" (propertize "passing" 'face 'success))
    ((or "FAILURE" "ERROR") (propertize "failing" 'face 'error))
    ((or "PENDING" "EXPECTED") (propertize "pending" 'face 'warning))
    (_ "-")))

(defun github-dashboard--merge-cell (mergeable)
  "Return a propertized cell for the PR mergeable state MERGEABLE."
  (pcase mergeable
    ("MERGEABLE" "mergeable")
    ("CONFLICTING" (propertize "conflicts" 'face 'error))
    (_ "-")))

(defun github-dashboard--pr-row (pr)
  "Return a table row (URL . CELLS) for the PR plist PR."
  (cons (plist-get pr :url)
        (list (number-to-string (plist-get pr :number))
              (github-dashboard--title (plist-get pr :title) (plist-get pr :draft))
              (plist-get pr :repo)
              (github-dashboard--review-cell (plist-get pr :review))
              (github-dashboard--checks-cell (plist-get pr :checks))
              (github-dashboard--merge-cell (plist-get pr :merge))
              (github-dashboard--ago (plist-get pr :updated)))))

(defun github-dashboard--issue-row (issue)
  "Return a table row (URL . CELLS) for the issue plist ISSUE."
  (let ((labels (plist-get issue :labels)))
    (cons (plist-get issue :url)
          (list (number-to-string (plist-get issue :number))
                (github-dashboard--title (plist-get issue :title) nil)
                (plist-get issue :repo)
                (if labels (string-join labels ", ") "-")
                (github-dashboard--ago (plist-get issue :updated))))))

(defconst github-dashboard--pr-columns
  '(("ID" . font-lock-constant-face)
    ("Title" . nil)
    ("Repository" . font-lock-type-face)
    ("Review" . nil)
    ("Checks" . nil)
    ("Merge" . nil)
    ("Updated" . font-lock-comment-face))
  "Columns of the pull request table as (HEADER . FACE) pairs.")

(defconst github-dashboard--issue-columns
  '(("ID" . font-lock-constant-face)
    ("Title" . nil)
    ("Repository" . font-lock-type-face)
    ("Labels" . font-lock-builtin-face)
    ("Updated" . font-lock-comment-face))
  "Columns of the issue table as (HEADER . FACE) pairs.")

(defun github-dashboard--table (columns rows)
  "Return a list of lines forming a table for COLUMNS and ROWS.
COLUMNS is a list of (HEADER . FACE).  Each row is (URL . CELLS).  The first
line is the header.  Cells without their own face get the column face."
  (let* ((headers (mapcar #'car columns))
         (faces (mapcar #'cdr columns))
         (widths
          (cl-loop for index from 0
                   for header in headers
                   collect (cl-reduce
                            #'max
                            (mapcar (lambda (row) (string-width (nth index (cdr row))))
                                    rows)
                            :initial-value (string-width header))))
         (format-line
          (lambda (cells)
            (string-trim-right
             (mapconcat #'identity
                        (cl-mapcar (lambda (cell width) (string-pad cell width))
                                   cells widths)
                        "  "))))
         (style-cell
          (lambda (cell face)
            (if (or (null face) (zerop (length cell))
                    (get-text-property 0 'face cell))
                cell
              (propertize cell 'face face)))))
    ;; Each line is propertized as a whole so that point anywhere on the line
    ;; finds the URL.
    (cons (propertize (funcall format-line headers)
                      'face '(:inherit font-lock-comment-face :weight bold))
          (mapcar (lambda (row)
                    (propertize (funcall format-line
                                         (cl-mapcar style-cell (cdr row) faces))
                                'github-dashboard-url (car row)
                                'mouse-face 'highlight
                                'help-echo (car row)))
                  rows))))

;;; Rendering

(defun github-dashboard--rule ()
  "Return a horizontal rule for the dashboard."
  (concat (propertize (make-string 76 ?─) 'face 'font-lock-comment-face) "\n"))

(defconst github-dashboard--body-width 80
  "Column at which descriptions are wrapped, including their indent.")

(defun github-dashboard--wrap-buffer (width)
  "Wrap the lines of the current buffer to WIDTH columns.
Break at the last space that fits.  A word wider than WIDTH is broken
where it overflows.  Text properties are kept."
  (goto-char (point-min))
  (while (not (eobp))
    (end-of-line)
    (if (<= (current-column) width)
        (forward-line 1)
      (move-to-column width)
      (let ((space (save-excursion
                     (and (search-backward " " (line-beginning-position) t)
                          (point)))))
        (if space
            (progn (goto-char space) (delete-char 1))
          (goto-char (point)))
        (insert "\n")
        ;; The remainder starts where the break was made.
        (when (eq (char-after) ?\s)
          (delete-char 1))))))

(defun github-dashboard--html-to-string (html width)
  "Render the HTML fragment HTML with `shr', wrapped to WIDTH columns.
Return the result as a propertized string with surrounding blank lines trimmed."
  (let ((dom (with-temp-buffer
               (insert html)
               (libxml-parse-html-region (point-min) (point-max)))))
    (with-temp-buffer
      ;; `shr' fills by measuring the window, which gives one word per line
      ;; when the buffer is not displayed.  Render unfilled and wrap here.
      (let ((shr-width width)
            (shr-fill-text nil)
            (shr-inhibit-images t))
        (shr-insert-document dom)
        (github-dashboard--wrap-buffer width)
        (string-trim (buffer-string))))))

(defun github-dashboard--insert-body (url html)
  "Insert the rendered description HTML of the item at URL, indented under its row.
Lines are wrapped to `github-dashboard--body-width' including the indent."
  (let* ((indent "    ")
         (width (- github-dashboard--body-width (length indent)))
         (text (and html (not (string-empty-p html))
                    (github-dashboard--html-to-string html width))))
    ;; Blank line between the row and its description.
    (insert "\n")
    (if (or (null text) (string-empty-p text))
        (insert (propertize (concat indent "No description.")
                            'face 'font-lock-comment-face
                            'github-dashboard-url url)
                "\n")
      (dolist (line (split-string text "\n"))
        (let ((start (point)))
          (insert indent line "\n")
          ;; Add properties without replacing the faces `shr' applied.
          (add-text-properties start (point)
                               (list 'github-dashboard-url url
                                     'mouse-face 'highlight
                                     'help-echo url)))))
    (insert "\n")))

(defun github-dashboard--insert-section (title count section columns entries)
  "Insert a section named TITLE with COUNT items and a table of ENTRIES.
Each entry is (ROW . BODY), where ROW is (URL . CELLS).  SECTION is a symbol
tagging each row, either `prs' or `issues'.  Expanded items show BODY below
their row."
  (insert "\n"
          (propertize title 'face '(:inherit font-lock-keyword-face :weight bold))
          " "
          (propertize (format "(%d)" count) 'face 'font-lock-constant-face)
          "\n")
  (insert (github-dashboard--rule))
  (if (null entries)
      (insert (propertize "Nothing here" 'face 'font-lock-comment-face) "\n")
    (let ((lines (github-dashboard--table columns (mapcar #'car entries))))
      (insert (car lines) "\n")
      ;; Tag only the item rows, not the column header.
      (cl-loop for line in (cdr lines)
               for entry in entries
               do (let ((url (car (car entry))))
                    (insert (propertize line 'github-dashboard-section section) "\n")
                    (when (member url github-dashboard--expanded)
                      (github-dashboard--insert-body url (cdr entry))))))))

(defun github-dashboard--render (data)
  "Replace the buffer contents with the dashboard for DATA."
  (let* ((prs (plist-get data :prs))
         (issues (plist-get data :issues))
         (inhibit-read-only t))
    (erase-buffer)
    (insert "\n"
            (propertize "GitHub Dashboard"
                        'face '(:inherit font-lock-keyword-face
                                :weight bold :height 1.4))
            "\n")
    (insert (github-dashboard--rule))
    (insert (propertize "RET" 'face 'font-lock-keyword-face) " open   "
            (propertize "TAB" 'face 'font-lock-keyword-face) " expand   "
            (propertize "yy" 'face 'font-lock-keyword-face) " yank URL   "
            (propertize "q" 'face 'font-lock-keyword-face) " quit   "
            (propertize "r" 'face 'font-lock-keyword-face) " refresh   "
            (propertize (format "fetched %s" (format-time-string "%H:%M"))
                        'face 'font-lock-comment-face)
            "\n")
    (github-dashboard--insert-section
     "Pull Requests" (length prs) 'prs github-dashboard--pr-columns
     (mapcar (lambda (pr)
               (cons (github-dashboard--pr-row pr) (plist-get pr :html)))
             prs))
    (github-dashboard--insert-section
     "Issues" (length issues) 'issues github-dashboard--issue-columns
     (mapcar (lambda (issue)
               (cons (github-dashboard--issue-row issue) (plist-get issue :html)))
             issues))
    ;; Start on the first item so that j and k work immediately.
    (goto-char (point-min))
    (github-dashboard--move 1)))

(defun github-dashboard--render-message (message &optional face)
  "Replace the buffer contents with MESSAGE, shown in FACE."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert "\n" (propertize message 'face (or face 'font-lock-comment-face)) "\n")))

;;; Mode and commands

(defun github-dashboard--item-line-p ()
  "Return non-nil when the current line is a PR or issue row.
Description lines are not item rows, so j and k skip them."
  (get-text-property (line-beginning-position) 'github-dashboard-section))

(defun github-dashboard--move (direction)
  "Move to the nearest item in DIRECTION (1 forward, -1 backward).
Stay put when there is no item in that direction."
  (let ((origin (point))
        (moved t))
    (forward-line direction)
    (while (and moved (not (github-dashboard--item-line-p)))
      (setq moved (zerop (forward-line direction))))
    (if (github-dashboard--item-line-p)
        (beginning-of-line)
      (goto-char origin))))

(defun github-dashboard-next-item ()
  "Move to the next pull request or issue."
  (interactive)
  (github-dashboard--move 1))

(defun github-dashboard-previous-item ()
  "Move to the previous pull request or issue."
  (interactive)
  (github-dashboard--move -1))

(defun github-dashboard--move-items (direction count)
  "Move COUNT items in DIRECTION, stopping at the first or last item."
  (dotimes (_ count)
    (github-dashboard--move direction)))

(defun github-dashboard-jump-up ()
  "Move five items up, or to the first item if fewer remain."
  (interactive)
  (github-dashboard--move-items -1 5))

(defun github-dashboard-jump-down ()
  "Move five items down, or to the last item if fewer remain."
  (interactive)
  (github-dashboard--move-items 1 5))

(defun github-dashboard-toggle-expand ()
  "Show or hide the description of the pull request or issue on this line."
  (interactive)
  (let ((url (get-text-property (line-beginning-position) 'github-dashboard-url)))
    (unless url
      (user-error "No pull request or issue on this line"))
    (setq github-dashboard--expanded
          (if (member url github-dashboard--expanded)
              (remove url github-dashboard--expanded)
            (cons url github-dashboard--expanded)))
    (github-dashboard--render github-dashboard--data)
    ;; Keep point on the item that was toggled.
    (let ((target (text-property-any (point-min) (point-max)
                                     'github-dashboard-url url)))
      (when target
        (goto-char target)
        (beginning-of-line)))))

(defvar-keymap github-dashboard-mode-map
  :parent special-mode-map
  "RET" #'github-dashboard-open
  "j" #'github-dashboard-next-item
  "k" #'github-dashboard-previous-item
  "C-u" #'github-dashboard-jump-up
  "C-d" #'github-dashboard-jump-down
  "TAB" #'github-dashboard-toggle-expand
  "r" #'github-dashboard-refresh)

(define-key github-dashboard-mode-map (kbd "yy") #'github-dashboard-yank-url)

(define-derived-mode github-dashboard-mode special-mode "GitHub Dashboard"
  "Major mode for the GitHub dashboard."
  ;; Match the Doom dashboard: no line numbers, but keep the mode line.
  (setq-local display-line-numbers nil)
  (hl-line-mode 1))

(declare-function evil-set-initial-state "evil-core")
(declare-function evil-define-key "evil-core")
(with-eval-after-load 'evil
  (evil-set-initial-state 'github-dashboard-mode 'motion)
  ;; Evil binds RET to `evil-ret' in motion state, which moves down a line.
  ;; Evil binds these keys in motion state, which would shadow the mode map.
  (evil-define-key '(normal motion) github-dashboard-mode-map
    (kbd "RET") #'github-dashboard-open
    "j" #'github-dashboard-next-item
    "k" #'github-dashboard-previous-item
    (kbd "C-u") #'github-dashboard-jump-up
    (kbd "C-d") #'github-dashboard-jump-down
    (kbd "TAB") #'github-dashboard-toggle-expand
    (kbd "yy") #'github-dashboard-yank-url
    "r" #'github-dashboard-refresh))

(defun github-dashboard-yank-url ()
  "Copy the pull request or issue URL on the current line to the clipboard."
  (interactive)
  (let ((url (get-text-property (line-beginning-position) 'github-dashboard-url)))
    (unless url
      (user-error "No pull request or issue on this line"))
    (kill-new url)
    ;; `kill-new' may only update the kill ring when clipboard integration is
    ;; disabled; set the CLIPBOARD selection explicitly as well.
    (gui-set-selection 'CLIPBOARD url)
    (message "Copied %s" url)))

(defun github-dashboard-open ()
  "Open the pull request or issue on the current line in a browser."
  (interactive)
  (let ((url (get-text-property (line-beginning-position) 'github-dashboard-url)))
    (unless url
      (user-error "No pull request or issue on this line"))
    (browse-url url)))

(defun github-dashboard--load (buffer)
  "Fetch the latest data and render it into the dashboard BUFFER."
  (unless (executable-find "gh")
    (user-error "The gh CLI is not installed"))
  (with-current-buffer buffer
    (github-dashboard--render-message "Loading..."))
  (github-dashboard--fetch
   (lambda (ok output errors)
     (when (buffer-live-p buffer)
       (with-current-buffer buffer
         (if (not ok)
             (github-dashboard--render-message
              (concat "Failed to fetch from GitHub:\n" errors)
              'error)
           (condition-case err
               (let ((data (github-dashboard--decode output)))
                 (setq github-dashboard--data data)
                 (github-dashboard--render data))
             (error
              (github-dashboard--render-message
               (format "Failed to read GitHub response: %s"
                       (error-message-string err))
               'error)))))))))

(defun github-dashboard-refresh ()
  "Fetch the latest pull requests and issues."
  (interactive)
  (github-dashboard--load (current-buffer)))

(defun github/dashboard ()
  "Show a dashboard of your open GitHub pull requests and assigned issues.
Data is fetched with the `gh' CLI each time this command runs."
  (interactive)
  (let ((buffer (get-buffer-create github-dashboard--buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'github-dashboard-mode)
        (github-dashboard-mode)))
    ;; Start the fetch before switching, so a missing gh fails without
    ;; changing the current window.
    (github-dashboard--load buffer)
    ;; Take over the current window, as the Doom dashboard does.
    (switch-to-buffer buffer)))

(provide 'github-dashboard)
;;; github-dashboard.el ends here
