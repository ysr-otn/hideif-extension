;;; hideif-extension.el --- An expansion for hideif.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2020 Yoshihiro Ohtani

;; Author: Yoshihiro Ohtani
;; Version: 0.1.0
;; Package-Requires: ((f "0.20.0") (s "1.12.0"))
;; Keywords: tools, c

;; The function hide-ifdef-ext-use-define-alist is modified from 
;; hide-ifdef-use-define-alist that is implemented in hideif.el.
;; More details of the copyright and the license about hideif.el, see below.
	
	;;; hideif.el --- hides selected code within ifdef  -*- lexical-binding:t -*-

	;; Copyright (C) 1988, 1994, 2001-2019 Free Software Foundation, Inc.
	
	;; Author: Brian Marick
	;;	Daniel LaLiberte <liberte@holonexus.org>
	;; Maintainer: Luke Lee <luke.yx.lee@gmail.com>
	;; Keywords: c, outlines
	
	;; This file is part of GNU Emacs.
	
	;; GNU Emacs is free software: you can redistribute it and/or modify
	;; it under the terms of the GNU General Public License as published by
	;; the Free Software Foundation, either version 3 of the License, or
	;; (at your option) any later version.
	
	;; GNU Emacs is distributed in the hope that it will be useful,
	;; but WITHOUT ANY WARRANTY; without even the implied warranty of
	;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	;; GNU General Public License for more details.
	
	;; You should have received a copy of the GNU General Public License
	;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.


;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

