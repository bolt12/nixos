;;; init  --- The main emacs init file  -*- lexical-binding: t; -*-

;;; https://github.com/TOTBWF/agda-evil-emacs/blob/main/init.el

;;; Commentary:
;; This Emacs configuration file is meant to get vim users
;; off the ground using Emacs, Evil Mode, and Agda.

;; To install, simply place this file in `~/.emacs.d/init.el'.
;;
;; Keybindings:
;; When you are in insert mode, things behave more or less the same as vim.
;; When you are in normal mode, you can hit the 'SPC' key to get
;; access to the main key menu.  If you wait a second, you can see all
;; the possible options available to you.

;;; Code:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package Management

;; We use `straight.el' (https://github.com/raxod502/straight.el) for package management.
;; To get that set up, we need to do a bit of bootstrapping.
;; Don't worry if you don't understand this!
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(require 'straight)

;; Next, let's load up `use-package' (https://github.com/jwiegley/use-package), which
;; provides a really handy macro for package configuration. So `straight.el' is
;; what we use to actually download packages and manage versions, and `use-package'
;; is what we use to configure them, and manage how they get loaded.

(straight-use-package 'use-package)
(require 'use-package)

;; By default, the GC threshold for Emacs is 800Kib, which means we will trigger
;; GC when we initialize, which can really slow down load times!
;; To avoid this, let's bump it up to 10Mib.
(setq gc-cons-threshold 10000000)

;; However, we don't want the GC threshold to be this high when we are using
;; Emacs, so let's set it to something a bit lower once we've initialized everything.
(add-hook 'after-init-hook
          (lambda ()
            (setq gc-cons-threshold 1000000)))

;; Enable smooth, line by line scrolling
(setq scroll-conservatively 101)
(setq mouse-wheel-scroll-amount '(1))
(setq mouse-wheel-progressive-speed nil)
(setq auto-window-vscroll nil)
(setq indent-tabs-mode nil)
;; Make backspace properly erase as many spaces as a tab
(setq backward-delete-char-untabify-method 'hungry)

;; Don't show startup screen
(setq inhibit-startup-screen t)

(use-package linum-relative
  :straight t
  :custom
  ;; use relative numbers everywhere
  (linum-relative-global-mode t)

  ;; Make linum show the actual line on the current line
  (linum-relative-current-symbol ""))

(linum-relative-toggle)
;; line numbers everywhere
(global-linum-mode t)

;; Show the column number on my powerline
(column-number-mode 1)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; User Interface

;; By default, Emacs has some really, really ugly window decorations.
;; Let's disable those!
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)

;; Let's keep our auto-save data in a different folder, as opposed to directly
;; alongside the files.
(setq auto-save-file-name-transforms `((".*" ,temporary-file-directory t))
      backup-by-copying t
      backup-directory-alist '((".*" . "~/.emacs-tmp"))
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t)

;; Disable the bell ring, which gets really obnoxious really fast.
(setq ring-bell-function 'ignore)

;; Make "yes or no" prompts use "y" and "n" instead
(defalias 'yes-or-no-p 'y-or-n-p)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Path Management

;; The PATH variable can be a little wonky in GUI Emacs, so
;; let's define a little helper function that helps solve some issues.

(defun add-to-path (path)
  "Add PATH to the variable `exec-path' and update $PATH.
This is used in place of `exec-path-from-shell' to avoid having
to start up a shell process, and is also more consistent."
  (let ((expanded-path (expand-file-name path)))
    (add-to-list 'exec-path expanded-path)
    (setenv "PATH" (concat expanded-path ":" (getenv "PATH")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Evil Mode + Keybinding

;; First, let's load up `evil', which provides a vim-like experience inside of
;; Emacs! This also serves as an introduction on how we do package management.

(use-package evil
  ;; Inform `use-package' that we want to install this package via `straight.el'
  :straight t
  ;; Code in the `:init' section gets run /before/
  ;; the package loads.
  :init
  ;; `setq' is used to set variables.
  ;; Here, we are configuring some `evil' preferences to ensure that
  ;; it behaves how we want.
  ;; If you are ever curious about what a variable means, you can
  ;; use put your cursor over a variable and hit 'C-h v' to see the
  ;; variable's documentation inside emacs!
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  ;; Code in the `:config' section gets run /after/
  ;; the package loads.
  :config
  ;; Here, we just want to enable `evil-mode' once we've finished loading
  ;; it.
  (evil-mode 1))

;; We install the `which-key' (https://github.com/justbur/emacs-which-key) so that we
;; can see what keybindings we have available. This is super useful for discovery!
(use-package which-key
  :straight t
  :config
  (which-key-mode 1))

;; Next, we are going to install `general.el' (https://github.com/noctuid/general.el),
;; which provides a nicer interface for binding fancy key sequences like we will.
;; We will specifically use the doom/spacemacs style of keybindings, where we use
;; the 'SPC' key as our leader key.
(use-package general
  :straight t
  :config
  (general-evil-setup)
  (general-auto-unbind-keys))

;; We have to load this file after `general' itself loads to make
;; sure that we have loaded some macros we need in the next bit.
(require 'general)

;; `general' has a concept of a "definer", which can be a bit complicated
;; to understand. For now, you can ignore this code, and just use the API
;; we set up.
(general-create-definer global-definer
  :keymaps 'override
  :states '(insert emacs normal hybrid motion visual operator)
  :prefix "SPC"
  :non-normal-prefix "C-SPC")

(global-definer
  "SPC" '(execute-extended-command :wk "execute command"))

(general-create-definer global-motion-definer
  :keymaps 'override
  :states '(normal motion visual operator)
  :prefix "g")

(general-create-definer mode-leader-definer
  :states '(normal motion)
  :wrapping global-definer
  :prefix "SPC m"
  "" '(:ignore t :which-key "mode"))

;; Now that we've got that set up, let's bind some keys!
;; First, let's set up some key bindings for opening files.
(general-create-definer file-menu-definer
  :wrapping global-definer
  ;; This means that all the key bindings we define using this "definer"
  ;; will be prefixed by 'SPC f'.
  :prefix "SPC f"
  ;; This magic incantation is how we change the name of the
  ;; menu in `which-key'. Don't worry about it too much.
  "" '(:ignore t :wk "file"))

;; Once we set up the menu, using it is really easy!
(file-menu-definer
  ;; This binds the `find-file' function to 'SPC f f', and
  ;; changes the name in `which-key' to "find file" instead of `find-file'.
  "f" '(find-file :wk "find file"))

;; Next, let's set up some keybindings for managing buffers.
;; Now, Emacs has a bit of a weird nomenclature here.
;; A "Buffer" just refers to /some/ open thing.
;; This could be a file, but it could be some sort
;; of console output, or a whole host of other things.
(general-create-definer buffer-menu-definer
  :states '(normal motion)
  :wrapping global-definer
  :prefix "SPC b"
  "" '(:ignore t :wk "buffer"))

(buffer-menu-definer
  "b" '(switch-to-buffer :wk "switch buffer")
  "d" '(kill-current-buffer :wk "kill buffer"))

;; Continuing with the theme of weird nomenclature,
;; A "Window" is some split area of the screen.
;; Meanwhile, the operating system window is
;; called a "Frame". One must remember that Emacs
;; is from the 70s, so such ideas didn't have names yet!
(general-create-definer window-menu-definer
  :wrapping global-definer
  :prefix "SPC w"
  "" '(:ignore t :wk "window"))

(window-menu-definer
  "h" '(evil-window-left :wk "left")
  "j" '(evil-window-down :wk "down")
  "k" '(evil-window-up :wk "up")
  "l" '(evil-window-right :wk "right")
  "v" '(evil-window-vsplit :wk "vertical split")
  "s" '(evil-window-split :wk "horizontal split")
  "d" '(evil-window-delete :wk "close")
  "o" '(delete-other-windows :wk "close other")
  "f" '(toggle-frame-fullscreen :wk "toggle fullscreen")
  "=" '(balance-windows :wk "balance windows"))

;; Emacs has this concept called the "Universal Argument", which
;; can be used to modify the behavior of some keybindings.
;; However, that is normally bound to C-u, which we want to
;; use for scrolling up, as one would do in vim (See `evi-want-C-u-scroll')
;; Binding this to something else involves some hacks, but
;; they aren't that bad.
(defun better-universal-argument ()
  (interactive)
  (if current-prefix-arg
      (universal-argument-more current-prefix-arg)
    (universal-argument)))

(global-definer
  "u" '(better-universal-argument :wk "universal"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Incremental Completion/Search

;; `selectrum' (https://github.com/raxod502/selectrum) is kind of like `fzf', but
;; for Emacs, but for every single prompt!

(use-package selectrum
  :straight t
  :config
  (selectrum-mode 1))

;; `selectrum-prescient' (https://github.com/raxod502/prescient.el) gives us slightly better filtering + completion results.
(use-package selectrum-prescient
  :straight t
  :after selectrum
  :config
  (selectrum-prescient-mode 1))

;; `ctrlf' (https://github.com/raxod502/ctrlf) gives us a nice interface for interactively
;; searching within a buffer.
(use-package ctrlf
  :straight t
  :config
  (ctrlf-change-search-style 'fuzzy)
  ;; The `:general' keyword lets us define keybindings
  ;; as a part of package configuration. Here we are
  ;; binding the `/' key to search in normal mode.
  :general
  (general-def
    :keymaps 'override
    :states '(normal motion visual operator)
    "/" '(ctrlf-forward-literal :wk "search"))
  ;; Let's also use 'C-j' and 'C-k' to navigate
  ;; between search matches.
  (general-def
    :keymaps 'ctrlf-mode-map
    "C-j" 'ctrlf-forward-literal
    "C-k" 'ctrlf-backward-literal))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Auto completion

;; `company' (https://github.com/company-mode/company-mode) is a text completion
;; framework for Emacs.

(use-package company-mode
  :straight t
  :bind (:map company-active-map
              ("<tab>" . company-complete-selection))
  (:map lsp-mode-map
        ("<tab>" . company-indent-or-complete-common))
  :bind (("C-x C-j" . dired-jump))
  :diminish
  :custom
  (company-minimum-prefix-length 2)
  (company-idle-delay 0.1)
  (global-company-mode 1)
  (company-dabbrev-other-buffers t)
  (company-dabbrev-code-other-buffers t)
  (company-transformers '(company-sort-by-backend-importance
                          company-sort-prefer-same-case-prefix
                          company-sort-by-occurrence))
  (company-complete-number t)
  )

;(use-package company-box
;  :hook (company-mode . company-box-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Help and Documentation

;; Emacs is a self-documenting system, and you can get documentation
;; or help with just a few keystrokes! However, we are going to supercharge
;; this with a couple of packages.

;; First, let's set up the help menu to start with 'SPC h'.
(general-create-definer help-menu-definer
  :states '(normal motion)
  :wrapping global-definer
  :prefix "SPC h"
  "" '(:ignore t :wk "help"))

;; `helpful' (https://github.com/Wilfred/helpful) provides a bunch more information
;; when you ask for documentation for functions + variables.
;; Understanding how to use the help system is probably the number one thing
;; you can do to learn Emacs better, so it's worth exploring!
(use-package helpful
  :straight t
  :general
  (help-menu-definer
    "f" '(helpful-callable :wk "describe function")
    "v" '(helpful-variable :wk "describe variable")
    "m" '(describe-mode :wk "describe mode")
    "F" '(describe-face :wk "describe face")
    "k" '(helpful-key :wk "describe key")
    "'" '(describe-char :wk "describe char")))

;; `elisp-demos' (https://github.com/xuchunyang/elisp-demos) is a nice
;; little package that adds bits of demo code to help buffers.
(use-package elisp-demos
  :straight t
  :defer t
  :init
  (advice-add 'helpful-update :after 'elisp-demos-advice-helpful-update))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; General Programming Configuration

;; Let's highlight tariling whitespace.
(setq whitespace-style '(face trailing empty tabs))
(global-whitespace-mode)

;; Never indent with tabs
(add-hook 'prog-mode-hook
	  (lambda ()
	    (setq indent-tabs-mode nil)))

;; Auto-insert closing parens
(add-hook 'prog-mode-hook
          'electric-pair-mode)

;; `evil-commentary' (https://github.com/linktohack/evil-commentary) allows
;; use to easily comment things out with 'g c c'.
(use-package evil-commentary
  :straight t
  :hook (prog-mode . evil-commentary-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Agda

;; First, let's add some common locations to all the relevant PATH variables,
;; using our `add-to-path' helper from before.
(add-to-path "/usr/local/bin")
(add-to-path "~/.local/bin/")
(add-to-path "~/.cabal/bin")

;; Now for the tricky part. `agda-mode' is a bit odd, as Agda ships with a bundle of elisp
;; files that need to match up with the version of Agda you've installed. This makes
;; `use-package' + `straight' not work very well, so we have to do this by hand.

;; First, let's define a little helper function that will use the `agda-mode' binary to
;; find the location of the elisp files.
(defun agda-mode-locate ()
  "Determine the location of the `agda2-mode' elisp files on your system."
  (condition-case _ (with-temp-buffer (call-process "agda-mode" nil t nil "locate")
                                    (buffer-string))
      (error (error "Could not find the `agda-mode' binary in your path. Do you have agda installed?"))))

;; Now, let's load up `agda-mode'
(load (agda-mode-locate))

(setq agda2-highlight-level (quote interactive))
;; Once that file is loaded, we apply our configuration, which mostly consists of keybindings.
(with-eval-after-load (agda-mode-locate)
  (mode-leader-definer
    :keymaps 'agda2-mode-map
    "c" '(agda2-make-case :wk "case split")
    "l" '(agda2-load :wk "load")
    "n" '(agda2-compute-normalised-maybe-toplevel :wk "normalize")
    "i" '(agda2-search-about-toplevel :wk "info")
    "r" '(agda2-refine :wk "refine")
    "s" '(agda2-solve-maybe-all :wk "solve")
    "w" '(agda2-why-in-scope-maybe-toplevel :wk "describe scope")
    "o" '(agda2-module-contents-maybe-toplevel :wk "module contents")
    "," '(agda2-goal-and-context :wk "display goal")
    "." '(agda2-goal-and-context-and-inferred :wk "display type"))
  (global-motion-definer
    :keymaps 'agda2-mode-map
    "d" '(agda2-goto-definition-keyboard :wk "goto definition"))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Themes

;; The default Emacs theme is pretty jarring, but luckily
;; we can use some of the themes provided by Doom Emacs.
;; You can check out a full list at the repository:
;; * https://github.com/hlissner/emacs-doom-themes

;; If you want to experiment with other themes,
;; you can hit `SPC SPC' to execute a command, followed
;; by `disable-theme'. Then, hit `SPC SPC', followed by
;; `load-theme', and then select the theme you want to try out
;; If you don't like gruvbox, I recommend `doom-one'!
;;
;; Once you have a theme you like, you can change
;; the name of the theme in the `load-theme' call below
;; to have it loaded on startup.

(use-package doom-themes
  :straight t
  :config
  ;; Let's load the Gruvbox theme for now.
  (load-theme 'doom-gruvbox t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fonts

(add-to-list 'default-frame-alist
  '(font . "JetBrainsMono Nerd Font Mono"))
(set-face-attribute 'default t :font "JetBrainsMono Nerd Font Mono" )

;;; init.el ends here

