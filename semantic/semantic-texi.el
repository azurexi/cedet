;;; semantic-texi.el --- Semantic details for Texinfo files

;;; Copyright (C) 2001, 2002, 2003 Eric M. Ludlam

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; X-RCS: $Id: semantic-texi.el,v 1.16 2003/08/01 16:39:19 zappo Exp $

;; This file is not part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This software is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; Parse Texinfo buffers using regular expressions.  The core parser
;; engine is the function `semantic-texi-bovinate-headings'.  The
;; parser plug-in is the function `semantic-texi-parse-region' that
;; overrides `semantic-parse-region'.

(require 'semantic)
(require 'semantic-format)
(require 'texinfo)

(eval-when-compile
  (require 'semanticdb)
  (require 'semanticdb-find)
  (require 'semantic-ctxt)
  (require 'semantic-imenu)
  (require 'document)
  (require 'senator))

(defvar semantic-texi-super-regex
  "^@\\(chapter\\|\\(sub\\)*section\\|unnumbered\\(\\(sub\\)*sec\\)?\\|\
\\(chap\\|\\(sub\\)+\\|major\\)?heading\\|appendix\\(\\(sub\\)*sec\\)?\\|\
centerchap\\|def\\(var\\|un\\|fn\\|opt\\)x?\\)"
  "Regular expression used to find special sections in a Texinfo file.")

(defvar semantic-texi-name-field-list
  '( ("defvar" . 1)
     ("defvarx" . 1)
     ("defun" . 1)
     ("defunx" . 1)
     ("defopt" . 1)
     ("deffn" . 2)
     ("deffnx" . 2)
     )
  "List of definition commands, and the field position.
The field position is the field number (based at 1) where the
name of this section is.")

;;; Code:
(defun semantic-texi-parse-region (&rest ignore)
  "Parse the current texinfo buffer for semantic tags.
IGNORE any arguments, always parse the whole buffer.
Each tag returned is of the form:
 (\"NAME\" section (:members CHILDREN))
or
 (\"NAME\" def)

It is an override of 'parse-region and must be installed by the
function `semantic-install-function-overrides'."
  ;;(semantic-texi-bovinate-headings)
  (mapcar 'semantic-texi-expand-tag
          (semantic-texi-bovinate-headings)))

(defun semantic-texi-parse-changes ()
  "Parse changes in the current texinfo buffer."
  ;; NOTE: For now, just schedule a full reparse.
  ;;       To be implemented later.
  (semantic-parse-tree-set-needs-rebuild))