;;; Load need libraries.
(require 'hideif)
(require 'f)
(require 's)

;; Extend hide-ifdef-use-define-alist to analyse hide-ifdef-define-alist 
;; that has a macro with value.
(defun hide-ifdef-ext-use-define-alist (name)
  "Set `hide-ifdef-env' to the define list specified by NAME."
  (interactive
   (list (completing-read "Use define list: "
						  (mapcar (lambda (x) (symbol-name (car x)))
								  hide-ifdef-define-alist)
						  nil t)))
  (if (stringp name) (setq name (intern name)))
  (let ((define-list (assoc name hide-ifdef-define-alis1t)))
	(if define-list
		(setq hide-ifdef-env
			  ;; If arg is cons like (MACRO . VALUE), use arg.
			  ;; If arg is not like MACRO, make cons (MACRO . t) and use it.
			  ;; This part is modified from hide-ifdef-use-define-alist.
			  (mapcar (lambda (arg) (cond ((consp arg) arg)
										  (t (cons arg t))))
					  (cdr define-list)))
	  (error "No define list for %s" name))
	(if hide-ifdef-hiding (hide-ifdefs))))

;;; An example to set hide-ifdef-define-alist that has a macro with values.
; (setq hide-ifdef-define-alist '((hoge FUGAFUGA (HOGE_1 . 1) (HOGE_2 . 2) (HOGE_3 . 3) (HOGE_TYPE . HOGE_2))
; 								(fuga FUGA (HOGE_1 . 1) (HOGE_2 . 2) (HOGE_3 . 3) (HOGE_TYPE . HOGE_3))))

;;; Convert string of macro value to (macro_name . value) of hide-ifdef-define-alist
(defun hide-ifdef-ext-conv-mcr-value (value)
  (cond ((s-match "^0[Xx][0-9A-Fa-f]+$" value)	; Hexadecimal number
		 ;; First convert hexadecimal string written in lowercase letters, then convert a number as hexadecimal.
		 (string-to-number (s-chop-prefix "0x" (s-downcase value)) 16))
		((s-match "^0[0-7]+$" value)  ; Octal number
		 ;; Convert to a number as octal. number.
		 (string-to-number (s-chop-prefix "0" value) 8))
		((s-match "[0-9]+\.[0-9]+$" value) ; Float number
		 ;; Convert to a number as float number.
		 (string-to-number value))
		((s-numeric? value) ; Integer
		 ;; Convert to a number as integer.
		 (string-to-number value))
		(t ; string
		 ;; convert a string to a symbol.
		 (intern value)))) 

;;; Make a element of hide-ifdef-define-alist from macro database file.
(defun hide-ifdex-exp-make-define-list (src-file mdb-file)
  ;; Execute only a case of file exist.
  (if (file-exists-p mdb-file)
	  ;; Combine first and second argument of append, the make a list 
	  ;; as a format of (filename	MACRO1	(MACRO2 . VALUE2) MACRO3 ..)
	  (append (list (intern src-file))	; Make a list as a format of (filename)
			  ;; Read from mdb-file written below format,
			  ;; then make a list as a format of (MACRO (MACRO1 . VALUE2) MACRO3 ...)
			  ;;  # command args1 args2 ...
			  ;;	MACRO1
			  ;;	MACRO2 VALUE2
			  ;;  MACRO3
			  ;;  ...
			  (mapcar '(lambda (x)
						 (let* ((mcr-lst (s-split " " x))	; Separate strings of each lines.
								(mcr-name (car mcr-lst))	; Macro name
								(mcr-value (cadr mcr-lst)))	; Macro value(if not exist it is nil)
						   ;; If macro value is exist,
						   (if mcr-value
							   ;; Collect to (MACRO . VALUE)
							   (cons (intern mcr-name) ; Convert macro name to a symbol.
									 (hide-ifdef-ext-conv-mcr-value mcr-value)) ; Convert macro value to a number or a symbol.
							 ;; If onnly macro name,
							 (intern mcr-name)))) ; Convert macro name to a symbol.
					  ;; Read all lines of mdb-file.
					  ;; First line is a comment start a character '#', so process second line or later. 
					  (cdr (s-lines (f-read-text mdb-file)))))))

;;; Search a macro database file that corresponding to src-file.
(defun hide-ifdef-ext-search-mcrdb-file (src-file)
  ;; A local function that search a directory '.mcrdb' in a directory 'dir' retroactively each parents directories.
  (cl-labels ((search-mcrdb-dir (dir)
								;; If '.mcrdb' is not found even if search until to a path that not include '/'
								;; (= If '.mcrdb' is not found even if search until to the top directory),
								;; return nil and end.
								(if (null (s-match "/" dir))
									nil
								  ;; Search recursively until found mcrdb-dir(= ${dir}/.mcrdb).
								  (let ((mcrdb-dir (s-concat (f-slash dir) ".mcrdb")))
									(if (f-directory-p mcrdb-dir)
										mcrdb-dir
									  ;; Search recursively using the directory name that deleted right side string 
									  ;; than last '/' of dir.
									  (search-mcrdb-dir (s-chop-suffix (car (s-match "/[^/]*$" dir)) dir)))))))
	;;     ;; Absolute path of .mcrdb
	(let* ((mcrdb-dir (search-mcrdb-dir (f-dirname src-file)))
		   ;; The relative path from the directory that include .mcrdb to the source file.
		   (src-file-relative (s-chop-prefix (f-slash (f-dirname mcrdb-dir)) src-file))
		   ;; Absolute path of macro database file .mdb that corresponding to the source file.
		   (mcrdb-file (s-concat (f-slash mcrdb-dir) src-file-relative ".mdb")))
	  ;; Return file name if the macro database file .mdb is exist.
	  (if (f-file-p mcrdb-file)
		  mcrdb-file))))

;;; Read the macro database file when open the source file.
(defun hide-ifdef-ext-add-define-alist ()
  (let* ((src-file (f-this-file))	; Source file
		 (mdb-file (hide-ifdef-ext-search-mcrdb-file src-file)))	; Macro database file
	;; If macro database file is exist,
	(if mdb-file
		(progn
		  ;; Add a data that made from the macro database file to hide-ifdef-define-alist.
		  (push (hide-ifdex-exp-make-define-list src-file mdb-file)
				hide-ifdef-define-alist)
		  ;; Select the data that was added to hide-ifdef-define-alist.
		  (hide-ifdef-ext-use-define-alist src-file)))))
  

;;; Add the setting of hide-ifdef-ext to hide-ifdef-mode-hook.
(add-hook 'hide-ifdef-mode-hook
		  '(lambda ()
			 ;; Redefine hide-ifdef-env as a local value.
			 ;; (To selectively use of different defined of ifdef to multiple source codes.)
			 (set (make-local-variable 'hide-ifdef-env)
				  (default-value 'hide-ifdef-env))
			 ;; Read the macro database file when open the source file.
			 (hide-ifdef-ext-add-define-alist)
			 ))


(provide 'hideif-extension)
;;; hideif-extension.el ends here
