;;; wisent-calc-wy.el --- Generated parser support file

;; Copyright (C) 2003 David Ponce
;;
;; Author: David Ponce <david@dponce.com>
;; Created: 2003-08-01 08:53:28+0200
;; Keywords: syntax
;; X-RCS: $Id: wisent-calc-wy.el,v 1.1 2003/08/02 08:16:29 ponced Exp $
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.
;;
;; This software is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; PLEASE DO NOT MANUALLY EDIT THIS FILE!  It is automatically
;; generated from the grammar file wisent-calc.wy.

;;; History:
;;

;;; Code:

;;; Prologue
;;

;;; Declarations
;;
(defconst wisent-calc-wy--keyword-table
  (semantic-lex-make-keyword-table 'nil 'nil)
  "Table of language keywords.")

(defconst wisent-calc-wy--token-table
  (wisent-lex-make-token-table
   '(("number"
      (NUM)))
   'nil)
  "Table of lexical tokens.")

(defconst wisent-calc-wy--parse-table
  (progn
    (eval-when-compile
      (require 'wisent-comp))
    (wisent-compile-grammar
     '((NUM)
       ((nonassoc 61)
        (left 45 43)
        (left 42 47)
        (left NEG)
        (right 94))
       (input
        ((line))
        ((input line)
         (format "%s %s" $1 $2)))
       (line
        ((59)
         ";")
        ((exp 59)
         (format "%s;" $1)))
       (exp
        ((NUM)
         (string-to-number $1))
        ((exp 61 exp)
         (= $1 $3))
        ((exp 43 exp)
         (+ $1 $3))
        ((exp 45 exp)
         (- $1 $3))
        ((exp 42 exp)
         (* $1 $3))
        ((exp 47 exp)
         (/ $1 $3))
        ((45 exp)
         [NEG]
         (- $2))
        ((exp 94 exp)
         (expt $1 $3))
        ((40 exp 41)
         $2)))
     'nil))
  "Parser table.")

(defun wisent-calc-wy--install-parser ()
  "Setup the Semantic Parser."
  (semantic-install-function-overrides
   '((parse-stream . wisent-parse-stream)))
  (setq semantic-parser-name "LALR"
        semantic-toplevel-bovine-table wisent-calc-wy--parse-table
        semantic-debug-parser-source "wisent-calc.wy"
        semantic-flex-keywords-obarray wisent-calc-wy--keyword-table
        semantic-lex-types-obarray wisent-calc-wy--token-table)
  ;; Collect unmatched syntax lexical tokens
  (semantic-make-local-hook 'wisent-discarding-token-functions)
  (add-hook 'wisent-discarding-token-functions
            'wisent-collect-unmatched-syntax nil t))


;;; Epilogue
;;
(defun wisent-calc-setup-parser ()
  "Setup buffer for parse."
  (wisent-calc-wy--install-parser)
  (setq semantic-number-expression
        (concat "\\([0-9]+\\([.][0-9]*\\)?\\([eE][-+]?[0-9]+\\)?"
                "\\|[.][0-9]+\\([eE][-+]?[0-9]+\\)?\\)")
        semantic-lex-analyzer #'wisent-calc-lexer
        semantic-lex-depth nil
        semantic-lex-syntax-modifications
        '((?\; ".") (?\= ".") (?\+ ".")
          (?\- ".") (?\* ".") (?\/ ".")
          (?\^ ".") (?\( ".") (?\) ".")
          )
        )
  )

(provide 'wisent-calc-wy)

;;; wisent-calc-wy.el ends here
