;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;;   ___  ____________ _____  ___  ______  ___   _   _ _____  _____
;;  / _ \ | ___ \ ___ \  ___|/ _ \ | ___ \/ _ \ | \ | /  __ \|  ___|
;; / /_\ \| |_/ / |_/ / |__ / /_\ \| |_/ / /_\ \|  \| | /  \/| |__
;; |  _  ||  __/|  __/|  __||  _  ||    /|  _  || . ` | |    |  __|
;; | | | || |   | |   | |___| | | || |\ \| | | || |\  | \__/\| |___
;; \_| |_/\_|   \_|   \____/\_| |_/\_| \_\_| |_/\_| \_/\____/\____/

;;(setq doom-theme 'doom-one)
;;(setq doom-theme 'doom-tokyo-night)
(setq doom-theme 'catppuccin)
(setq catppuccin-flavor 'frappe)

(setq display-line-numbers-type 'relative)

(setq scroll-margin 10)

;; ____________ _____ _____ ______  ___  ___  ______  ________ _   _ _____
;; | ___ \ ___ \  _  |  __ \| ___ \/ _ \ |  \/  ||  \/  |_   _| \ | |  __ \
;; | |_/ / |_/ / | | | |  \/| |_/ / /_\ \| .  . || .  . | | | |  \| | |  \/
;; |  __/|    /| | | | | __ |    /|  _  || |\/| || |\/| | | | | . ` | | __
;; | |   | |\ \\ \_/ / |_\ \| |\ \| | | || |  | || |  | |_| |_| |\  | |_\ \
;; \_|   \_| \_|\___/ \____/\_| \_\_| |_/\_|  |_/\_|  |_/\___/\_| \_/\____/

;; Reuse the language servers installed by Neovim's Mason rather than installing
;; a second copy for Emacs. Prepending this directory makes its executables
;; available to Eglot and Doom's language modules.
(let ((mason-bin (expand-file-name "~/.local/share/nvim/mason/bin")))
  (when (file-directory-p mason-bin)
    (add-to-list 'exec-path mason-bin)
    (unless (member mason-bin (split-string (or (getenv "PATH") "")
                                            path-separator t))
      (setenv "PATH" (concat mason-bin path-separator (getenv "PATH"))))))

(use-package! templ-ts-mode
  :mode "\\.templ\\'"
  :hook (templ-ts-mode . eglot-ensure))

;; Use Zsh for interactive and subprocess shells.
(setq shell-file-name (executable-find "zsh")
      explicit-shell-file-name shell-file-name)
(setenv "SHELL" shell-file-name)

;;  _____ _____ _____
;; |  __ \_   _|_   _|
;; | |  \/ | |   | |
;; | | __  | |   | |
;; | |_\ \_| |_  | |
;;  \____/\___/  \_/

(load! "github-dashboard")

(after! magit
  (magit-add-section-hook 'magit-status-sections-hook
                          #'magit-insert-worktrees
                          nil t))

;;  _   _   ___  _   _ _____ _____   ___ _____ _____ _____ _   _
;; | \ | | / _ \| | | |_   _|  __ \ / _ \_   _|_   _|  _  | \ | |
;; |  \| |/ /_\ \ | | | | | | |  \// /_\ \| |   | | | | | |  \| |
;; | . ` ||  _  | | | | | | | | __ |  _  || |   | | | | | | . ` |
;; | |\  || | | \ \_/ /_| |_| |_\ \| | | || |  _| |_\ \_/ / |\  |
;; \_| \_/\_| |_/\___/ \___/ \____/\_| |_/\_/  \___/ \___/\_| \_/

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

;; Send the current file (and, when active, its line range) to an AI agent
;; already running in a Ghostel or other Emacs terminal buffer.
(load! "reference")
(map! :leader
      :desc "Send file reference to AI agent" "c c" #'reference-send)

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
  (let ((private-feeds (expand-file-name "elfeed-feeds.el" doom-private-dir)))
    (when (file-exists-p private-feeds)
      (load private-feeds))))

;; ___  ________ _____ _____
;; |  \/  |_   _/  ___/  __ \
;; | .  . | | | \ `--.| /  \/
;; | |\/| | | |  `--. \ |
;; | |  | |_| |_/\__/ / \__/\
;; \_|  |_/\___/\____/ \____/

(setq user-full-name "Daniel Ronalds"
      user-mail-address "nzdanron@gmail.com")
