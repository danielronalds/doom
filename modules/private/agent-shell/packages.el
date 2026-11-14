;;; private/agent-shell/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

(package! shell-maker)
(package! acp)
;; Use upstream so the Pi backend is available, even with older MELPA recipes.
(package! agent-shell
  :recipe (:host github :repo "xenodium/agent-shell" :branch "main"))
