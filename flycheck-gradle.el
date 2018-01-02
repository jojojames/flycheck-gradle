;;; flycheck-gradle.el --- Flycheck extension for Gradle. -*- lexical-binding: t -*-

;; Copyright (C) 2017 James Nguyen

;; Authors: James Nguyen <james@jojojames.com>
;; Version: 1.0
;; Package-Requires: ((emacs "25.1") (flycheck "0.25"))
;; Keywords: languages gradle

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Flycheck extension for Gradle.
;; (with-eval-after-load 'flycheck
;;   (flycheck-gradle-setup))

;;; Code:

(require 'flycheck)
(require 'cl-lib)

;; Compatibility
(eval-and-compile
  (when (version< emacs-version "26")
    (with-no-warnings
      (defalias 'if-let* #'if-let)
      (defalias 'when-let* #'when-let)
      (function-put #'if-let* 'lisp-indent-function 2)
      (function-put #'when-let* 'lisp-indent-function 1))))

;;; Flycheck

(flycheck-def-executable-var gradle "gradle")

(flycheck-def-option-var flycheck-gradle-extra-flags nil gradle
  "Extra flags prepended to arguments of gradle."
  :type '(repeat (string :tag "Flags"))
  :safe #'flycheck-string-list-p)

(flycheck-define-checker gradle
  "Flycheck plugin for for Gradle."
  :command ("./gradlew"
            (eval (flycheck-gradle-warm-or-cold-build))
            "--warn"
            "--console"
            "plain"
            (eval flycheck-gradle-extra-flags))
  :error-patterns
  (;; e: /kotlin/MainActivity.kt: (10, 46): Expecting ')'
   (error line-start "e: " (file-name) ": (" line ", " column "): "
          (message) line-end)
   ;; w: /kotlin/MainActivity.kt: (12, 13): Variable 'a' is never used
   (warning line-start "w: " (file-name) ": (" line ", " column "): "
            (message) line-end))
  :modes (groovy-mode java-mode kotlin-mode)
  :predicate
  (lambda ()
    (funcall #'flycheck-gradle--gradle-available-p))
  :working-directory
  (lambda (checker)
    (flycheck-gradle--find-gradleproj-directory checker)))

;;;###autoload
(defun flycheck-gradle-setup ()
  "Setup Flycheck for Gradle."
  (interactive)
  (add-to-list 'flycheck-checkers 'gradle))

(defun flycheck-gradle-warm-or-cold-build ()
  "Return whether or not gradle should be ran with clean."
  (if (flycheck-has-current-errors-p 'error)
      '("build")
    '("clean" "build")))

(defun flycheck-gradle--gradle-available-p ()
  "Return whether or not current buffer is part of a Gradle project."
  (flycheck-gradle--find-gradleproj-directory 'gradle))

(defun flycheck-gradle--find-gradleproj-directory (&optional _checker)
  "Return directory containing gradlew file or nil if file is not found."
  (locate-dominating-file buffer-file-name "gradlew"))

;; HACK
;; Flycheck doesn't seem to 'pass' this checker since it won't be able to find
;; the gradlew file (sine it's project specific). Advise these functions so
;; the check will pass.
(defun flycheck-gradle-find-checker-executable (f &rest args)
  "Return flycheck executable."
  (if (flycheck-gradle-should-use-gradle-p args)
      (or (flycheck-gradle-find-gradlew-executable)
          (apply f args))
    (apply f args)))

(advice-add 'flycheck-find-checker-executable
            :around 'flycheck-gradle-find-checker-executable)

(defun flycheck-gradle-verify-checker (f &rest args)
  "Return whether or not flycheck should verify checker."
  (if (flycheck-gradle-should-use-gradle-p args)
      (or (flycheck-gradle-find-gradlew-executable)
          (apply f args))
    (apply f args)))

(advice-add 'flycheck-verify-checker :around 'flycheck-gradle-verify-checker)

(defun flycheck-gradle-may-use-checker (f &rest args)
  "Return whether or not flycheck should use checker."
  (if (flycheck-gradle-should-use-gradle-p args)
      (or (flycheck-gradle-find-gradlew-executable)
          (apply f args))
    (apply f args)))

(advice-add 'flycheck-may-use-checker :around 'flycheck-gradle-verify-checker)

(defun flycheck-gradle-should-use-gradle-p (args)
  "Return whether or not flycheck should be advised to pass through gradle."
  (and (eq (nth 0 args) 'gradle)
       (memq major-mode '(java-mode groovy-mode kotlin-mode))))

(defun flycheck-gradle-find-gradlew-executable ()
  "Return path containing gradlew, if it exists."
  (when-let* ((path (locate-dominating-file buffer-file-name "gradlew")))
    (concat path "gradlew")))

(provide 'flycheck-gradle)
;;; flycheck-gradle.el ends here
