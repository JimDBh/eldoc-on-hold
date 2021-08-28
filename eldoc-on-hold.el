;;; eldoc-on-hold.el --- Summary -*- lexical-binding: t; -*-

;; Copyright 2021 Google LLC
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;      http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.
;;
;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:
;;
;; This package extends eldoc.el to display documentations with a delay.
;;
;; When `global-eldoc-on-hold-mode' is on, eldoc will wait for an extra
;; time of `eldoc-on-hold-delay-interval' seconds to display the message
;; (Note that this is in addition to `eldoc-idle-delay', however `eldoc-idle-delay'
;; delays the calculation of eldoc info, while `eldoc-on-hold-delay-interval'
;; delays the display of the info).
;;
;; An extra command, `eldoc-on-hold-pick-up' is also provided to immediately
;; display the eldoc message.

;;; Code:

(eval-when-compile (require 'eldoc))

(defcustom eldoc-on-hold-delay-interval 5.0
  "Delayed time to display eldoc."
  :group 'eldoc-on-hold
  :type 'number)

(defcustom eldoc-on-hold-pause-after-clear 1.0
  "Time to pause on-hold after clearing eldoc messages."
  :group 'eldoc-on-hold
  :type 'number)

(defvar eldoc-on-hold--msg-timer nil
  "Timer for displaying eldoc messages.")
(defvar eldoc-on-hold--no-delay-timer nil
  "Timer to reset 'eldoc-on-hold--use-timer' after a cancel event.")
(defvar eldoc-on-hold--use-timer t
  "Internal variable to keep track of whether we should delay the display.")
(defvar eldoc-on-hold--prev-interval nil
  "Internal variable to remember the user's preferred delay time.")

(defun eldoc-on-hold--refresh (orig-fun)
  "Immediately refresh the eldoc output.
Used to advice ORIG-FUN, which should be 'eldoc-pre-command-refresh-echo-area'."
  (when (not (equal this-command 'eldoc-on-hold-pick-up))
    (let ((eldoc-on-hold--use-timer nil))
      (funcall orig-fun))))

(defun eldoc-on-hold--msg (orig-fun &optional string)
  "Show eldoc message with a delay.
Used to advice ORIG-FUN, which should be 'eldoc--message'.
STRING is the message to display."
  ;; Cancel the pending delay timer
  (when eldoc-on-hold--msg-timer
    (cancel-timer eldoc-on-hold--msg-timer)
    (setq eldoc-on-hold--msg-timer nil))
  (cond ((or (not eldoc-on-hold--use-timer) (and string eldoc-last-message))
         ;; Display the string immediately.
         ;; This is caused by:
         ;; 1. eldoc-on-hold-use-timer is nil
         ;; 2. eldoc is currently displaying some message, and we should
         ;;    continue doing so to avoid flickering.
         (funcall orig-fun string))
        ((not string)
         ;; The variable string is nil. This means eldoc is trying to clear the
         ;; message, and we should do it immediately.
         (when eldoc-last-message
           ;; If eldoc is displaying something, it is possible that this
           ;; operation of clearing the display is not intended by the user (for
           ;; example, accidentally went out of the symbol under point). So we
           ;; temporarily set eldoc-on-hold--use-timer to nil for a short period
           ;; allowing immediate display of info to avoid annoyance.
           (setq eldoc-on-hold--use-timer nil)
           (when eldoc-on-hold--no-delay-timer
             (cancel-timer eldoc-on-hold--no-delay-timer))
           (setq eldoc-on-hold--no-delay-timer
                 (run-with-timer eldoc-on-hold-pause-after-clear nil
                                 (lambda ()
                                   (setq eldoc-on-hold--use-timer t)))))
         (funcall orig-fun string))
        (t
         (setq eldoc-on-hold--msg-timer
               (run-with-timer eldoc-on-hold-delay-interval nil orig-fun string))))
  ;; Recover the original eldoc-on-hold--delay-interval value
  (setq eldoc-on-hold-delay-interval eldoc-on-hold--prev-interval)
  eldoc-last-message)

(defun eldoc-on-hold--dummy ()
  "Dummy function used to display the eldoc message (almost) immediately."
  (interactive)
  (let ((last-command 'eldoc-on-hold--dummy)
        (this-command nil)
        (eldoc--last-request-state nil))
    ;; Set eldoc-on-hold-delay-interval to a very small value to display the
    ;; message almost immediately.
    (setq eldoc-on-hold-delay-interval 0.001)
    ;; The function eldoc-print-current-symbol-info requires that
    ;; 1. last-command is in eldoc-message-commands,
    ;; 2. this-command is nil
    ;; 3. eldoc's request state is not the same as last time.
    ;; We set those values temporarily with the let clause.
    ;; One caveat is that for async eldoc sources like eglot, the above are
    ;; checked after eldoc receives the message, and in that case this let
    ;; clause has finished and last-command is set back to the original
    ;; value. Since this function (eldoc-on-hold--dummy) is called by a command
    ;; eldoc-on-hold-pick-up, we also add eldoc-on-hold-pick-up to
    ;; eldoc-message-commands to work around this.
    (eldoc-print-current-symbol-info)))

(defun eldoc-on-hold-pick-up ()
  "Display the eldoc message immediately.
If we have a pending timer, do what is planned by the timer right now.
If there's no pending timer, call eldoc and display the message."
  (interactive)
  (when (not eldoc-on-hold--msg-timer)
    (progn
      (call-interactively 'eldoc-on-hold--dummy t)))
  ;; With sync sources, the above will schedule a timer, and we can just display
  ;; it right now.  For async sources, the timer will be ran after a very short
  ;; time after the message is available.
  (when eldoc-on-hold--msg-timer
    (let ((func (timer--function eldoc-on-hold--msg-timer))
          (arg (timer--args eldoc-on-hold--msg-timer)))
      (apply func arg)
      (cancel-timer eldoc-on-hold--msg-timer)
      (setq eldoc-on-hold--msg-timer nil))))

(defun eldoc-on-hold--cancel-timer ()
  "Cancel the delayed eldoc display if necessary."
  (when (and eldoc-on-hold--msg-timer
             (or (not (eldoc--message-command-p last-command))
                 this-command))
    (cancel-timer eldoc-on-hold--msg-timer)))

(define-minor-mode global-eldoc-on-hold-mode
  "Enable global-eldoc-on-hold mode."
  :group 'eldoc-on-hold
  :global t
  (if global-eldoc-on-hold-mode
      (progn
        (setq eldoc-on-hold--msg-timer nil)
        (setq eldoc-on-hold--no-delay-timer nil)
        (setq eldoc-on-hold--use-timer t)
        (setq eldoc-on-hold--prev-interval eldoc-on-hold-delay-interval)
        (advice-add 'eldoc--message :around #'eldoc-on-hold--msg)
        (advice-add 'eldoc-pre-command-refresh-echo-area :around #'eldoc-on-hold--refresh)
        (eldoc-add-command 'eldoc-on-hold--dummy)
        (eldoc-add-command 'eldoc-on-hold-pick-up)
        (add-hook 'post-command-hook #'eldoc-on-hold--cancel-timer))
    (advice-remove 'eldoc--message #'eldoc-on-hold--msg)
    (advice-remove 'eldoc-pre-command-refresh-echo-area #'eldoc-on-hold--refresh)
    (eldoc-remove-command 'eldoc-on-hold--dummy)
    (eldoc-remove-command 'eldoc-on-hold-pick-up)
    (when eldoc-on-hold--msg-timer
      (cancel-timer eldoc-on-hold--msg-timer))
    (when eldoc-on-hold--no-delay-timer
      (cancel-timer eldoc-on-hold--no-delay-timer))
    (setq eldoc-on-hold--msg-timer nil)
    (setq eldoc-on-hold--no-delay-timer nil)
    (setq eldoc-on-hold--use-timer t)
    (setq eldoc-on-hold-delay-interval eldoc-on-hold--prev-interval)
    (remove-hook 'post-command-hook #'eldoc-on-hold--cancel-timer)))

(provide 'eldoc-on-hold)
;;; eldoc-on-hold.el ends here