(defun semantic-texi-expand-tag (tag)
  "Expand the texinfo tag TAG."
  (let ((chil (semantic-texi-components tag)))
    (if chil
        (semantic-tag-put-attribute
         tag :members (mapcar 'semantic-texi-expand-tag chil)))
    (car (semantic--tag-expand tag))))

(defun semantic-texi-bovinate-headings ()
  "Parse the current texinfo buffer for all semantic tags now."
  (let ((pass1 nil))
    ;; First search and snarf.
    (save-excursion
      (goto-char (point-min))
      (working-status-forms (file-name-nondirectory buffer-file-name) "done"
	(while (re-search-forward semantic-texi-super-regex nil t)
	  (setq pass1 (cons (match-beginning 0) pass1))
	  (working-status)
	  )
	(working-status t)))
    (setq pass1 (nreverse pass1))
    ;; Now, make some tags while creating a set of children.
    (car (semantic-texi-recursive-combobulate-list pass1 0))
    ))

(defsubst semantic-texi-new-section-tag (name members start end)
  "Create a semantic tag of class section.
NAME is the name of this section.
MEMBERS is a list of semantic tags representing the elements that make
up this section.
START and END define the location of data described by the tag."
  (append (semantic-tag name 'section :members members)
          (list start end)))

(defsubst semantic-texi-new-def-tag (name start end)
  "Create a semantic tag of class def.
NAME is the name of this definition.
START and END define the location of data described by the tag."
  (append (semantic-tag name 'def)
          (list start end)))

(defun semantic-texi-recursive-combobulate-list (sectionlist level)
  "Rearrange SECTIONLIST to be a hierarchical tag list starting at LEVEL.
Return the rearranged new list, with all remaining tags from
SECTIONLIST starting at ELT 2.  Sections not are not dealt with as soon as a
tag with greater section value than LEVEL is found."
  (let ((newl nil)
	(oldl sectionlist)
        tag
	)
    (save-excursion
      (catch 'level-jump
	(while oldl
	  (goto-char (car oldl))
	  (if (looking-at "@\\(\\w+\\)")
	      (let* ((word (match-string 1))
		     (levelmatch (assoc word texinfo-section-list))
		     text begin tmp
		     )
		;; Get out of here if there if we made it that far.
		(if (and levelmatch (<= (car (cdr levelmatch)) level))
		    (throw 'level-jump t))
		(setq begin (point))
		;; Recombobulate
		(if levelmatch
		    (progn
		      ;; When there is a match, the descriptive text
		      ;; consists of the rest of the line.
		      (goto-char (match-end 1))
		      (skip-chars-forward " \t")
		      (setq text (buffer-substring-no-properties
				  (point)
				  (progn (end-of-line) (point))))
		      ;; Next, recurse into the body to find the end.
		      (setq tmp (semantic-texi-recursive-combobulate-list
				 (cdr oldl) (car (cdr levelmatch))))
		      ;; Build a tag
                      (setq tag (semantic-texi-new-section-tag
                                 text (car tmp) begin (point))
                            newl (cons tag newl))
		      ;; continue
		      (setq oldl (cdr tmp))
		      )
		  ;; No match means we have a def*, so get the name from
		  ;; it based on the type of thingy we found.
		  (setq levelmatch (assoc word semantic-texi-name-field-list)
			tmp (or (cdr levelmatch) 1))
		  (forward-sexp tmp)
		  (skip-chars-forward " \t")
		  (setq text (buffer-substring-no-properties
			      (point)
			      (progn (forward-sexp 1) (point))))
		  ;; Seek the end of this definition
		  (goto-char begin)
		  (semantic-texi-forward-deffn)
                  (setq tag (semantic-texi-new-def-tag text begin (point))
                        newl (cons tag newl))
		  ;; continue
		  (setq oldl (cdr oldl)))
		)
	    (error "Problem finding section in semantic/texi parser"))
	  ;; (setq oldl (cdr oldl))
	  )))
    (cons (nreverse newl) oldl)))

(defun semantic-texi-forward-deffn ()
  "Move forward over one deffn type definition.
The cursor should be on the @ sign."
  (when (looking-at "@\\(\\w+\\)")
    (let* ((type (match-string 1))
	   (seek (concat "^@end\\s-+" (regexp-quote type))))
      (re-search-forward seek nil t))))

(defun semantic-texi-components (tag)
  "Return components belonging to TAG."
  (semantic-tag-get-attribute tag :members))

(defun semantic-texi-insert-foreign-tag (tag tagfile)
  "Insert TAG from a foreign buffer in TAGFILE.
Assume TAGFILE is a source buffer, and create a documentation
thingy from it using the `document' tool."
  ;; This makes sure that TAG will be in an active buffer.
  (let ((b (find-file-noselect tagfile)))
    ;; Now call the document insert thingy.
    (require 'document)
    (document-insert-texinfo tag b)))

;;;###autoload
(defun semantic-default-texi-setup ()
  "Set up a buffer for parsing of Texinfo files."
  ;; This will use our parser.
  (semantic-install-function-overrides
   '((parse-region . semantic-texi-parse-region)
     (parse-changes . semantic-texi-parse-changes)))
  (setq semantic-parser-name "TEXI"
        ;; Setup a dummy parser table to enable parsing!
        semantic-toplevel-bovine-table t
        imenu-create-index-function 'semantic-create-imenu-index
	semantic-command-separation-character "@"
	semantic-type-relation-separator-character '(":")
	semantic-symbol->name-assoc-list '((section . "Section")
					   (def . "Definition")
					   )
	semantic-imenu-expandable-token 'section
	semantic-imenu-bucketize-file nil
	semantic-imenu-bucketize-type-parts nil
	senator-step-at-start-end-tag-classes '(section)
	)
  (semantic-install-function-overrides
   '((tag-components . semantic-texi-components)
     (insert-foreign-tag . semantic-texi-insert-foreign-tag)
     )
   t)
  )

;;;###autoload
(add-hook 'texinfo-mode-hook 'semantic-default-texi-setup)


;;; Special features of Texinfo tag streams
;;
;; This section provides specialized access into texinfo files.
;; Because texinfo files often directly refer to functions and programs
;; it is useful to access the texinfo file from the C code for document
;; maintainance.
(defun semantic-texi-associated-files (&optional buffer)
  "Find texinfo files associated with BUFFER."
  (save-excursion
    (if buffer (set-buffer buffer))
    (cond ((and (fboundp 'ede-documentation-files)
                ede-minor-mode (ede-current-project))
	   ;; When EDE is active, ask it.
	   (ede-documentation-files)
	   )
	  ((and (featurep 'semanticdb) (semanticdb-minor-mode-p))
	   ;; See what texinfo files we have loaded in the database
	   (let ((tabs (oref semanticdb-current-database tables))
		 (r nil))
	     (while tabs
	       (if (eq (oref (car tabs) major-mode) 'texinfo-mode)
		   (setq r (cons (oref (car tabs) file) r)))
	       (setq tabs (cdr tabs)))
	     r))
	  (t
	   (directory-files default-directory nil "\\.texi$"))
	  )))

;; Turns out this might not be useful.
;; Delete later if that is true.
(defun semantic-texi-find-documentation (name &optional type)
  "Find the function or variable NAME of TYPE in the texinfo source.
NAME is a string representing some functional symbol.
TYPE is a string, such as \"variable\" or \"Command\" used to find
the correct definition in case NAME qualifies as several things.
When this function exists, POINT is at the definition.
If the doc was not found, an error is thrown.
Note: TYPE not yet implemented."
  (let ((f (semantic-texi-associated-files))
	stream match)
    (while (and f (not match))
      (unless stream
	(with-current-buffer (find-file-noselect (car f))
	  (setq stream (semantic-bovinate-toplevel t))))
      (setq match (semantic-find-first-tag-by-name name stream t nil))
      (when match
	(set-buffer (semantic-tag-buffer match))
	(goto-char (semantic-tag-start match)))
      (setq f (cdr f)))))

(defun semantic-texi-update-doc-from-texi (&optional tag)
  "Update the documentation in the texinfo deffn class tag TAG.
The current buffer must be a texinfo file containing TAG.
If TAG is nil, determine a tag based on the current position."
  (interactive)
  (unless (or (featurep 'semanticdb) (semanticdb-minor-mode-p))
    (error "Texinfo updating only works when `semanticdb' is being used"))
  (semantic-bovinate-toplevel t)
  (unless tag
    (beginning-of-line)
    (setq tag (semantic-current-tag)))
  (unless (semantic-tag-of-class-p tag 'def)
    (error "Only deffns (or defun or defvar) can be updated"))
  (let* ((name (semantic-tag-name tag))
	 (tags (mapcar
                #'cdr
                ;; `semanticdb-find-first-tag-by-name' returns a
                ;; list ((DB-TABLE . TOKEN) ...)
                (semanticdb-deep-find-tags-by-name name nil t)))
	 (docstring nil)
	 (doctag nil))
    (save-excursion
      (while (and tags (not docstring))
	(set-buffer (semantic-tag-buffer (car tags)))
	(unless (eq major-mode 'texinfo-mode)
	  (setq docstring (semantic-find-documentation (car tags))
		doctag (if docstring (car tags) nil)))
	(setq tags (cdr tags))))
    (unless docstring
      (error "Could not find documentation for %s" (semantic-tag-name tag)))
    ;; If we have a string, do the replacement.
    (delete-region (semantic-tag-start tag)
		   (semantic-tag-end tag))
    ;; Use useful functions from the docaument library.
    (require 'document)
    (document-insert-texinfo doctag (semantic-tag-buffer doctag))
    ))

(defun semantic-texi-update-doc-from-source (&optional tag)
  "Update the documentation for the source TAG.
The current buffer must be a non-texinfo source file containing TAG.
If TAG is nil, determine the tag based on the current position.
The current buffer must include TAG."
  (interactive)
  (when (eq major-mode 'texinfo-mode)
    (error "Not a source file"))
  (semantic-bovinate-toplevel t)
  (unless tag
    (setq tag (semantic-current-tag)))
  (unless (semantic-find-documentation tag)
    (error "Cannot find interesting documentation to use for %s"
	   (semantic-tag-name tag)))
  (let* ((name (semantic-tag-name tag))
	 (texi (semantic-texi-associated-files))
	 (doctag nil)
	 (docbuff nil))
    (while (and texi (not doctag))
      (set-buffer (find-file-noselect (car texi)))
      (setq doctag (semantic-find-first-tag-by-name
		    name (semantic-bovinate-toplevel t) t nil)
	    docbuff (if doctag (current-buffer) nil))
      (setq texi (cdr texi)))
    (unless doctag
      (error "Tag %s is not yet documented.  Use the `document' command"
             name))
    ;; Ok, we should have everything we need.  Do the deed.
    (if (get-buffer-window docbuff)
	(set-buffer docbuff)
      (switch-to-buffer docbuff))
    (goto-char (semantic-tag-start doctag))
    (delete-region (semantic-tag-start doctag)
		   (semantic-tag-end doctag))
    ;; Use useful functions from the document library.
    (require 'document)
    (document-insert-texinfo tag (semantic-tag-buffer tag))
    ))

(defun semantic-texi-update-doc (&optional tag)
  "Update the documentation for TAG.
If the current buffer is a texinfo file, then find the source doc, and
update it.  If the current buffer is a source file, then get the
documentation for this item, find the existing doc in the associated
manual, and update that."
  (interactive)
  (cond ((eq major-mode 'texinfo-mode)
	 (semantic-texi-update-doc-from-texi tag))
	(t
	 (semantic-texi-update-doc-from-source tag))))

(defun semantic-texi-goto-source (&optional tag)
  "Jump to the source for the definition in the texinfo file TAG.
If TAG is nil, it is derived from the deffn under POINT."
  (interactive)
  (unless (or (featurep 'semanticdb) (semanticdb-minor-mode-p))
    (error "Texinfo updating only works when `semanticdb' is being used"))
  (semantic-bovinate-toplevel t)
  (unless tag
    (beginning-of-line)
    (setq tag (semantic-current-tag)))
  (unless (semantic-tag-of-class-p tag 'def)
    (error "Only deffns (or defun or defvar) can be updated"))
  (let* ((name (semantic-tag-name tag))
	 (tags (mapcar
                #'cdr
                ;; `semanticdb-find-nonterminal-by-name' returns a
                ;; list ((DB-TABLE . TOKEN) ...)
                (semanticdb-deep-find-tags-by-name name nil t)))
	 (done nil)
	 )
    (save-excursion
      (while (and tags (not done))
	(set-buffer (semantic-tag-buffer (car tags)))
	(unless (eq major-mode 'texinfo-mode)
	  (switch-to-buffer (semantic-tag-buffer (car tags)))
	  (goto-char (semantic-tag-start (car tags)))
	  (setq done t))
	(setq tags (cdr tags))))))

(provide 'semantic-texi)

;;; semantic-texi.el ends here
