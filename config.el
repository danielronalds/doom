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

(setq projectile-project-search-path '(("~/") ("~/.config") ("~/Projects/" . 2)))

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

;; Keep a short list of important files for each Projectile project and Git
;; branch. Direct slots mirror the bindings in the Neovim configuration.
(use-package! harpoon
  :commands (harpoon-add-file
             harpoon-clear
             harpoon-go-to-1
             harpoon-go-to-2
             harpoon-go-to-3
             harpoon-go-to-4
             harpoon-go-to-5
             harpoon-go-to-next
             harpoon-go-to-prev
             harpoon-quick-menu-hydra
             harpoon-toggle-file)
  :init
  (setq harpoon-project-package 'projectile
        harpoon-separate-by-branch t)
  (map! :leader
        :desc "Harpoon file 1" "1" #'harpoon-go-to-1
        :desc "Harpoon file 2" "2" #'harpoon-go-to-2
        :desc "Harpoon file 3" "3" #'harpoon-go-to-3
        :desc "Harpoon file 4" "4" #'harpoon-go-to-4
        :desc "Harpoon file 5" "5" #'harpoon-go-to-5
        (:prefix ("j" . "jump")
         :desc "Add file to Harpoon" "a" #'harpoon-add-file
         :desc "Harpoon menu" "m" #'harpoon-quick-menu-hydra
         :desc "Edit Harpoon list" "f" #'harpoon-toggle-file
         :desc "Clear Harpoon list" "c" #'harpoon-clear
         :desc "Next Harpoon file" "n" #'harpoon-go-to-next
         :desc "Previous Harpoon file" "p" #'harpoon-go-to-prev)))

;;  _____                 ___  ___          _
;; |  _  |                |  \/  |         | |
;; | | | |_ __ __ _ ______| .  . | ___   __| | ___
;; | | | | '__/ _` |______| |\/| |/ _ \ / _` |/ _ \
;; \ \_/ / | | (_| |      | |  | | (_) | (_| |  __/
;;  \___/|_|  \__, |      \_|  |_/\___/ \__,_|\___|
;;             __/ |
;;            |___/

(setq org-directory "~/org/")

(use-package! org-superstar
  :after org
  :hook (org-mode . org-superstar-mode))

;; Doom lazy-loads Babel backends by source block language.  Map Zsh blocks to
;; ob-shell, which provides `org-babel-execute:zsh'.
(after! org
  (add-to-list '+org-babel-mode-alist '(zsh . shell)))

;; ______  _____ _____
;; | ___ \/  ___/  ___|
;; | |_/ /\ `--.\ `--.
;; |    /  `--. \`--. \
;; | |\ \ /\__/ /\__/ /
;; \_| \_|\____/\____/

(after! elfeed
  (let ((private-feeds (expand-file-name "elfeed-private.el" doom-private-dir)))
    (when (file-exists-p private-feeds)
      (load private-feeds))))
