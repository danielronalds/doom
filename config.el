;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; Reuse the language servers installed by Neovim's Mason rather than installing
;; a second copy for Emacs. Prepending this directory makes its executables
;; available to Eglot and Doom's language modules.
(let ((mason-bin (expand-file-name "~/.local/share/nvim/mason/bin")))
  (when (file-directory-p mason-bin)
    (add-to-list 'exec-path mason-bin)
    (unless (member mason-bin (split-string (or (getenv "PATH") "")
                                            path-separator t))
      (setenv "PATH" (concat mason-bin path-separator (getenv "PATH"))))))

;; Use Zsh for interactive and subprocess shells.
(setq shell-file-name (executable-find "zsh")
      explicit-shell-file-name shell-file-name)
(setenv "SHELL" shell-file-name)

;; Doom lazy-loads Babel backends by source block language.  Map Zsh blocks to
;; ob-shell, which provides `org-babel-execute:zsh'.
(after! org
  (add-to-list '+org-babel-mode-alist '(zsh . shell)))


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Daniel Ronalds"
      user-mail-address "nzdanron@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;;(setq doom-theme 'doom-one)
(setq doom-theme 'doom-tokyo-night)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

(setq projectile-project-search-path '(("~/.config") ("~/Projects/" . 2)))

;; Open the current buffer's directory in Dired, reusing this window.
(map! :n "-" #'dired-jump)

(defun danielr/dired-vsplit ()
  "Open Dired in a new split to the right."
  (interactive)
  (select-window (split-window-right))
  (dired-jump))

(defun danielr/dired-hsplit ()
  "Open Dired in a new split below."
  (interactive)
  (select-window (split-window-below))
  (dired-jump))

(map! :leader
      :desc "Open Dired vertical split" "s v" #'danielr/dired-vsplit
      :desc "Open Dired horizontal split" "s h" #'danielr/dired-hsplit)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; `templ' has no dedicated Doom module. Use its tree-sitter mode and language
;; server alongside the Go module.
(use-package! templ-ts-mode
  :mode "\\.templ\\'"
  :hook (templ-ts-mode . eglot-ensure))

(setq scroll-margin 10)

;; Send the current file (and, when active, its line range) to an AI agent
;; already running in a Ghostel or other Emacs terminal buffer.
(load! "reference")
(map! :leader
      :desc "Send file reference to AI agent" "c c" #'reference-send)


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
