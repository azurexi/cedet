;;; inversion.el --- When you need something in version XX.XX

;;; Copyright (C) 2002, 2003 Eric M. Ludlam

;; Author: Eric M. Ludlam <zappo@gnu.org>
;; X-RCS: $Id: inversion.el,v 1.13 2003/03/02 14:04:22 zappo Exp $

;;; Code:
(defvar inversion-version "1.0beta4"
  "Current version of InVersion.")
(defvar inversion-incompatible-version "0.1alpha1"
  "An earlier release which is incompatible with this release.")

;; InVersion is free software; you can redistribute it and/or modify
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
;; Keeping track of rapidly developing software is a tough thing to
;; do, especially if you want to have co-dependent packages which all
;; move at different rates.
;;
;; This library provides a framework for specifying version numbers
;; and (as side effect) have a flexible way of getting a desired feature set.
;;
;; If you would like to use this package to satisfy dependency replace this:
;; 
;; (require 'spiffy)
;;
;; with this:
;;
;; (require 'inversion)
;; (inversion-require 'spiffy "1.0")
;;
;; If you feel the need to not throw errors, you can do this instead:
;;
;; (let ((err (inversion-test 'spiffy "1.0")))
;;    (if err (your-stuff-here)))
;;
;; If you new package (2.0) needs to make sure a load file from your
;; package is compatible, use this test:
;;
;; (if (not (inversion-reverse-test 'spiffy version-from-file))
;;       ;; Everything ok
;;       (do stuff)
;;    ;; Out of date
;;    (import-old-code))
;;
;; If you would like to make inversion optional, do this:
;;
;; (or (require 'inversion nil t)
;;     (defun inversion-test (p v)
;;       (string= v (symbol-value
;; 		  (intern-soft (concat (symbol-string p) "-version"))))))
;; 
;; Or modify to specify `inversion-require' instead.
;;
;; TODO:
;;  Offer to download newer versions of a package.

;;; History:
;; 
;; Sept 3, 2002:  First general publication.

(defvar inversion-decoder-ring
  '(
    (alpha  "^\\([0-9]+\\)\\.\\([0-9]+\\)alpha\\([0-9]+\\)$" 3)
    (beta   "^\\([0-9]+\\)\\.\\([0-9]+\\)beta\\([0-9]+\\)$" 3)
    (full   "^\\([0-9]+\\)\\.\\([0-9]+\\)$" 2)
    (point  "^\\([0-9]+\\)\\.\\([0-9]+\\)\\.\\([0-9]+\\)$" 3)
    )
  "List of regular expressions for version strings.
Each element is of the form:
  ( RELEASE-TYPE REGEXP MAX )
Where RELEASE-TYPE is a symbol specifying something like `beta'
or `alpha'.  REGEXP is the regular expression to match.
MAX is the maximum number of match-numbers in the release number.
The order of the list is important.  Least stable versions should
be first.  More stable version should be last.")

;;; Version Checking
;;
(defun inversion-decode-version (version-string)
  "Decode VERSION-STRING into an encoded list.
Return value is of the form:
  (RELEASE MAJOR MINOR ...)
where RELEASE is a symbol such as `full', or `beta'."
  (let ((ring inversion-decoder-ring)
	(result nil))
    (while (and ring (not result))
      (if (string-match (car (cdr (car ring))) version-string)
	  (let ((ver nil)
		(num-left (nth 2 (car ring)))
		(count 1))
	    (while (<= count num-left)
	      (setq ver
		    (cons (string-to-int
			   (substring version-string
				      (match-beginning count)
				      (match-end count)))
			  ver)
		    count (1+ count)))
	    (setq result
		  (cons (car (car ring))
			(nreverse ver)))
	    ))
      (setq ring (cdr ring)))
    result))

(defun inversion-package-version (package)
  "Return the decoded version for PACKAGE."
  (let ((ver (symbol-value
	      (intern-soft
	       (concat (symbol-name package)
		       "-version"))))
	(code nil))
    (unless ver
      (error "Package %S does not define %S-version"))
    ;; Decode the code
    (setq code (inversion-decode-version ver))
    (unless code
      (error "%S-version value cannot be decoded"))
    code))

(defun inversion-package-incompatibility-version (package)
  "Return the decoded incompatibility version for PACKAGE.
The incompatibility version is specified by the programmer of
a package when a package is not backward compatible.  It is
not an indication of new features or bug fixes."
  (let ((ver (symbol-value
	      (intern-soft
	       (concat (symbol-name package)
		       "-incompatible-version")))))
    (if (not ver)
	nil
      ;; Decode the code
      (inversion-decode-version ver))))

(defun inversion-recode (code)
  "Convert CODE into a string."
  (let ((r (nth 0 code))		; release-type
	(n (nth 1 code))		; main number
	(i (nth 2 code))		; first increment
	(p (nth 3 code)))		; second increment
    (cond
     ((eq r 'full)
      (setq r "" p ""))
     ((eq r 'point)
      (setq r ".")))
    (format "%s.%s%s%s" n i r p)))

(defun inversion-release-to-number (release-symbol)
  "Convert RELEASE-SYMBOL into a number."
  (let* ((ra (assoc release-symbol inversion-decoder-ring))
	 (rn (- (length inversion-decoder-ring)
		(length (member ra inversion-decoder-ring)))))
    rn))

(defun inversion-= (ver1 ver2)
  "Return non-nil if VER1 is equal to VER2."
  (equal ver1 ver2))

(defun inversion-< (ver1 ver2)
  "Return non-nil if VER1 is less than VER2."
  (let ((v1-0 (inversion-release-to-number (nth 0 ver1)))
	(v1-1 (nth 1 ver1))
	(v1-2 (nth 2 ver1))
	(v1-3 (nth 3 ver1))
	;; v2
	(v2-0 (inversion-release-to-number (nth 0 ver2)))
	(v2-1 (nth 1 ver2))
	(v2-2 (nth 2 ver2))
	(v2-3 (nth 3 ver2)))
    (or (and (= v1-0 v2-0)
	     (= v1-1 v2-1)
	     (= v1-2 v2-2)
	     v1-3 v2-3		; all or nothin if elt - is =
	     (< v1-3 v2-3))
	(and (= v1-1 v2-1)
	     (< v1-2 v2-2))
	(and (< v1-1 v2-1))
	(and (< v1-0 v2-0)
	     (= v1-1 v2-1)
	     (= v1-2 v2-2)
	     )
	)))

(defun inversion-check-version (version incompatible-version
					minimum &rest reserved)
  "Check that a given version meets the minimum requirement.
VERSION, INCOMPATIBLE-VERSION and MINIMUM are of similar format to
return entries of `inversion-decode-version', or a classic version
string.	 INCOMPATIBLE-VERSION can be nil.
RESERVED arguments are kept for a later user.
Return:
- nil if everything is ok
- 'outdated if VERSION is less than MINIMUM.
- 'incompatible if VERSION is not backward compatible with MINIMUM.
- t if the check failed."
  (let ((code (if (stringp version)
		  (inversion-decode-version version)
		version))
	(req (if (stringp minimum)
		 (inversion-decode-version minimum)
	       minimum))
	(count 0)
	)
    ;; Perform a test.
    (cond
     ((inversion-= code req)
      ;; Same version.. Yay!
      nil)
     ((inversion-< code req)
      ;; Version is too old!
      'outdated)
     ((inversion-< req code)
      ;; Newer is installed.  What to do?
      (let ((incompatible
	     (if (stringp incompatible-version)
		 (inversion-decode-version incompatible-version)
	       incompatible-version)))
	(cond
	 ((not incompatible) nil)
	 ((or (inversion-= req incompatible)
	      (inversion-< req incompatible))
	  ;; The requested version is = or < than what the package
	  ;; maintainer says is incompatible.
	  'incompatible)
	 ;; Things are ok.
	 (t nil))))
     ;; Check failed
     (t t))))

(Defun inversion-test (package minimum &rest reserved)
  "Test that PACKAGE meets the MINIMUM version requirement.
PACKAGE is a symbol, similar to what is passed to `require'.
MINIMUM is of similar format to return entries of
`inversion-decode-version', or a classic version string.
RESERVED arguments are kept for a later user.
This depends on the symbols `PACKAGE-version' and optionally
`PACKAGE-incompatible-version' being defined in PACKAGE.
Return nil if everything is ok.	 Return an error string otherwise."
  (let ((check (inversion-check-version
		(inversion-package-version package)
		(inversion-package-incompatibility-version package)
		minimum reserved)))
    (cond
     ((null check)
      ;; Same version.. Yay!
      nil)
     ((eq check 'outdated)
      ;; Version is too old!
      (format "You need to upgrade package %s to %s" package minimum))
     ((eq check 'incompatible)
      ;; Newer is installed but the requested version is = or < than
      ;; what the package maintainer says is incompatible, then throw
      ;; that error.
      (format "Package %s version is not backward compatible with %s"
	      package minimum))
     ;; Check failed
     (t "Inversion version check failed."))))

(defun inversion-reverse-test (package oldversion &rest reserved)
  "Test that PACKAGE at OLDVERSION is still compatible.
If something like a save file is loaded at OLDVERSION, this
test will identify if OLDVERSION is compatible with the current version
of PACKAGE.
PACKAGE is a symbol, similar to what is passed to `require'.
OLDVERSION is of similar format to return entries of
`inversion-decode-version', or a classic version string.
RESERVED arguments are kept for a later user.
This depends on the symbols `PACKAGE-version' and optionally
`PACKAGE-incompatible-version' being defined in PACKAGE.
Return nil if everything is ok.	 Return an error string otherwise."
  (let ((check (inversion-check-version
		(inversion-package-version package)
		(inversion-package-incompatibility-version package)
		oldversion reserved)))
    (cond
     ((null check)
      ;; Same version.. Yay!
      nil)
     ((eq check 'outdated)
      ;; Version is too old!
      (format "Package %s version %s is not compatible with current version"
	      package oldversion))
     ((eq check 'incompatible)
      ;; Newer is installed but the requested version is = or < than
      ;; what the package maintainer says is incompatible, then throw
      ;; that error.
      (format "Package %s version is not backward compatible with %s"
	      package oldversion))
     ;; Check failed
     (t "Inversion version check failed."))))

(defun inversion-require (package version file &optional directory
				  &rest reserved)
  "Declare that you need PACKAGE with at least VERSION.
PACKAGE might be found in FILE.  (See `require'.)
Throws an error if VERSION is incompatible with what is installed.
Optional argument DIRECTORY is a location where new versions of
this tool can be located.  If there is a versioning problem and
DIRECTORY is provided, inversion will offer to download the file.
Optional argument RESERVED is saved for later use."
  (require package file)
  (let ((err (inversion-test package version)))
    (when err
      (if directory
	  (inversion-download-package-ask err package directory version)
	(error err)))))
  
(defconst inversion-find-data
  '("(def\\(var\\|const\\)\\s-+%s-%s\\s-+\"\\([^\"]+\\)" 2)
  "Regexp template and match data index of a version string.")

(defun inversion-find-version (package)
  "Search for the version and incompatible version of PACKAGE.
Does not load PACKAGE nor requires that it has been previously loaded.
Search in the directories in `load-path' for a PACKAGE.el library.
Visit the file found and search for the declarations of variables or
constants `PACKAGE-version' and `PACKAGE-incompatible-version'.  The
value of these variables must be a version string.

Return a pair (VERSION-STRING . INCOMPATIBLE-VERSION-STRING) where
INCOMPATIBLE-VERSION-STRING can be nil.
Return nil when VERSION-STRING was not found."
  (let* ((file (locate-library (format "%s.el" package) t))
	 (tag (car inversion-find-data))
	 (idx (nth 1 inversion-find-data))
	 version)
    (when file
      (with-temp-buffer
	(insert-file-contents-literally file)
	(goto-char (point-min))
	(when (re-search-forward (format tag package 'version) nil t)
	  (setq version (list (match-string idx)))
	  (goto-char (point-min))
	  (when (re-search-forward
		 (format tag package 'incompatible-version) nil t)
	    (setcdr version (match-string idx))))))
    version))

(defun inversion-add-to-load-path (package minimum
					   &optional installdir
					   &rest subdirs)
  "Add the PACKAGE path to `load-path' if necessary.
MINIMUM is the minimum version requirement of PACKAGE.
Optional argument INSTALLDIR is the base directory where PACKAGE is
installed.  It defaults to `default-directory'.
SUBDIRS are PACKAGE sub-directories to add to `load-path', following
the main INSTALLDIR/PACKAGE path."
  (let ((ver (inversion-find-version package)))
    ;; If PACKAGE not found or a bad version already in `load-path',
    ;; prepend the new PACKAGE path, so it will be loaded first.
    (when (or (not ver)
	      (inversion-check-version (car ver) (cdr ver) minimum))
      (let* ((default-directory (or installdir default-directory))
	     (path (expand-file-name (format "./%s" package)))
	     subpath)
	(when (file-directory-p path)
	  ;; Add SUBDIRS
	  (while subdirs
	    (setq subpath (format "%s/%s" path (car subdirs))
		  subdirs (cdr subdirs))
	    (when (file-directory-p subpath)
	      (message "%S added to `load-path'" subpath)
	      (add-to-list 'load-path subpath)))
	  ;; Add the main path
	  (message "%S added to `load-path'" path)
	  (add-to-list 'load-path path))))))

;;; Inversion tests
;;
(defun inversion-unit-test ()
  "Test inversion to make sure it can identify different version strings."
  (interactive)
  (let ((c1 (inversion-package-version 'inversion))
	(c1i (inversion-package-incompatibility-version 'inversion))
	(c2 (inversion-decode-version "1.3alpha2"))
	(c3 (inversion-decode-version "1.3beta4"))
	(c4 (inversion-decode-version "1.3beta5"))
	(c5 (inversion-decode-version "1.3.4"))
	(c6 (inversion-decode-version "2.3alpha1")))
    (if (not (and
	      (inversion-= c1 c1)
	      (inversion-< c1i c1)
	      (inversion-< c2 c3)
	      (inversion-< c3 c4)
	      (inversion-< c4 c5)
	      (inversion-< c5 c6)
	      (inversion-< c2 c4)
	      (inversion-< c2 c5)
	      (inversion-< c2 c6)
	      (inversion-< c3 c5)
	      (inversion-< c3 c6)
	      ;; Negatives
	      (not (inversion-< c3 c2))
	      (not (inversion-< c4 c3))
	      (not (inversion-< c5 c4))
	      (not (inversion-< c6 c5))
	      ;; Test the tester on inversion
	      (not (inversion-test 'inversion inversion-version))
	      ;; Test that we throw an error
	      (inversion-test 'inversion "0.0.0")
	      (inversion-test 'inversion "1000.0")
	      ))
	(error "Inversion tests failed")
      (message "Inversion tests passed."))))

;;; URL and downloading code
;;
(defun inversion-locate-package-files (package directory &optional version)
  "Get a list of distributions of PACKAGE from DIRECTORY.
DIRECTORY can be an ange-ftp compatible filename, such as:
 \"/ftp@ftp1.sourceforge.net/pub/sourceforge/PACKAGE\"
If it is a URL, wget will be used for download.
Optional argument VERSION will restrict the list of available versions
to the file matching VERSION exactly, or nil."
;;DIRECTORY should also allow a URL:
;; \"http://ftp1.sourceforge.net/PACKAGE\"
;; but then I can get file listings easily.
  (if (symbolp package) (setq package (symbol-name package)))
  (directory-files directory t
		   (if version
		       (concat "^" package "-" version "\\>")
		     package)))

(defvar inversion-package-common-tails '( ".tar.gz"
					 ".tar"
					 ".zip"
					 ".gz"
					 )
  "Common distribution mechanisms for Emacs Lisp packages.")

(defun inversion-locate-package-files-and-split (package directory &optional version)
  "Use `inversion-locate-package-files' to get a list of PACKAGE files.
DIRECTORY is the location where distributions of PACKAGE are.
VERSION is an optional argument specifying a version to restrict to.
The return list is an alist with the version string in the CAR,
and the full path name in the CDR."
  (if (symbolp package) (setq package (symbol-name package)))
  (let ((f (inversion-locate-package-files package directory version))
	(prefix (concat (file-name-as-directory directory)
			package "-"))
	(out nil))
    (while f
      (let* ((file (car f))
	     (dist (file-name-nondirectory file))
	     (tails inversion-package-common-tails)
	     (verstring nil))
	(while (and tails (not verstring))
	  (when (string-match (concat (car tails) "$") dist)
	    (setq verstring
		  (substring dist (1+ (length package)) (match-beginning 0))))
	  (setq tails (cdr tails)))
	(if (not verstring)
	    (error "Cannot decode version for %s" dist))
	(setq out
	      (cons
	       (cons verstring file)
	       out))
	(setq f (cdr f))))
    out))

(defun inversion-download-package-ask (err package directory version)
  "Due to ERR, offer to download PACKAGE from DIRECTORY.
The package should have VERSION available for download."
  (if (symbolp package) (setq package (symbol-name package)))
  (let ((files (inversion-locate-package-files-and-split
		package directory version)))
    (if (not files)
	(error err)
      (if (not (y-or-n-p (concat err ": Download update? ")))
	  (error err)
	(let ((dest (read-directory-name (format "Download %s to: "
						 package)
					 t)))
	  (if (> (length files) 1)
	      (setq files
		    (list
		     "foo" ;; ignored
		     (read-file-name "Version to download: "
				     directory
				     files
				     t
				     (concat
				      (file-name-as-directory directory)
				      package)
				     nil))))

	  (copy-file (cdr (car files)) dest))))))

(defun inversion-upgrade-package (package &optional directory)
  "Try to upgrade PACKAGE in DIRECTORY is available."
  (interactive "sPackage to upgrade: ")
  (if (stringp package) (setq package (intern package)))
  (if (not directory)
      ;; Hope that the package maintainer specified.
      (setq directory (symbol-value (or (intern-soft
					 (concat (symbol-name package)
						 "-url"))
					(intern-soft
					 (concat (symbol-name package)
						 "-directory"))))))
  (let ((files (inversion-locate-package-files-and-split
		package directory))
	(cver (inversion-package-version package))
	(newer nil))
    (mapcar (lambda (f)
	      (if (inversion-< cver (inversion-decode-version (car f)))
		  (setq newer (cons f newer))))
	    files)
    newer
    ))

;; (inversion-upgrade-package
;;  'semantic
;;  "/ftp@ftp1.sourceforge.net:/pub/sourceforge/cedet")

;; "/ftp@ftp1.sourceforge.net:/pub/sourceforge/cedet"
(provide 'inversion)

;;; inversion.el ends here
