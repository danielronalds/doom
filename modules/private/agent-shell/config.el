;;; private/agent-shell/config.el -*- lexical-binding: t; -*-

(use-package! agent-shell
  :commands (agent-shell agent-shell-send-region agent-shell-toggle)
  :init
  (when (modulep! +pi)
    (autoload 'agent-shell-pi-start-agent "agent-shell" nil t))
  (when (modulep! +claude)
    (autoload 'agent-shell-anthropic-start-claude-code "agent-shell" nil t))
  ;; Declare the labelled prefix only once: repeating it replaces its keymap.
  (map! :leader
        (:prefix ("a" . "agents")
         :desc "Agent shell" "a" #'agent-shell
         :desc "Send selection to agent" "s" #'agent-shell-send-region
         :desc "Toggle agent pane" "t" #'agent-shell-toggle
         (:when (modulep! +pi)
          :desc "Pi agent shell" "p" #'agent-shell-pi-start-agent)
         (:when (modulep! +claude)
          :desc "Claude agent shell" "c" #'agent-shell-anthropic-start-claude-code)))
  :config
  ;; Show cumulative session cost when the ACP backend reports it.
  (setq agent-shell-show-cost-indicator t)
  ;; Collapse tool details; show only the current activity group's members.
  (setq agent-shell-tool-use-expand-by-default nil
        agent-shell-activity-group-expand-by-default 'latest)
  (setq agent-shell-display-action
        '((display-buffer-in-side-window)
          (side . right)
          (slot . 0)
          (window-width . 0.4)))
  ;; Offer only the backends enabled by this module's flags.
  ;; Keep makers rather than concrete configs so changes take effect on startup.
  (setq agent-shell-agent-configs
        (append
         (when (modulep! +pi)
           (list #'agent-shell-pi-make-agent-config))
         (when (modulep! +claude)
           (list #'agent-shell-anthropic-make-claude-code-config)))))
