;;; private/agent-shell/doctor.el -*- lexical-binding: t; -*-

(unless (or (modulep! +pi) (modulep! +claude))
  (warn! "Enable at least one agent-shell backend: +pi or +claude"))

(when (modulep! +pi)
  (unless (executable-find "pi")
    (warn! "Couldn't find pi. Install with: npm install -g @earendil-works/pi-coding-agent"))
  (unless (executable-find "pi-acp")
    (warn! "Couldn't find pi-acp. Install with: npm install -g pi-acp")))

(when (modulep! +claude)
  (unless (executable-find "claude-agent-acp")
    (warn! "Couldn't find claude-agent-acp. Install with: npm install -g @agentclientprotocol/claude-agent-acp"))
  (unless (executable-find "claude")
    (warn! "Claude subscription authentication requires Claude Code; install it and run claude to sign in")))
