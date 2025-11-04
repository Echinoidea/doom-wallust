;;; doom-wallust.el --- Wallust integration for Doom Emacs -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025
;;
;; Author: Your Name
;; Keywords: faces, themes
;; Version: 1.0.0
;; Package-Requires: ((emacs "24.3") (doom-themes "2.2.1"))
;;
;;; Commentary:
;;
;; This package integrates Wallust (a pywal alternative) with Doom Emacs,
;; providing automatic theme generation and an interactive theme browser.
;;
;;; Code:

(require 'doom-themes)
(require 'ansi-color)

(defvar doom-user-dir)
(declare-function doom/reload-theme "doom-ui" ())

(defgroup doom-wallust nil
  "Wallust integration for Doom Emacs."
  :group 'doom-themes
  :prefix "doom-wallust-")

(defcustom doom-wallust-doom-dir
  (or (bound-and-true-p doom-user-dir)
      (expand-file-name "~/.config/doom"))
  "Directory where Doom Emacs configuration is stored."
  :type 'string
  :group 'doom-wallust)

(defcustom doom-wallust-config-dir
  (expand-file-name "~/.config/wallust")
  "Directory where wallust configuration is stored."
  :type 'string
  :group 'doom-wallust)

(defcustom doom-wallust-post-run-hook nil
  "Hook run after wallust theme is applied.
Use this to update other programs (e.g., terminal, shell)."
  :type 'hook
  :group 'doom-wallust)

(defcustom doom-wallust-auto-reload t
  "Automatically reload Emacs theme after running wallust."
  :type 'boolean
  :group 'doom-wallust)

(defvar doom-wallust--theme-cache nil
  "Cache of available wallust themes.")

(defvar doom-wallust--current-theme nil
  "Currently selected wallust theme.")

;;; Utility functions

(defun doom-wallust--executable ()
  "Return path to wallust executable or nil if not found."
  (executable-find "wallust"))

(defun doom-wallust--ensure-executable ()
  "Ensure wallust is installed and available."
  (unless (doom-wallust--executable)
    (user-error "Wallust executable not found. Please install wallust first")))

(defun doom-wallust--strip-ansi (str)
  "Remove ANSI escape codes from STR."
  (replace-regexp-in-string "\033\\[[0-9;]*m" "" str))

(defun doom-wallust--get-themes ()
  "Get list of available wallust themes."
  (doom-wallust--ensure-executable)
  (let* ((output (shell-command-to-string "wallust theme list 2>/dev/null"))
         (clean-output (doom-wallust--strip-ansi output))
         (lines (split-string clean-output "\n" t))
         (themes '())
         (in-themes-section nil))
    (dolist (line lines)
      ;; Start collecting when we see "Available themes:"
      (when (string-match-p "^Available themes" line)
        (setq in-themes-section t))
      ;; Stop when we hit "Extra:" section
      (when (string-match-p "^Extra" line)
        (setq in-themes-section nil)
        ;; Add "random" as a valid option
        (push "random" themes))
      ;; Collect theme names (lines starting with "- ")
      (when (and in-themes-section
                 (string-match "^[[:space:]]*-[[:space:]]+\\([^[:space:](]+\\)" line))
        (let ((theme (match-string 1 line)))
          ;; Exclude "list" since it's a command, not a theme
          (unless (string= theme "list")
            (push theme themes)))))
    (nreverse themes)))

(defun doom-wallust--preview-theme (theme)
  "Get color preview for THEME as ANSI string."
  (doom-wallust--ensure-executable)
  (shell-command-to-string
   (format "wallust theme %s --preview 2>&1" (shell-quote-argument theme))))

(defun doom-wallust--parse-ansi-colors (ansi-string)
  "Parse ANSI color codes from ANSI-STRING and return list of RGB colors."
  (let ((colors '())
        (pos 0))
    (while (string-match "\\[48;2;\\([0-9]+\\);\\([0-9]+\\);\\([0-9]+\\)m" ansi-string pos)
      (let ((r (string-to-number (match-string 1 ansi-string)))
            (g (string-to-number (match-string 2 ansi-string)))
            (b (string-to-number (match-string 3 ansi-string))))
        (push (format "#%02x%02x%02x" r g b) colors)
        (setq pos (match-end 0))))
    (nreverse colors)))

(defun doom-wallust--apply-theme (theme)
  "Apply wallust THEME."
  (doom-wallust--ensure-executable)
  (message "Applying wallust theme: %s..." theme)
  (let* ((cmd (format "wallust theme %s 2>&1" (shell-quote-argument theme)))
         (result (shell-command-to-string cmd))
         (clean-result (doom-wallust--strip-ansi result)))
    ;; Check for actual errors (not warnings). Look for error patterns in clean output
    (if (string-match-p "\\[E\\]\\|Error:\\|error:\\|ERROR:" clean-result)
        (user-error "Failed to apply theme: %s" clean-result)
      ;; If random was selected, extract the actual theme name from clean output
      (let ((actual-theme theme))
        (when (string= theme "random")
          (if (string-match "randomly selected \\([^\n\r]+\\)" clean-result)
              (let ((matched (match-string 1 clean-result)))
                ;; Trim any trailing whitespace or color blocks
                (setq actual-theme (string-trim matched))
                (message "✓ Random theme selected: %s" actual-theme))
            (message "Warning: Could not parse random theme name from output")))
        (setq doom-wallust--current-theme actual-theme)
        (message "✓ Applied wallust theme: %s" actual-theme)
        (when doom-wallust-auto-reload
          (sit-for 0.5) ; Give wallust time to write files
          (doom-wallust-reload-theme)
          (message "✓ Reloaded Emacs with wallust theme: %s" actual-theme))
        (run-hooks 'doom-wallust-post-run-hook)
        t))))

(defun doom-wallust-reload-theme ()
  "Reload the doom-wallust theme after wallust updates it."
  (interactive)
  (let* ((dark-theme-file (expand-file-name "themes/doom-wallust-dark-theme.el" doom-wallust-doom-dir))
         (light-theme-file (expand-file-name "themes/doom-wallust-light-theme.el" doom-wallust-doom-dir))
         (theme-file (if (eq (frame-parameter nil 'background-mode) 'dark)
                         dark-theme-file
                       light-theme-file))
         (theme-name (if (eq (frame-parameter nil 'background-mode) 'dark)
                         'doom-wallust-dark
                       'doom-wallust-light)))
    (if (file-exists-p theme-file)
        (progn
          ;; Unload the old theme completely
          (when (featurep theme-name)
            (unload-feature theme-name t))
          ;; Clear any cached theme data
          (setq custom-enabled-themes (delq theme-name custom-enabled-themes))
          ;; Load the new theme file
          (load-file theme-file)
          ;; Apply the theme
          (load-theme theme-name t)
          ;; If doom/reload-theme exists, use it for additional cleanup
          (when (fboundp 'doom/reload-theme)
            (doom/reload-theme))
          (message "Reloaded doom-wallust theme"))
      (user-error "Theme file not found: %s" theme-file))))

;;; Configuration setup

(defun doom-wallust--ensure-config ()
  "Ensure wallust configuration and templates are set up."
  (let ((config-file (expand-file-name "wallust.toml" doom-wallust-config-dir))
        (templates-dir (expand-file-name "templates" doom-wallust-config-dir))
        (dark-template (expand-file-name "templates/doom-wallust-dark-theme.el" doom-wallust-config-dir))
        (light-template (expand-file-name "templates/doom-wallust-light-theme.el" doom-wallust-config-dir)))
    
    ;; Create directories if they don't exist
    (unless (file-directory-p doom-wallust-config-dir)
      (make-directory doom-wallust-config-dir t))
    (unless (file-directory-p templates-dir)
      (make-directory templates-dir t))
    
    ;; Check and update config file
    (doom-wallust--ensure-config-entries config-file)
    
    ;; Create template files if they don't exist
    (unless (file-exists-p dark-template)
      (doom-wallust--create-dark-template dark-template))
    (unless (file-exists-p light-template)
      (doom-wallust--create-light-template light-template))))

(defun doom-wallust--ensure-config-entries (config-file)
  "Ensure CONFIG-FILE has the necessary template entries."
  (let ((dark-target (expand-file-name "themes/doom-wallust-dark-theme.el" doom-wallust-doom-dir))
        (light-target (expand-file-name "themes/doom-wallust-light-theme.el" doom-wallust-doom-dir))
        (config-content (if (file-exists-p config-file)
                            (with-temp-buffer
                              (insert-file-contents config-file)
                              (buffer-string))
                          ""))
        (needs-update nil))
    
    ;; Check if [templates] section exists
    (unless (string-match-p "\\[templates\\]" config-content)
      (setq config-content (concat config-content "\n[templates]\n"))
      (setq needs-update t))
    
    ;; Check for dark theme entry
    (unless (string-match-p "doom-wallust-dark" config-content)
      (setq config-content
            (replace-regexp-in-string
             "\\[templates\\]"
             (format "[templates]\ndoom-wallust-dark = { template = 'doom-wallust-dark-theme.el', target = '%s' }"
                     dark-target)
             config-content))
      (setq needs-update t))
    
    ;; Check for light theme entry
    (unless (string-match-p "doom-wallust-light" config-content)
      (setq config-content
            (replace-regexp-in-string
             "\\[templates\\]"
             (format "[templates]\ndoom-wallust-light = { template = 'doom-wallust-light-theme.el', target = '%s' }"
                     light-target)
             config-content t))
      (setq needs-update t))
    
    ;; Write updated config
    (when needs-update
      (with-temp-file config-file
        (insert config-content))
      (message "Updated wallust config: %s" config-file))))

;;; Interactive theme browser

(defvar doom-wallust-browser-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'doom-wallust-browser-apply-theme)
    (define-key map (kbd "v") 'doom-wallust-browser-preview-theme)
    (define-key map (kbd "j") 'next-line)
    (define-key map (kbd "k") 'previous-line)
    (define-key map (kbd "n") 'next-line)
    (define-key map (kbd "p") 'previous-line)
    (define-key map (kbd "q") 'quit-window)
    (define-key map (kbd "g") 'doom-wallust-browser-refresh)
    (define-key map (kbd "r") 'doom-wallust-browser-refresh)
    map)
  "Keymap for `doom-wallust-browser-mode'.")

(define-derived-mode doom-wallust-browser-mode special-mode "Wallust-Browser"
  "Major mode for browsing and selecting wallust themes.
\\{doom-wallust-browser-mode-map}"
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (when (featurep 'evil)
    (evil-set-initial-state 'doom-wallust-browser-mode 'normal)))

(defun doom-wallust-browser-refresh ()
  "Refresh the theme browser."
  (interactive)
  (doom-wallust-browse-themes))

(defun doom-wallust-browser-apply-theme ()
  "Apply the theme at point."
  (interactive)
  (let ((theme (get-text-property (point) 'doom-wallust-theme)))
    (when theme
      (doom-wallust--apply-theme theme)
      (message "Applied theme: %s" theme))))

(defun doom-wallust-browser-preview-theme ()
  "Show color preview for theme at point."
  (interactive)
  (let ((theme (get-text-property (point) 'doom-wallust-theme)))
    (when theme
      (let ((preview (doom-wallust--preview-theme theme)))
        (with-current-buffer (get-buffer-create "*Wallust Preview*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert preview)
            (ansi-color-apply-on-region (point-min) (point-max))
            (goto-char (point-min)))
          (special-mode)
          (display-buffer (current-buffer)))))))

(defun doom-wallust-browse-themes ()
  "Open interactive theme browser."
  (interactive)
  (doom-wallust--ensure-executable)
  (message "DEBUG: Starting theme browser...")
  (let ((themes (doom-wallust--get-themes))
        (buffer (get-buffer-create "*Wallust Themes*")))
    (message "DEBUG: Got %d themes for browser" (length themes))
    (if (null themes)
        (user-error "No themes found! Check wallust installation")
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (doom-wallust-browser-mode)
          (insert (propertize "Wallust Theme Browser\n" 'face 'bold))
          (insert (propertize "======================\n\n" 'face 'bold))
          (insert "Press RET to apply theme, 'p' for preview, 'g' to refresh, 'q' to quit\n\n")
          
          (dolist (theme themes)
            (let ((start (point)))
              (insert (format "  %s" theme))
              (when (equal theme doom-wallust--current-theme)
                (insert " [current]"))
              (insert "\n")
              (put-text-property start (point) 'doom-wallust-theme theme)
              (put-text-property start (point) 'face
                                 (if (equal theme doom-wallust--current-theme)
                                     '(:inherit success :weight bold)
                                   'default))))
          (goto-char (point-min))
          (forward-line 5)))
      (message "DEBUG: Displaying buffer")
      (pop-to-buffer buffer))))

;;; Fuzzy finder integration

(defun doom-wallust-select-theme ()
  "Select and apply a wallust theme using completion."
  (interactive)
  (doom-wallust--ensure-executable)
  (let* ((themes (doom-wallust--get-themes)))
    (if (null themes)
        (user-error "No themes found!")
      (let ((theme (completing-read "Select wallust theme: " themes nil t)))
        (when (and theme (not (string-empty-p theme)))
          (doom-wallust--apply-theme theme))))))

;;; Template creation

(defun doom-wallust--create-dark-template (file)
  "Create dark theme template at FILE."
  (with-temp-file file
    (insert-file-contents 
     (expand-file-name "doom-wallust-dark-theme.el" 
                       (file-name-directory (locate-library "doom-wallust"))))))

(defun doom-wallust--create-light-template (file)
  "Create light theme template at FILE."
  (with-temp-file file
    (insert-file-contents 
     (expand-file-name "doom-wallust-light-theme.el" 
                       (file-name-directory (locate-library "doom-wallust"))))))

;;; Setup and initialization

;;;###autoload
(defun doom-wallust-setup ()
  "Set up doom-wallust configuration and templates."
  (interactive)
  (doom-wallust--ensure-config)
  (message "Doom-wallust setup complete! Run 'wallust theme <theme>' to generate themes."))

;;;###autoload
(defun doom-wallust-initialize ()
  "Initialize doom-wallust integration.
Call this function in your config to set up wallust integration."
  (doom-wallust-setup))

(provide 'doom-wallust)
;;; doom-wallust.el ends here
