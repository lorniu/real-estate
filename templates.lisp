(ql:quickload 'cl-who)
;;(ql:quickload 'closer-mop)

;;(defpackage :re-templates
;;  (:use :common-lisp :cl-user :closer-mop :cl-who))

(in-package :re)

(defmacro html-out (&body body)
  `(cl-who:with-html-output-to-string 
       (*standard-output* nil :prologue nil :indent t)
     ,@body))

(defun html-combine (&key head body)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue t :indent t)
    (:html :xmlns "http://www.w3.org/1999/xhtml"
	   (cl-who:str head)
	   (:body (cl-who:str body)))))

(defun head (title &key css-files js-files more)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:head
     (:meta :http-equiv "Content-Type" 
	    :content "text/html; charset=utf-8")
     ;;meta cache-control/pragma tags don't work
     #|(when disable-cache
       (cl-who:htm
	(:meta :http-equiv "Pragma" :content "no-cache")
	(:meta :http-equiv "Expires" :content "-1")))|#
     (:title (cl-who:str title))
     (cl-who:str
      (if (and css-files (listp css-files))
	  (reduce #'(lambda (arg1 arg2) (+s arg1 arg2))
		  (mapcar #'(lambda (css-file) 
			      (concatenate 
			       'string 
			       "<link rel=\"stylesheet\" href=\"" 
			       css-file "\">"))
			  css-files))
	  ""))
     (cl-who:str
      (if (and js-files (listp js-files))
	  (reduce #'(lambda (arg1 arg2) 
		      (concatenate 'string arg1 arg2))
		  (mapcar 
		   #'(lambda (js-file) 
		       (concatenate 
			'string 
			"<script type=\"text/javascript\" src=\"" 
			js-file "\"></script>"))
		   js-files))
	  ""))
     (cl-who:str (smake (or more ""))))))

(defun simple-page (heading text &key (div-class "") (div-id ""))
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:div :class (+s "simple-page-div" " " div-class) :id div-id
	  (:h1 (cl-who:str heading))
	  (:div :class "text" (cl-who:str text)))))

(defmacro do-table ((rows row) &body body)
  `(labels ((do-row (,row other-rows)
	      (append 
	       (mapcar 
		#'(lambda (form) 
		    (if (symbolp form) (getf ,row form) form))
		,@body)
	       (if other-rows
		   (do-row (car other-rows) (cdr other-rows))
		   nil))))
     (do-row (car ,rows) (cdr ,rows))))

(defmacro do-table-to-s ((rows row) &body body)
  `(smake (do-table (,rows ,row) ,@body)))

(defmacro do-objects ((objs obj) &body body)
  `(labels ((do-obj (,obj other-objs)
	      (append
	       (mapcar 
		#'(lambda (form) 
		    (if (and ,obj (symbolp form))
			(slot-value ,obj form) 
			form))
		,@body)
	       (if other-objs
		   (do-obj (car other-objs) (cdr other-objs))
		   nil))))
     (do-obj (car ,objs) (cdr ,objs))))

;;;do class instance list like this:
;;;(do-objects-to-s (*companies* obj) `("<td class='name'>" name-geo "</td>"))
;;;where *companies* is a list of class instances and 'name-geo is a slot
(defmacro do-objects-to-s ((objs obj) &body body)
  `(smake (do-objects (,objs ,obj) ,@body)))

(defmacro for-each-class-slot 
    ((class-name-sym slot slot-type) &body body)
  `(labels 
       ((do-slots (slots)
	  (let* ((,slot (car slots)) 
		 (,slot-type (slot-value ,slot 'type)))
	    (append (list ,@body) 
		    (if (cdr slots) (do-slots (cdr slots)))))))
     (do-slots (closer-mop:class-slots 
		(find-class ,class-name-sym)))))

(defun script-tag (code)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:script :type "text/javascript"
	     (cl-who:str code))))

(defun style-tag (code)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:style :type "text/css"
	     (cl-who:str code))))

(defun label-input (name &key val label (type "text") (size-attr "") id
		    disabled readonly multiple)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:label :for (or id (+s "input_" name))
	    :id (+s "label_" name) :class "label-left"
	    (cl-who:str (or label name)))
    (:input :type type :id (or id (+s "input_" name))
	    :class (+s "input_" name)
	    :value (or (smake val) "")
	    :name name :size size-attr
	    :disabled disabled :readonly readonly :multiple multiple)))

(defun label-textarea (name &key val label (rows 4) (cols 20))
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:label :for (+s "textarea_" name)
	    :id (+s "label_" name) :class "label-left"
	    (cl-who:str (or label name)))
    (:textarea :id (+s "textarea_" name) :class (+s "input_" name)
	       :value (or (smake val) "") :name name
	       :rows rows :cols cols)))

(defun label-checkbox (name &key val label checked)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (htm (:input :type "checkbox" :id (+s "input_" name) :name name
		 :class (+s "input_" name) :value (or (smake val) "") 
		 :checked checked))
    (:label :for (+s "input_" name)
	    :id (+s "label_" name) :class "label-right"
	    (cl-who:str (or label name)))))

(defun label-select (name &key options val label direct-selectbox)
  "makes <label..><select><option..>*</>. if direct-selectbox is passed, 
  its inserted instead of generated select tag. options can be either 
  ((val lbl) (val lbl)), or (opt opt); on lack of lbl, opt will be used."
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:label :for (+s "select_" name)
	    :id (+s "label_" name) :class "label-left"
	    (cl-who:str (or label name)))
    (if direct-selectbox
	(cl-who:str direct-selectbox)
	(cl-who:htm 
	 (:select 
	  :class (+s "input_" name) :id (+s "input_" name) :name name
	  (loop for option in options
	     do (let ((opt-val (if (listp option) 
				   (car option) 
				   option))
		      (opt-lbl (if (listp option) 
				   (or (cadr option) (car option)) 
				   option)))
		  (if (equal opt-val val)
		      (htm (:option :value opt-val :selected "selected" 
				    (str opt-lbl)))
		      (htm (:option :value opt-val (str opt-lbl)))))))))))

(defun selectbox-from-class (&key select-name class-name value-slot 
			     label-slot not-selected-option)
  "gen <select> from class items. if passed, first item val will be not-sel.."
  (cl-who:with-html-output-to-string
      (*standard-output* nil :prologue nil :indent t)
    (:select
     :name select-name
     (if not-selected-option
	 (cl-who:htm (:option :value not-selected-option 
			      "Not Selected")))
     (loop for item in (all-of-class class-name)
	collecting 
	  (cl-who:htm (:option 
		       :value (slot-value item value-slot)
		       (cl-who:str 
			(slot-value item label-slot))))))))

(defun label-datepicker (name &key (val (get-universal-time)) label)
  (let ((value (* 1000 (unix-time-from-universal val))))
    (+s (label-input (+s "datepicker_" name) :label (or label name))
	(+s "<input type='hidden' name='" name "' "
	    " id='input_" name "' class='input_" name "' "
	    " value='" value "' />")
	(script-tag
	 (eval
	  `(ps:ps
	     (chain ($ ,(+s "#input_datepicker_" name))
		    (datepicker
		     (ps:create alt-field ,(+s "#input_" name)
				alt-format "@"
				default-date (new (-Date ,value))
				date-format "dd/mm/yy")))
	     (chain ($ ,(+s "#input_datepicker_" name))
		    (datepicker "setDate" (new (-Date ,value))))
	     ""))))))



(defun fb-like-btn (url &key (w 170) (h 35))
  (+s "<iframe src='//www.facebook.com/plugins/like.php?href=" url 
      "&amp;send=false&amp;layout=standard&amp;width=" w 
      "&amp;show_faces=false&amp;action=like&amp;colorscheme=dark&amp;" 
      "font=arial&amp;height=" h "' scrolling='no' frameborder='0' " 
      " style='border:none; overflow:hidden; width:" w "px; height:" h 
      "px;' allowTransparency='true'></iframe>"))


(defun fb-share-btn (url &key (caption "Share On Facebook"))
  (+s "<a rel='nofollow' href='http://www.facebook.com/share.php?u=" url
      "' onclick='return fbs_click()' target='_blank' class='fb_share_link'>"
      caption "</a>"))

;;sample usage: 
;;(for-each-class-slot ('foo slot type)
;;  (format nil "next slot type is: ~a" type))

;;code reuse
;;(defmacro do-table-to-s ((rows row) &body body)
;;  `(format nil "~{~a~}" ,`(labels ((do-row (,row)
;;	      (append (list ,@body)
;;		    (if (cdr ,row) (do-row (cdr ,row)) NIL ))))
;;     (do-row ,rows))))



(defun generic-css-files ()
  (list "css/smoothness/jquery-ui-1.8.21.custom.css"
	"css/reset.css" "css/elements.css" 
	"css/fancybox/jquery.fancybox.css"))

(defun generic-js-files ()
  (list "js/jquery-1.7.2.min.js" 
	"js/jquery-ui-1.8.21.custom.min.js"
	"js/jquery.fancybox.pack.js"
	"js/jquery.mousewheel.min.js"
	"formulas.js"
	"http://maps.googleapis.com/maps/api/js?key=AIzaSyDl2UEh2szaf3AjDf24cj4AFN-7a0oIUM0&sensor=false"))

;;;re-specific templates

(defun re-head (&key title (more ""))
  (head (or title "Welcome to Project RE!")
	:css-files (concatenate 'list (generic-css-files)
				(list "css/re.css" "re-gen.css"))
	:js-files (concatenate 'list (generic-js-files)
				(list "main.js"))
	:more (+s "<meta name=\"viewport\" content=\"initial-scale=1.0, user-scalable=no\" />" more)))

(defun do-menu (items-list)
  (smake (mapcar #'(lambda (item) 
		     (format nil "<a href='~a'>~a</a>"
			     (cadr item)
			     (car item)))
		 items-list)))

(defun re-header (&key lang)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:div :id "header"
	  (:div :id "header-mask")
	  (:a :href "./"
	      (:img :id "logo" :src "../css/img/logo.png"))
	  (:div :id "menu"
		(cl-who:str (do-menu (menu-items 
				      :lang lang))))
	  (if (session-value 'logged-in-p)
	      (cl-who:htm
	       (:div :id "header-account-links"
		     (:a :id "header-account-link" :href "./account"
			 "My account")
		     (:a :id "header-logout-link" :href "./logout"
			 "Logout")))
	      (cl-who:str (login-page))))))

(defun main-template (page)
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:div :id "main-container"
	  (:div :id "main"
		;;(cl-who:str (re-header :lang "en"))
		;;(cl-who:str (re-home-search-bar))
		(cl-who:str page)))))

(defun re-main (&key title body)
  (html-combine :head (re-head :title title)
		:body (+s (re-fb-root-div)
			  (main-template body))))

(defun re-fb-root-div ()
  (fb-root-div (config-value :fb-app-id)
	       :channel-file (+s (config-value :host) "/channel.html")
	       :js-code (re-fb-auth-code)))

(defun with-admin-template (content &key lang (title "Dashboard"))
  (let ((lang (or lang (default-lang))))
    (html-combine :head (re-head :title title)
		  :body
    (cl-who:with-html-output-to-string
	(*standard-output* nil :prologue nil :indent t)
      (:link :href "css/admin/css/960.css" :rel "stylesheet")
      (:link :href "css/admin/css/reset.css" :rel "stylesheet")
      (:link :href "css/admin/css/text.css" :rel "stylesheet")
      (:link :href "css/admin/css/blue.css" :rel "stylesheet")
      (cl-who:str (style-tag (style-admin-page)))
      (:div :id "wrapper" :class "container_16"
       (:div :class "grid_8" "logo")
       (:div :class "grid_8" :id "acc-box" "about")
       (:div :id "header" :class "grid_16"
	(:div :id "menu"
         (:ul :id "menu_group_main" :class "group"
	  (:li :class "first" (:a :href "admin?page=estates" 
	   (:span :class "outer" (:span :class "inner dashboard" 
	    (str (tr :real-estates lang))))))
	  (:li (:a :href "admin?page=text"
	   (:span :class "outer" (:span :class "inner content"
	    (str (tr :text-pages lang))))))
	  (:li (:a :href "admin?page=zml-apps"
	   (:span :class "outer" (:span :class "inner content"
	    (str (tr :applications lang))))))
	  (:li (:a :href "admin?page=trans"
	   (:span :class "outer" (:span :class "inner trans"
	    (str (tr :translations lang))))))
	  (:li (:a :href "admin?page=users"
	   (:span :class "outer" (:span :class "inner users"
	    (str (tr :users lang))))))
	  (:li :class "last" (:a :href "admin?page=settings"
	   (:span :class "outer" (:span :class "inner settings"
	    (str (tr :settings lang))))))
	  )))
       (:div :class  "grid_16"
	(:div :id "tabs"
	 (:div :class "container"
	  (:ul ;;(:li (:a :class "current" "Estates"))
	       ;;(:li (:a "asdasdasd"))
	       ))))
       (:div :id "content" :class "grid_16"
	     (:div :class "grid_9" (:h1 (cl-who:str title)))
	     (:div :class "clear")
	     (:div :id "content-inner"
		   (cl-who:str content)))
       (:br :class "clearfloat"))))))

(defun fb-root-div (fb-app-id &key (channel-file "") (js-code ""))
  (smake "<div id='fb-root'></div>
<script>
  // Additional JS functions here
  window.fbAsyncInit = function() {
    FB.init({
      appId      : '" fb-app-id "', // App ID
      channelUrl : '" channel-file "', // Channel File
      status     : true, // check login status
      cookie     : true, // enable cookies to allow the server to access the session
      xfbml      : true  // parse XFBML
    });

    // Additional init code here
    " js-code "

  };

  // Load the SDK asynchronously
  (function(d){
     var js, id = 'facebook-jssdk', ref = d.getElementsByTagName('script')[0];
     if (d.getElementById(id)) {return;}
     js = d.createElement('script'); js.id = id; js.async = true;
     js.src = '//connect.facebook.net/en_US/all.js';
     ref.parentNode.insertBefore(js, ref);
   }(document));
</script>"))

(defun admin-page-estates (&optional (page-num 1) (items-per-page 10))
  (cl-who:with-html-output-to-string
	(*standard-output* nil :prologue nil :indent t)
    (:table :id "box-table-a" 
     (loop for e in (all-estates-paged page-num) do 
	  (htm (:tr
		(:td (str (title-for-estate e)))
		(:td :class "td-action"
		     (:a :href (smake "edit-estate?ix-estate=" (ix-estate e))
			 "Edit"))))))
    (loop for i from 1
       to (+ 1 (/ (get-dao-count 'estate 'ix-estate) items-per-page)) do
	 (htm (:a :href (make-qs "/admin" :page "estates" :page-num i)
		  :style (str (if (equal page-num i) "color:red;" ""))
		  (str i))))))

(defun admin-page-tr (&key (lang (re-lang)))
  (html-out
    (:h1 "Editing translations for language " (str lang))
    (:table 
     :id "table-edit-tr"
     (loop for tt in (concatenate 'list (all-tr lang) 
				  ;;in-memory tr for adding new translations
		     	(list (make-instance 'tr :ix-tr 0 :lang lang))) do
       (htm 
	(:tr
	 (:td (str (keyword tt))
	      ;;allow the user to edit(see) and save in-memory tr's keyword
	      (:input :type (if (equal (ix-tr tt) 0) "text" "hidden")
		      :id (smake "tr_keyword-" (ix-tr tt))
		      :value (keyword tt)))
	 (:td (:input :type "text" :id (smake "tr_value-" (ix-tr tt))
		      :value (value tt)))
	 (:td :class "td-action"
	      (:button :type "button" :id (smake "btn_save_tr-" (ix-tr tt))
		       :class "save-btn" " " #|(str (re-tr :save))|#)
	      (:button :type "button" :id (smake "btn_remove_tr-" (ix-tr tt))
		       :class "remove-btn" " " #|(str (re-tr :remove))|#))))))
    (str
     (+s
      (style-tag "#table-edit-tr td { vertical-align:top; }")
      (script-tag
       (ps
	 ($$ "[id|='btn_save_tr']" 
	     (click (lambda ()
		(let* ((ix-tr (elt (chain ($$ this (attr "id")) 
					  (split "-")) 
				   1))
		       (keyword ($$ (+ "#tr_keyword-" ix-tr) (val)))
		       (lang (lisp lang))
		       (value ($$ (+ "#tr_value-" ix-tr) (val))))
		  (chain $ (ajax 
		  	(create url "./save-tr"
				data (create :keyword keyword
					     :lang lang
					     :value value)
				type "GET"
				data-type "json"
				success (lambda (data)
					  #|(alert (@ data ix-tr))|#
					  (alert (@ data message))
					  (document.location.reload)))))))))
	 ($$ "[id|='btn_remove_tr']" 
	     (click (lambda () 
		      (alert 6))))))))))

(defun admin-page-zml-apps (&optional (page-num 1) (items-per-page 10))
  (cl-who:with-html-output-to-string
	(*standard-output* nil :prologue nil :indent t)
    (:table :id "box-table-a" 
     (loop for e in (all-zml-apps-paged page-num) do 
	  (htm (:tr
		(:td (str (format-date "~d-~m-~Y" (date e))))
		(:td :class "td-action"
		     (:a :href (smake "view-zml-app?ix-zml-app=" (ix-zml-app e))
			 "View"))))))
    (loop for i from 1
       to (+ 1 (/ (get-dao-count 'zml-app 'zml-app) items-per-page)) do
	 (htm (:a :href (make-qs "/admin" :page "zml-apps" :page-num i)
		  :style (str (if (equal page-num i) "color:red;" ""))
		  (str i))))))

(defun user-management-page (&optional (page-num 1) (items-per-page 10))
  (cl-who:with-html-output-to-string
	(*standard-output* nil :prologue nil :indent t)
    (:table :id "box-table-a" 
     (loop for u in (all-users-paged page-num) do 
      (htm (:tr (:td (str (username u)))
		(:td :class "td-action"
		     (:a :href (smake "admin?page=user&ix-user=" (ix-user u)) 
			 "Edit"))))))
    (loop for i from 1
       to (+ 1 (/ (get-dao-count 'user 'ix-user) items-per-page)) do
	 (htm (:a :href (make-qs "/admin" :page "users" :page-num i)
		  :style (str (if (equal page-num i) "color:red;" ""))
		  (str i))))))

(defun account-page (ix-user)
  (let* ((acc-user (single-user ix-user))
	 (user-estates (estates-of-user ix-user)))
    (cl-who:with-html-output-to-string
	(*standard-output* nil :prologue nil :indent t)
      (cl-who:str (style-tag (style-account-page)))
      (:h1 (cl-who:str (+s "User: " (username acc-user))))
      (if 
       (plusp (length user-estates))
       (cl-who:htm
	(:div
	 :id "user-estates"
	 (:h2 "Real estates by you")
	 (loop for e in user-estates
	    do (cl-who:htm
		(:p (:a :href (smake "./#estate-" (ix-estate e))
			(cl-who:str (desc e)))
		    (:a :href (smake "./edit-estate?ix-estate="
				     (ix-estate e))
			"- Edit"))))))))))


(defun register-page (&key reg-token acc-type div-id)
  (let ((checked-type (if (valid-acc-type-p acc-type) 
			  acc-type "simple"))
	(id-for-div (or div-id "reg-div")))
    (cl-who:with-html-output-to-string 
	(*standard-output* nil :prologue nil :indent t)
      (cl-who:str (style-tag (style-register-page)))
      (:div 
       :id id-for-div :class "reg-div"
       (:form 
	:method "post" :action "./register-handler"
	:autocomplete "off" :enctype "multipart/form-data"
	(:h1 "Register")
	(:input :type "hidden" :name "reg-token" :value reg-token)
	(:input :type "hidden" :name "acc-type" :value checked-type)
	(cl-who:str
	 (+s
	  (label-input "usr" :label "Username:" :val "")
	  (label-input "email" :label "Email address:" :val "")
	  (label-input "pwd" :label "Password:" :type "password" :val "")
	  (label-input "confirm-pwd" :label "Confirm password:" 
		       :type "password" :val "")
	  (label-input "fname" :label "First name:" :val "")
	  (label-input "lname" :label "Last name:" :val "")
	  (if (string-equal checked-type "broker")
	      (+s 
	       (label-input "url" :label "Website:")
	       (label-input "telnum" :label "Tel:")
	       (label-input "logo" :type "file"
			    :label "Upload your logo:"))
	      "")))
	(:input :type "submit" :value "Register" :class "btn-register"))
       (:br :class "clearfloat")
       (:div (cl-who:str
	    (+s "By registering, you will have access to numerous<br>"
		"features, such as favoriting real estate properties.")))
       (:div :class "register-page-scripts-container" 
        (cl-who:str 
	(script-tag 
	 (ps:ps
	   (var cur-div-sel (lisp (+s "#" id-for-div)))
	   (chain
	    ($ cur-div-sel)
	    (find ".btn-register")
	    (unbind "click")
	    (click 
	     (lambda (e)
	       (var ret true)
	       (var msg "")
	       (when (not (input-filled (+ cur-div-sel " .input_usr")))
		 (setf ret false)
		 (+= msg (lisp (re-tr :enter-username)) "; "))
	       (when (not (input-filled (+ cur-div-sel " .input_email")))
		 (setf ret false)
		 (+= msg (lisp (re-tr :enter-email)) "; "))
	       (when (not (input-filled (+ cur-div-sel " .input_fname")))
		 (setf ret false)
		 (+= msg (lisp (re-tr :enter-first-name)) "; "))
	       (when (not (input-filled (+ cur-div-sel " .input_lname")))
		 (setf ret false)
		    (+= msg (lisp (re-tr :enter-last-name)) "; "))
	       (when (not (input-filled (+ cur-div-sel " .input_pwd")))
		 (setf ret false)
		 (+= msg (lisp (re-tr :enter-password)) "; "))
	       (when (not (input-filled (+ cur-div-sel " .input_confirm-pwd")))
		 (setf ret false)
		 (+= msg (lisp (re-tr :enter-confirm-password)) "; "))
	       (when (not (= ($$ (+ cur-div-sel " .input_pwd") (val))
			     ($$ (+ cur-div-sel " .input_confirm-pwd") (val))))
			  (setf ret false)
			  (+= msg (lisp (re-tr :passwords-dont-match)) "; "))
	       (when (not 
		      (chain (new (-reg-exp 
		      	   "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$" "gi")) 
			     (test ($$ (+ cur-div-sel " .input_email") (val)))))
			  (setf ret false)
			  (+= msg (lisp (re-tr :enter-valid-email)) "; "))
		 (if (not ret) (alert msg))
		  ret
		  )))
	   ))))))))


(defun login-page (&key (redir "/"))
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (cl-who:str (style-tag (style-login-page)))
    (:div :id "login-form-div"
	  (:div :class "warning")
	  (:form :method "post" :action "./login-handler"
		 (:input :type "hidden" :name "redir" :value redir)
		 (cl-who:str
		  (+s
		   (label-input "usr" :label (re-tr :username))
		   (label-input "pwd" :label (re-tr :password)
				:type "password")))
		 (:input :type "submit" :value (re-tr :btn-log-in))
		 (:a :href "./register" :id "reg-link-on-login-page"
		     (cl-who:str (re-tr :register-link)))))
    (cl-who:str (script-tag 
		 "
    $(function(){
      $('#reg-link-on-login-page').click(function(){
        if($('#top-reg-link').length > 0){ 
          $('#top-reg-link').click(); return false}
      });
    });
    "))))

(defun admin-login-page (&key (redir "/"))
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (cl-who:str (style-tag "@import url(css/login/login.css);"))
    (:div :id "admin-login-form-div" :class "login-screen"
      (:form :method "post" :action "./login-handler"
        (:input :type "hidden" :name "redir" :value redir)
	(:div :class "login-header" "Log in to Admin Panel")
	(:div :class "login-fields"
	  (:input :name "usr" :id "input_usr" :type "text")
	  (:input :name "pwd" :id "input_pwd" :type "password"))
	(:div :class "login-bottom"
	  (:input :type "checkbox" :id "input_remember-me")
	  (:label :class "for_checkbox" :for "input_remember-me"
	      (cl-who:str (re-tr :remember-me)))
	  (:input :type "submit" :value (re-tr :login))
	  )))
      (cl-who:str (script-tag ""))))

;;; project-specific code

(defun uneven-grid (w h &key square)
  (loop for iw from 0 to (- w 1)
     collecting
       (loop for ih from 0 to (- h 1)
	  collecting :min)));; :min :none :square

(defun fill-grid (grid bucket)
  "grid should be ret'ed by uneven-grid; 
   bucket should be (list :minimals (list ...) :squares (list ...))"
  (let ((h (length grid))
	(w (length (car grid)))
	(ret (copy-tree grid))
	(minimals (getf bucket :minimals))
	(squares (getf bucket :squares)))
    (loop for ih from 0 to (- h 1)
       do
	 (loop for iw from 0 to (- w 1)
	    do (let ((current (nth iw (nth ih ret))))
		 (case current
		   (:min (setf (nth iw (nth ih ret)) 
			       (or (pop minimals) "")))
		   (:square 
		    (setf (nth iw (nth ih ret)) 
			  (or (pop squares) "")))
		   (:none (setf (nth iw (nth ih ret)) ""))))))
    ret))

;;;old version of #fp-pics contents
#+nil(cl-who:str
      (with-re-db
	(let* 
	    ((normal-size-pics 
	      (mapcar 
	       (lambda (p) 
		 (+s 
		  "<a href='#view-estate' class='fp-estate-link' " 
		  " ixestate='" (ix-estate p) "'" 
		  " style='background:transparent url(" 
		  (linkable-pic-path p)") center center no-repeat;' " 
		  ">"
		  ;;"<img src='" (linkable-pic-path p) "' class='img-min' />" 
		  "</a>"))
	       (pics-for-firstpage)))
	     (2x2-size-pics 
	      (mapcar (lambda (p) 
			(+s  "<img src='" (linkable-pic-path p) 
			     "' class='img-sq' />"))
		      (pics-for-firstpage)))
	     (grid-width 5);;decide width based on total img count
	     (grid-height 5)
	     (grid (uneven-grid grid-width grid-height))
	     (filled-grid (fill-grid grid (list :minimals normal-size-pics 
						:squares 2x2-size-pics))))
	  (apply 
	   #'+s 
	   (loop for i from 0 to (1- (length filled-grid))
	      collecting 
		(+s "<div class='grid-10'>" 
		    (reduce #'+s (nth i filled-grid)) "</div>"))))))

(defun re-firstpage ()
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:div 
     :id "top-menu"
     (:a :href "javascript:toggleSearchBar();" :id "top-search-btn" 
	 (str (re-tr :search)))
     (if (session-value 'logged-in-p)
	 (cl-who:htm
	  (if (not (equal "simple" (acc-type (session-value 'user-authed))))
	      (cl-who:htm
	       (:a :href "./edit-estate?ix-estate=0" :id "top-add-estate-link"
		   "Upload new estate"))
	      "")
	  (:a :href "./account" :id "top-account-link" :class "fancybox.iframe" 
	      (cl-who:str (+s "Logged in as " 
			      (username (session-value 'user-authed)))))
	  (:a :href "./logout" :id "top-logout-link" (str (re-tr :log-out))))
	 (cl-who:htm	  
	  (:a :href "#reg-div" :id "top-reg-link" :class "fancybox.inline" 
	      (str (re-tr :register)))
	  (:a :href "#reg-broker-div" :id "top-reg-broker-link"
	      :class "fancybox.inline" (str (re-tr :register-as-broker)))
	  (:a :href "#login-form-div" :id "top-login-link" 
	      :class "fancybox.inline" (str (re-tr :login)))
	  ;; show-faces='false' max-rows='1' width='200'
	  "<fb:login-button id='top-fb-login-btn'></fb:login-button>"))
     (:a :href "./contact" :id "top-contact-link" :class "fancybox.iframe" 
	 (str (re-tr :contact)))
     (:a :href "./faq" :id "top-faq-link" :class "fancybox.iframe" 
	 (str (re-tr :faq))))
    (:div :id "fp-pics"
	  (:table :id "fp-pics-table" 
		  :border 0 :cellpadding 0 :cellspacing 0
		  (:tr :id "fp-pics-table-tr")))
    (:img :id "fp-preloader" :src "css/img/preloader.gif")
    (:div :id "view-estate"
	  (:a :id "e-close-btn" 
	      :href "javascript:hideEstateDiv();void(0)")
	  (:div :id "view-estate-inner"))
    (:div 
     :id "search-bar"
     (:a :href "javascript:void(0)" :id "btn-toggle-search"
	 "&nbsp;")
     (cl-who:str 
      (+s
       (if (session-value 'logged-in-p)
	   (+s
	    (label-checkbox "only-my-estates" 
			    :label "Only properties added by me")
	    (label-checkbox "only-my-favs" 
			    :label "Only my favorites"))
	   "")
       (label-select "status" :options (status-options :not-sel t)
		     :label (re-tr :status))
       (label-select "apt-type" :options (apt-type-options :not-sel t)
		     :label (re-tr :apt-type))
       (label-select "ix-country" :options (all-countries :not-sel t)
		     :label (re-tr :country) :val 1)
       (label-input "price-min" :label (re-tr :lbl-price-min) :size-attr 4)
       (label-input "price-max" :label (re-tr :lbl-price-max) :size-attr 4)
       (label-input "desired-monthly-pay" :label (re-tr :desired-monthly-pay)
		    :size-attr 6)
       (label-input "bedrooms-min" :label (re-tr :lbl-bedrooms-min) :size-attr 4)
       (label-input "bedrooms-max" :label (re-tr :lbl-bedrooms-max) :size-attr 4)
       (label-input "postcode-1" :label (re-tr :lbl-postcode-1) :size-attr 4)
       (label-input "postcode-2" :label (re-tr :lbl-postcode-2) :size-attr 4)
       (label-input "postcode-3" :label (re-tr :lbl-postcode-3) :size-attr 4)
       ))
     (:a :href "javascript:void(0);" :id "btn-toggle-adv-search"
	 (str (re-tr :more-filters)))
     (:div 
      :id "search-adv"
      (cl-who:str
       (+s 
	(label-input "bathrooms-min" :label (re-tr :lbl-bathrooms-min) :size-attr 4)
	(label-input "bathrooms-max" :label (re-tr :lbl-bathrooms-max) :size-attr 4)
	(label-checkbox "garden" :val 1 :label (re-tr :garden))
	(label-input "total-min" :label (re-tr :lbl-total-min) :size-attr 2)
	(label-input "total-max" :label (re-tr :lbl-total-max) :size-attr 3)
	(label-input "land-min" :label (re-tr :lbl-land-min) :size-attr 3)
	(label-input "land-max" :label (re-tr :lbl-land-max) :size-attr 4)
	(label-input "epc-max" :label (re-tr :lbl-epc-max) :size-attr 4)
	(label-select "constr" :options (constr-options :not-sel t)
		      :label (re-tr :construction))
	(label-checkbox "terrace" :val 1 :label (re-tr :terrace))
	(label-checkbox "building-permit" :val 1 :label (re-tr :building-permit))
	(label-select "summons" :options (summons-options :not-sel t)
		      :label (re-tr :summons))
	(label-select "preemption" :options (preemption-options :not-sel t)
		      :label (re-tr :preemption))
	(label-select "subdiv-permit" :label (re-tr :subdiv-permit)
		      :options (subdiv-permit-options :not-sel t))
	))))
    (:div :id "ajax-pages"
	  (cl-who:str 
	   (+s (register-page :acc-type "broker" :div-id "reg-broker-div")
	       (register-page)
	       (login-page)
	       (register-success-page)
	       (activation-success-page)
	       (already-activated-page))))
    (cl-who:str (script-tag (fp-search-js)))))


;;TODO: populate a grid (generated with uneven-grid) with fp-pics
#+nil(loop for img in normal-size-pics
	do (cl-who:htm 
	    (:div 
	     :class "grid-10"
	     (cl-who:str 
	      (+s "<img src='" (linkable-pic-path img) 
		  "' /><br>")))))


(defun estate-edit-form (e &key message)
  (let ((ix-estate (if (slot-boundp e 'ix-estate)
		       (ix-estate e) 0)))
    (cl-who:with-html-output-to-string 
	(*standard-output* nil :prologue nil :indent t)
      (cl-who:str (style-tag (style-edit-estate-form)))
      (:div :id "estate-form-message-div" 
	    (cl-who:str (re-tr (hunchentoot:url-decode message))))
      (:div 
       :id "edit-estate-form-div"
       (:form 
	:method :post :action "./save-estate"
	(:input :type "hidden" :name "ix-estate" :value ix-estate)
	;;not useful, because 
	(:input :type "hidden" :name "ix-main-pic" 
		:value (ix-main-pic e))
	(:input :type "hidden" :name "main-pic-uuid" 
		:id "input_main-pic-uuid" :value "")
	(:h1 "Edit real estate")
	(:div 
	 :class "edit-estate-column"
	 (cl-who:str
	  (+s 
	   (label-select "apt-type" 
			 :options (apt-type-options)
			 :val (apt-type e))
	   (label-select "status" :options (status-options)
			 :val (status e))
	   (label-input "pst-code" :val (pst-code e))
	   (label-input "munic" :val (munic e))
	   (label-select "ix-country" :options (all-countries)
			 :val (ix-country e))
	   (label-input "price" :val (price e))
	   (label-datepicker "since" :label "Date added"
	       :val (if (plusp ix-estate) (since e) (get-universal-time)))
	   (label-input "telnum" :val (telnum e))
	   (label-textarea "desc" :val (desc e) :label "Description"
			   :rows 7 :cols 66))))
	(:div 
	 :class "edit-estate-column"
	 (cl-who:str
	  (+s 
	   (label-input "bedrooms" :val (bedrooms e) :label "Bedroom count")
	   (label-input "bathrooms" :val (bathrooms e) :label "Bathroom count")
	   (label-input "total" :val (total e) :label "Total m2")
	   (label-input "land" :val (land e) :label "Land area m2")
	   (label-checkbox "terrace-p" :val 1 :checked (terrace-p e))
	   (label-checkbox "garden-p" :val 1 :checked (garden-p e))
	   (label-input "parking-lots" :val (parking-lots e))
	   (label-select "constr" :options (constr-options)
			 :val (constr e))
	   (label-checkbox "visible" :val 1 :checked (visible e)
			   :label "still selling"))))
	(:div 
	 :class "edit-estate-column"
	 (cl-who:str 
	  (+s 
	   (label-input "zmh" :label "ZMH Reference" :val ix-estate #|(zmh e)|#
			:disabled t)
	   (if (plusp ix-estate)
	       (+s (html-out 
		     (:a :href "javascript:void(0)" :id "copy-zmh-btn" 
			 :style "line-height:24px; margin-left:8px;" 
			 (:u "Copy")))
		   (script-tag (ps ($$ "#copy-zmh-btn" (click (lambda ()
	             (chain window (prompt "Copy to clipboard: Ctrl+C then Enter"
					   ($$ "#input_zmh" (val))))))))))
	       "<br class='clearfloat' />
               <div>ZMH reference will be generated after saving</div>")
	   (html-out (:br) (:h3 "Ruimtelijke Ordening")
	    (:div :id "ordening-tip"
	     (:a ;:onclick "$(\"#ordening-tip\").toggle();" :href "#"
		 :style "line-height:25px;"
		 "<b><u>Wat is dit?</u></b>")
	     (:p #|:id "ordening-tip"|# :style "display:none;padding-right:20px;"
		 "In bepaalde Vlaamse gemeenten is het verplicht bepaalde 
                  stedenbouwkundige gegevens te vermelden bij het publiceren 
                  van uw pand op het internet. Voor meer info: "
		 (:a :target "_blank" :href "http://www.ruimtelijkeordening.be/"
		     :style "color:#0066cc;"
		     "http://www.ruimtelijkeordening.be/"))
	     (:br :class "clearfloat")))
	    (script-tag (ps
	      ($$ "#ordening-tip"
		  (mouseenter (lambda () ($$ this (find "p") (show))))
		  (mouseleave (lambda () ($$ this (find "p") (hide)))))))
	   (label-checkbox "building-permit-p" :val 1 
			   :checked (building-permit-p e)
			   :label (re-tr :building-permit))
	   #+nil(label-input "destination" :val (destination e)
			:label (re-tr :destination))
	   (label-select "destination" :options (destination-options)
			 :val (destination e) :label (re-tr :destination))
	   (label-select "summons" :options (summons-options) 
			 :val (summons e) :label (re-tr :summons))
	   (label-select "preemption" :options (preemption-options)
			 :val (preemption e) :label (re-tr :preemption))
	   (label-select "subdiv-permit" :options (subdiv-permit-options)
			 :val (subdiv-permit e) :label (re-tr :subdiv-permit))
	   (html-out (:hr :style "display:block; margin:10px 30px 10px 0px; 
                                 clear:both;"))
	   (label-input "epc" :val (epc e) :label "EPC")
	   (label-input "kad-ink" :val (kad-ink e) :label "K.I."))))
	(:div 
	 :class "edit-estate-column"
	 (cl-who:str (label-input "address" :val (address e)))
	 (:h4 "write address in the box or click on the map " 
	      "to set location")
	 (:input :type "hidden" :id "loc-lat" :name "loc-lat" :value (loc-lat e))
	 (:input :type "hidden" :id "loc-lng" :name "loc-lng" :value (loc-lng e))
	 (:div :id "edit-estate-map"))
	(:br :class "clearfloat")
	(:div :id "estate-pics-container"
	      (:div :id "estate-pics")
	      (:button :id "add-estate-pic" :type "button" :class "button_grey"
		       "Add image"))
	(:input :type "submit" :value "Save")))
      (:script
       :type "text/javascript"
       (cl-who:str
	(+s (if (< 0 (length message)) 
		"$('#estate-form-message-div').show(200);" "")
	 (ps:ps
	      (defun set-main-pic (pic-uuid)
		(chain ($ "#input_main-pic-uuid") (val pic-uuid))
		false)
	      (defun next-avail-iframe-id ()
		(let ((max-id 0))
		  (chain ($ "iframe[id|='pic_iframe']")
		   (each 
		    (lambda (i el)
		      (setf max-id 
			    (-math.max 
			     max-id 
			     (aref (chain (chain ($ el) (attr "id")) 
					  (to-string) (split "-")) 1))))))
		  (+ max-id 1)))
	      (defun add-pic-box (rem-pic-uuid)
		(let ((next-id (next-avail-iframe-id)))
		  (chain 
		   ($ "#estate-pics")
		   (append 
		    (ps:who-ps-html
		     (:div :class "estate-pic" :id (+ "pic_div-" next-id)
			   (:iframe :src (+ "/estate-form-pic-box?rem-pic-uuid="
					    rem-pic-uuid)
				    :id (+ "pic_iframe-" next-id))
			   (:a :href (+ "javascript:void(0);")
			       :id (+ "set_main_pic_btn-" next-id)
			       "Set as main pic")
			   (:br)
			   (:a :href (+ "javascript:void(0);")
			       :id (+ "remove_pic_btn-" next-id)
			       "Remove pic")))))))
	      (chain ($ "#add-estate-pic")
		     (click (lambda () (add-pic-box "") false)))
	      (chain ($ "a[id|='set_main_pic_btn']")
		(live "click" (lambda ()
	          (set-main-pic (chain ($ this) 
				       (attr "rem-pic-uuid"))))))
	      (chain ($ "a[id|='remove_pic_btn']")
	        (live "click" (lambda ()
		   (let ((pic-uuid (chain ($ this) (attr "rem-pic-uuid")))
			 (pic-div-id
			   (aref (chain (chain ($ this) (attr "id")) 
					(to-string) (split "-")) 1)))
		     (chain $ (ajax 
		  	(create url "./del-pic"
				data (create :del-pic-uuid pic-uuid)
				type "GET"
				data-type "json"
				success (lambda (data)
					  ($$ (+ "#pic_div-" pic-div-id)
					      (remove))
					  (alert (@ data message))))))))))
	      (when (!= "undefined" (typeof google))
		(defvar estate-map (create-map-for-id "edit-estate-map"))
		(defvar loc-marker 
		  (create-marker "Real estate map location"
				 (new (google.maps.-lat-lng 
				       (lisp (loc-lat e)) 
				       (lisp (loc-lng e))))))
		(chain loc-marker (set-map estate-map))
		(google.maps.event.add-listener 
		 estate-map "click" 
		 (lambda (event)
		   (let ((lat (event.lat-lng.lat)) (lng (event.lat-lng.lng)))
		     (chain ($ "#loc-lat") (val lat))
		     (chain ($ "#loc-lng") (val lng))
		     (chain loc-marker
			    (set-position
			     (new (google.maps.-lat-lng lat
							lng))))
		     t)))
		(-map-marker-A-C-Combo "#input_address" "#loc-lat" "#loc-lng"
				       estate-map loc-marker))
	      );end main ps:ps
	    (smake
	     (loop for key being the hash-keys 
		of (session-value 'rem-pics)
		collecting 
		  (let ((p (gethash key (session-value 'rem-pics))))
		    (smake "addPicBox('" key "');" 
			   (if (and
				(slot-boundp p 'ix-pic)
				(= (ix-main-pic e) 
				   (ix-pic p)))
			       (smake "setMainPic('" key "');")
			       "")))))
	    ))))))

(defun estate-form-pic-box (&optional (rem-pic-uuid "") additional-img-uuid-s)
  (let ((saved-pic (gethash rem-pic-uuid (session-value 'rem-pics))))
    (cl-who:with-html-output-to-string 
	(*standard-output* nil :prologue nil :indent t)
      (cl-who:str (head "" :js-files '("/js/jquery-1.7.2.min.js")))
      (cl-who:str (style-tag  (style-pic-box-iframe)))
      (:form :action "/rem-pic" :method :post :enctype "multipart/form-data"
       :class "form-in-pic-box-iframe"
       (:div :class "div-in-pic-box-iframe"
	(:input :type "hidden" :name "rem-pic-uuid" :value rem-pic-uuid)
	(if (and saved-pic
		 (slot-boundp saved-pic 'ix-pic)
		 (plusp (ix-pic saved-pic)))
	    (cl-who:htm (:input :type "hidden" :name "ix-pic" 
				:value (ix-pic saved-pic))) 
	    (cl-who:str ""))
	(:img :src (if saved-pic (linkable-tmp-path (path saved-pic)) 
		       "/css/img/no-pic.jpg"))
	(cl-who:str 
	 (label-input "img[]" :type "file" :label "Choose Image:" 
		      :size-attr 4 :multiple t :id "input_img"))
	;;(:input :type "submit" :value "Update image")
	(:script :type "text/javascript" (cl-who:str (ps:ps
	    ;;if more than one img was uploaded, then add boxes for them
            (var more-uuids (lisp (append (list 'array) additional-img-uuid-s)))
	    (loop for one-more-uuid in more-uuids
	       do (window.parent.add-pic-box one-more-uuid))
	    ;;
	    (chain ($ "#input_img") (change (lambda ()
	    	(chain ($ ".form-in-pic-box-iframe")
		       (submit)))))
	    (when (< 0 (chain (ps:lisp rem-pic-uuid) length))
	      ;;$(window.parent.document).find("iframe").each(function(i, el){if((el.contentWindow || el.contentDocument) == window){/*here, el is the iframe#pic_iframe-3, so show a#set_main_pic_btn-3*/};});
	      (chain ($ window.parent.document)
	       (find "iframe")
	       (each (lambda (i el)
		  (when (== (or (@ el content-window)
				(@ el content-document))
			    window)
		    (let ((pic-id (aref (chain (chain ($ el) (attr "id")) 
					       (to-string) (split "-")) 1)))
		      (chain ($ el) 
			     (parents "body")
			     (find (+ "#set_main_pic_btn-" pic-id
				      "," "#remove_pic_btn-" pic-id))
			     (attr "rem-pic-uuid" (lisp rem-pic-uuid))
			     (show))))))))
	    ))))))))

(defun contact-page ()
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (cl-who:str (style-tag (style-text-page)))
    (:div :id "contact-div" :class "text-div"
      (:h1 "Contact us")
      (:div :class "text" 
	"You can contact us by calling +995 11 22 33"))))

(defun faq-page ()
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (cl-who:str (style-tag (style-text-page)))
    (:div :id "faq-div" :class "text-div"
	(:h1 "Frequently asked questions")
	(:div :class "text" 
	  "Q: What's your number? A: 277 55 59 96"))))

(defun register-success-page (&key (div-id "reg-success-div"))
  (cl-who:with-html-output-to-string 
      (*standard-output* nil :prologue nil :indent t)
    (:div 
     :class "reg-success-div" :id div-id
     (:h1 "Congratulations!")
     (:p " You can now add favorites, save them for later, and more! <br>
         <br>Click on the close button or outside this box to dismiss it. "))
    (cl-who:str (style-tag (style-register-success-page)))))

(defun activation-success-page ()
  (simple-page 
   "Activation Successful!"
   "Your account was activated successfully. <br>
    You can now log in <a href='./login'>here</a>."
   :div-id "div-activation-success"))

(defun already-activated-page ()
  (simple-page 
   "Activation Successful!"
   "Your account was activated successfully. <br>
    You can now log in <a href='./login'>here</a>."
   :div-id "div-already-activated"))


(defun zml-template (page)
  (html-combine 
   :head (head "Calculate my loan" 
	       :css-files (generic-css-files)
	       :js-files (generic-js-files)
	       :more (html-out (:link :rel "stylesheet" :href "css/zml.css")))
   :body
   (html-out
     (:div :id "zml-header"
         (:div :id "zml-header-in"
	   (:div :id "zml-menu"
	       (:a :href "/zml-home" "Home")
	       (:a :href "/zml-about" "About Zoek Mijn Lening")
	       (:a :href "/zml-express" "Express loan form")
	       (:a :href "/zml-calc" "Advanced Loan Calculator"))
	   (:div :id "zml-header-title"
	       (:a :href "/zml-contact" "Contact us"))))
     (:div :id "zml-main"
       (:div :id "zml-content"
	     (cl-who:str page))
       (:div :id "zml-footer"
	     (cl-who:str (+s
			  "Copyright 2013 &copy; Zoek Mijn Lening LLC"
			  )))
       (:br :class "clearfloat")))))

(defun loan-express-page ()
  (html-out
    (:div :class "zml-express-div"
      (:form :method "post" :action "./zml-submit-express" :id "zml-exp-form"
	(:h1 "Express loan request")
	(:br)
        (str (+s
	  (label-input "full-name" :label "Naam &amp; voornaam")
	  (label-input "postcode" :label "Postcode")
	  (label-input "phone" :label "Gsmnummer")
	  (label-input "email" :label "E-mail adres")
	  (label-input "amount" :label "Gevraagd kredietbedrag")
	  (label-datepicker "years" :label "Looptijd (aantal jaren)")
	  (label-select "formula" :label "Rente formule"
	    :options `((2.82 "1/1") (2.98 "3/3") (3.28 "5/5")
		       (3.69 "10/5") (3.89 "15/5") (4 "Vast")))
	  (label-input "interest-rate" :label "Rentevoet" :readonly t)
	  (label-input "monthly-payment" :label "Maandlast" :readonly t)))
	(str (script-tag 
	      (ps ($$ "#input_formula" 
		      (change (lambda ()
				($$ "#input_interest-rate"
				    (val ($$ this (val))))))
		      (change)))))
	(str (label-textarea "data" :label "Data"))
	(:br :class "clearfloat")
	(:input :type "hidden" :name "exp-form-result"
		   :id "input_exp-form-result" :val "")
	(:input :type :submit :value "Submit")
    ))
    (str (script-tag (ps
	   ($$ "#zml-exp-form" (submit (lambda ()
          (let ((filled ($$ "#zml-exp-form" (clone))))
	    ($$ filled 
		(find "script,button,input[type='button'],input[type='submit']")
		(remove))
	    ($$ filled (find "label") (append ":"))
	    ($$ filled (find "input")
		(each (lambda (i el)
		  ($$ el (after "<br>")
		      (after ($$ this (val)))
		      (remove)))))
	    ($$ filled (find "textarea")
		(each (lambda (i el)
		  ($$ el (after "<br><br>")
		      (after ($$ this (text)))
		      (remove)))))
	    ($$ filled (find "select")
		(each (lambda (i el)
		  ($$ el (after "<br>")
		      (after ($$ this (find "option:selected") (text)))
		      (remove)))))
	    (chain console (log (@ (elt filled 0) inner-h-t-m-l)))
	    ($$ "#input_exp-form-result"
		(val (@ (elt filled 0) inner-h-t-m-l)))
	    #|(return false)|#)))))))))

(defun loan-calc-page ()
  (+s 
   (html-out
    (:form :method "post" :action "/zml-submit-advanced" :id "zml-adv-form"
     (:h1 "Calculate monthly/yearly loan rate")
     
     (:div :class "float-left half step-1"
       (:h2 "Aankoop")
       (str (label-select "b25" :label "Aard van het pand"
           :options `(("grond" "Grond") ("appartement" "Appartement")
		      ("huis" "Huis") ("villa" "Villa")
		      ("nieuwbouw" "Nieuwbouw")
		      ("opbrengsteigendom" "Opbrengsteigendom")
		      ("andere" "Andere"))))
       (:label :for "select_b9" "Beschrijf")
       (:select :id "select_b9" :name "b9"
		(:option :value "0.11" "Grootbeschrijf 10%")
		(:option :value "0.063" "Grootbeschrijf 5%"))
       (str (+s
         (label-input "b10" :val "185000" :label "Aankoopprijs")
	 (label-input "b11" :val "0" :label "Notaris &amp; regk" :readonly t)
	 (label-input "b12" :val "0" :label "Bijkomend voor renovatie")
	 #|(label-input "b13" :val "0" :label "Kostprijs nieuwbouw (incl.btw)")|#
	 #|(label-input "b15" :val "0" :label "Subtotaal" :readonly t)|#
	 (html-out (:input :name "b15" :id "input_b15" :type "hidden" :val "0"))
	 (label-input "b16" :val "0" :label "Hypotheekkosten" :readonly t)
	 (label-input "b18" :val "0" :label "Totaal" :readonly t)
	 (label-input "b19" :val "38500" :label "Eigen inbreng")
	 (label-input "b21" :val "0" :label "Gevraagd kredietbedrag" :readonly t)
	 (html-out (:input :name "b22" :id "input_b22" :type "hidden" :val "0"))
	 #|(label-input "b22" :val "0" :readonly t
		      :label "Venale waard van het onroerend goed")|#
	 )))
     (:div :class "float-left half step-1"
       (:h3 "Klassieke lening")
       (str (+s
         (label-input "b28" :val "0" :label "Bedrag" :readonly t)
	 (label-input "b29" :val "4.2%" :label "Rentevoet")
	 (label-input "b30" :val "0" :label "Maandelijks rentevoet" :readonly t)
	 (label-select "b31" :label "Renteformule"
	   :options (list "20 jaar vast"
			  "25 jaar vast"
			  "30 jaar vast"
			  "Accordeon 15-18"
			  "Accordeon 20-25"))
	 (label-select "b32" :label "Looptijd (maanden)"
	   :options (loop for i from 10 to 30
		       collecting (list (* i 12) i)))
	 ;;(:button :type "button" :id "btn-calc" "Calculate")
	 (label-input "calc-result" :val "0" :label "Maandlast" :readonly t))))
     (:div :id "creditors_div" :class "step-2"
	   (:h2 "Kredietaanvragers")
	   (:button :type "button" :id "add_creditor_btn" 
		    :class "simple-blue-button"
		    (str (re-tr :add-creditor))))
     (:div :id "loans_div" :class "step-3"
       (:h2 "Maandelijkse lasten")
       (:table :id "loans_table" :border 1 :cellspacing 0 :cellpadding 0
         (:tr (:th "Type krediet") (:th "Bank") (:th "Ontleend bedrag") 
	      (:th "Openstaand saldo") (:th "Begindatum") (:th "Looptijd") 
	      (:th "Rentevoet %") (:th "Maandlast") (:th "Overnemen")
	      ))
       (:button :type "button" :id "add_loan_btn" :class "simple-blue-button"
		(str (re-tr :add-loan))))
     (:div :class "step-4"
	   (:h2 "Contactgegevens")
	   (str (+s #|(label-input "first-name" :label "First name")|#
		    (label-input "last-name" :label "Naam &amp; voornaam")
		    (label-input "email" :label "E-mail adres *")
		    (label-input "gsmphone" :label "Gsmnummer *")
		    #|(label-input "phone" :label "Telefoonnummer")|#
		    (label-textarea "comment" :label "Comment" 
				    :rows 10 :cols 40)))
	   (:br :class "clearfloat")
	   (:input :type "hidden" :name "adv-form-result"
		   :id "input_adv-form-result" :val "")
	   (:input :type "submit" :class "zml-home-button blue"
		   :value (re-tr :submit)))
     ))
   (script-tag
    (ps
      (defun calculate-b30 (b29)
	(- (expt (1+ b29) (/ 1 12)) 1))
      (defun calculate-loan (params)
	(let* ((b9  (parse-float (@ params b9)))
	       (b10 (parse-float (@ params b10)))
	       (b12 (parse-float (@ params b12)))
	       ;(b13 (parse-float (@ params b13)))
	       (b19 (parse-float (@ params b19)))
	       (b29 (parse-percent (@ params b29)))
	       (b32 (parse-int (@ params b32)))
	       ;;now follow the derived variables
	       (b11 (* b10 b9))
	       (b15 (+ b10 b11 b12));+ b13
	       (b16 (+ (* (- b15 b19) 0.01881234) 1200))
	       (b18 (+ b15 b16))
	       (b21 (- b18 b19))
	       (b22 (+ b10));+b13
	       (b28 b21)
	       (b30 (calculate-b30 b29))
	       (b31 "todo dropdown")
	       (b33 (- (pmt b30 b32 b28))))
	  b33))
      ($$ "#select_b9,#input_b10" 
	(change (lambda ()
          ($$ "#input_b11" 
	      (val (chain (* (parse-float ($$ "#select_b9" (val)))
			     (parse-float ($$ "#input_b10" (val))))
			  (to-fixed 2)))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b10,#input_b11,#input_b12,#input_b13" 
	(change (lambda ()
          ($$ "#input_b15" 
	      (val (chain (+ (parse-float ($$ "#input_b10" (val)))
			     (parse-float ($$ "#input_b11" (val)))
			     (parse-float ($$ "#input_b12" (val)))
			     ;;(parse-float ($$ "#input_b13" (val)))
			     )
			  (to-fixed 2)))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b15,#input_b19" 
	(change (lambda ()
          ($$ "#input_b16" 
	   (val (chain (+ 1200 (* 0.01881234
				  (- (parse-float ($$ "#input_b15" (val)))
				     (parse-float ($$ "#input_b19" (val))))))
		       (to-fixed 2)))
	   (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b15,#input_b16" 
	(change (lambda ()
          ($$ "#input_b18"
	      (val (chain (+ (parse-float ($$ "#input_b15" (val)))
			     (parse-float ($$ "#input_b16" (val))))
			  (to-fixed 2)))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b18,#input_b19"
	(change (lambda ()
          ($$ "#input_b21"
	      (val (chain (- (parse-float ($$ "#input_b18" (val)))
			     (parse-float ($$ "#input_b19" (val))))
			  (to-fixed 2)))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b10,#input_b13"
	(change (lambda ()
          ($$ "#input_b22"
	      (val (chain (+ (parse-float ($$ "#input_b10" (val)))
			     ;;(parse-float ($$ "#input_b13" (val)))
			     )
			  (to-fixed 2)))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b21"
	(change (lambda ()
          ($$ "#input_b28"
	      (val (chain (+ (parse-float ($$ "#input_b21" (val))))
			  (to-fixed 2)))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ($$ "#input_b29"
	(change (lambda ()
          ($$ "#input_b30"
	      (val (+ (* (chain (calculate-b30 (parse-percent ($$ "#input_b29" 
								  (val))))
				(to-fixed 6)) 100)
		      "%"))
	      (change)#|trigger programmatic onchange handlers|#)))
	(change))
      ;;($$ "#btn-calc" (click (lambda ()
      ($$ "#zml-content select,#zml-content input"
	(change (lambda ()
          (let ((calc-result (calculate-loan 
			      (create b9  ($$ "#select_b9" (val))
				      b10 ($$ "#input_b10" (val))
				      b12 ($$ "#input_b12" (val))
				      ;;b13 ($$ "#input_b13" (val))
				      b19 ($$ "#input_b19" (val))
				      b29 ($$ "#input_b29" (val))
				      b32 ($$ "#input_b32" (val))))))
	    ($$ "#input_calc-result" (val (chain calc-result (to-fixed 2)))))))
	(change))#|call onchange for the first time to display result|#
      ;;end of calculator, creditor name/contact info following
      (defun js-input (name &key (val ""))
	(who-ps-html 
	 (:input :type "text" :name name :id (+ "input_" name) :value val)))
      (defun js-label-input (name &key (val "") label)
	(who-ps-html 
	 (:label :for (+ "input_" name) :class "label-left"
		 (if label label name))
	 (:input :type "text" :name name :id (+ "input_" name) :value val)
	 (:br)))
      ;;edit multiple creditors
      (defun gen-creditor (cr-id)
	(who-ps-html 
	 (:div :id (+ "creditor_div-" cr-id)
	   (:h3 (+ "Kredietaanvrager " cr-id))
	   (:br)
	   (js-label-input (+ "cr_name-" cr-id) :label "Naam &amp; Voornaam *")
	   (js-label-input (+ "cr_birth-" cr-id) :label "Geboortedatum *")
       #|(js-label-input (+ "cr_regnum-" cr-id) :label "Rijksregisternummer *")|#
	   (js-label-input (+ "cr_street-" cr-id) :label "Straat &amp; nr *")
	   (js-label-input (+ "cr_city-" cr-id) :label "Gemeente *")
	   (js-label-input (+ "cr_postcode-" cr-id) :label "postcode *")
	   (:br)
	   (:label :for (+ "input_" "cr_marital-" cr-id) "Burgerlijke stand *")
	   (:select :name (+ "cr_marital-" cr-id) 
		    :id (+ "input_" "cr_marital-" cr-id)
	       (:option :value 1 "Ongehuwd")
	       (:option :value 2 "Gehuwd")
	       (:option :value 3 "Echtgescheiden")
	       (:option :value 4 "Feitelijk gescheiden")
	       (:option :value 5 "Gescheiden van tafel en bed")
	       (:option :value 6 "Samenwonend")
	       (:option :value 7 "Wettelijk samenwonend")
	       (:option :value 8 "Weduwe")
	       (:option :value 9 "Weduwnaar"))
	   (:br)
	   (:label :for (+ "input_" "cr_worker_type-" cr-id) "Worker type *")
	   (:select :name (+ "cr_worker_type-" cr-id) 
		    :id (+ "input_" "cr_worker_type-" cr-id)
	       (:option :value 1 "Arbeider") (:option :value 2 "Bediende")
	       (:option :value 3 "Vrij beroep") (:option :value 4 "Handelaar")
	       (:option :value 5 "Bedrijfsleider") (:option :value 6 "Ambtenaar")
	       (:option :value 7 "Diplomaat") (:option :value 8 "Zelfstandig"))
	   (:br)
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 1)
		 :class "worker_type_div"
	     (:label :for (+ "cr_wt_1_contract_type-" cr-id)
		     "Type contract *")
	     (:select :id (+ "input_" "cr_wt_1_contract_type-" cr-id)
		      :name (+ "cr_wt_1_contract_type-" cr-id)
		  (:option :value 1 "bepaalde duur")
		  (:option :value 2 "onbepaalde duur"))
	     (js-label-input (+ "cr_wt_1_employment_form-" cr-id)
	         :label "Indiensttreding vanaf *")
	     #|(js-label-input (+ "cr_wt_1_employer_name-" cr-id)
	         :label "Naam werkgever")|#
	     #|(js-label-input (+ "cr_wt_1_activity_type-" cr-id)
	         :label "aard van activiteit")|#
	     (:br)
	     (js-label-input (+ "cr_wt_1_net_earnings-" cr-id)
		 :label "Netto loon *")
	     (js-label-input (+ "cr_wt_1_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_1_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_1_other_income-" cr-id)
	         :label "Andere inkomsten ( eventueel bijberoep, rente,...)"))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 2)
		 :class "worker_type_div"
	     (:label :for (+ "cr_wt_2_contract_type-" cr-id)
		     "Type contract *")
	     (:select :id (+ "input_" "cr_wt_2_contract_type-" cr-id)
		      :name (+ "cr_wt_2_contract_type-" cr-id)
		  (:option :value 1 "bepaalde duur")
		  (:option :value 2 "onbepaalde duur"))
	     (js-label-input (+ "cr_wt_2_employment_form-" cr-id)
	         :label "Indiensttreding vanaf *")
	     #|(js-label-input (+ "cr_wt_2_employer_name-" cr-id)
	         :label "Naam werkgever")|#
	     #|(js-label-input (+ "cr_wt_2_activity_type-" cr-id)
	         :label "aard van activiteit")|#
	     (:br)
	     (js-label-input (+ "cr_wt_2_net_earnings-" cr-id)
		 :label "Netto loon *")
	     (js-label-input (+ "cr_wt_2_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_2_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_2_other_income-" cr-id)
	         :label "Andere inkomsten ( eventueel bijberoep, rente,...)"))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 3)
		 :class "worker_type_div"
	     (js-label-input (+ "cr_wt_3_activity_type-" cr-id)
	         :label "Aard activiteit *")
	     (js-label-input (+ "cr_wt_3_company_number-" cr-id)
	         :label "Ondernemingsnummer *")
	     #|(js-label-input (+ "cr_wt_3_start_date-" cr-id)
	         :label "Startdatum")|#
	     
	     (js-label-input (+ "cr_wt_3_last_year_annual_net_profit-" cr-id)
	         :label "Netto belastbaar inkomen *")
	     #|(js-label-input (+ "cr_wt_3_write_off-" cr-id)
		 :label "Afschrijving")|#
	     #|(js-label-input (+ "cr_wt_3_financial_costs-" cr-id)
	         :label "Financiële kosten")|#
	     
	     (js-label-input (+ "cr_wt_3_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_3_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_3_other_income-" cr-id)
	         :label "Andere inkomsten"))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 4)
		 :class "worker_type_div"
	     (js-label-input (+ "cr_wt_4_activity_type-" cr-id)
	         :label "Aard activiteit *")
	     (js-label-input (+ "cr_wt_4_btw_number-" cr-id)
	         :label "BTW - nummer *")
	     #|(js-label-input (+ "cr_wt_4_start_date-" cr-id)
	         :label "Startdatum")|#
	     (:br)
	     (js-label-input (+ "cr_wt_4_last_year_annual_net_profit-" cr-id)
	         :label "Netto belastbaar inkomen *")
	     #|(js-label-input (+ "cr_wt_4_write_off-" cr-id)
		 :label "Afschrijving")|#
	     #|(js-label-input (+ "cr_wt_4_financial_costs-" cr-id)
	         :label "Financiële kosten")|#
	     (:br)
	     (js-label-input (+ "cr_wt_4_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_4_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_4_other_income-" cr-id)
	         :label "Andere inkomsten"))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 5)
		 :class "worker_type_div"
	     #|(js-label-input (+ "cr_wt_5_company_business_type-" cr-id)
	         :label "Aard van activiteit van de vennootschap *")|#
	     #|(js-label-input (+ "cr_wt_5_begin_date-" cr-id)
	         :label "Begindatum")|#
	     (js-label-input (+ "cr_wt_5_company_number-" cr-id)
	         :label "Ondernemingsnummer *")
	     (:br)
	     (js-label-input (+ "cr_wt_5_gross_annual_salary-" cr-id)
	         :label "bruto bezoldiging p/m *")
	     (js-label-input (+ "cr_wt_5_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_5_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_5_other_income-" cr-id)
	         :label "Andere inkomsten")
	     (:br)
	     (:label :for (+ "cr_wt_5_group_insurance-" cr-id)
		     "heeft U een groepsverzekering?")
	     (:select :id (+ "input_" "cr_wt_5_group_insurance-" cr-id)
		      :name (+ "cr_wt_5_group_insurance-" cr-id)
		  (:option :value 1 "ja")
		  (:option :value 2 "neen")))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 6)
		 :class "worker_type_div"
	     (:label :for (+ "cr_wt_6_contract_type-" cr-id)
		     "Type contract *")
	     (:select :id (+ "input_" "cr_wt_6_contract_type-" cr-id)
		      :name (+ "cr_wt_6_contract_type-" cr-id)
		  (:option :value 1 "bepaalde duur")
		  (:option :value 2 "onbepaalde duur"))
	     #|(js-label-input (+ "cr_wt_6_employment_form-" cr-id)
	         :label "Indiensttreding vanaf *")|#
	     #|(js-label-input (+ "cr_wt_6_employer_name-" cr-id)
	         :label "Naam werkgever")|#
	     #|(js-label-input (+ "cr_wt_6_activity_type-" cr-id)
	         :label "aard van activiteit")|#
	     (:br)
	     (js-label-input (+ "cr_wt_6_net_earnings-" cr-id)
		 :label "Netto loon *")
	     (js-label-input (+ "cr_wt_6_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_6_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_6_other_income-" cr-id)
	         :label "Andere inkomsten ( eventueel bijberoep, rente,...)"))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 7)
		 :class "worker_type_div"
	     (:label :for (+ "cr_wt_7_contract_type-" cr-id)
		     "Type contract *")
	     (:select :id (+ "input_" "cr_wt_7_contract_type-" cr-id)
		      :name (+ "cr_wt_7_contract_type-" cr-id)
		  (:option :value 1 "bepaalde duur")
		  (:option :value 2 "onbepaalde duur"))
	     #|(js-label-input (+ "cr_wt_7_employment_form-" cr-id)
	         :label "Indiensttreding vanaf *")|#
	     #|(js-label-input (+ "cr_wt_7_employer_name-" cr-id)
	         :label "Naam werkgever")|#
	     #|(js-label-input (+ "cr_wt_7_activity_type-" cr-id)
	         :label "aard van activiteit")|#
	     (:br)
	     (js-label-input (+ "cr_wt_7_net_earnings-" cr-id)
		 :label "Netto loon *")
	     (js-label-input (+ "cr_wt_7_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     #|(js-label-input (+ "cr_wt_7_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")|#
	     (js-label-input (+ "cr_wt_7_other_income-" cr-id)
	         :label "Andere inkomsten ( eventueel bijberoep, rente,...)"))
	   (:div :id (+ "cr_worker_type_div_" cr-id "-" 8)
		 :class "worker_type_div"
	     (js-label-input (+ "cr_wt_8_activity_type-" cr-id)
	         :label "Aard activiteit *")
	     (js-label-input (+ "cr_wt_8_btw_number-" cr-id)
	         :label "BTW - nummer *")
	     (js-label-input (+ "cr_wt_8_start_date-" cr-id)
	         :label "Startdatum")
	     (:br)
	     (js-label-input (+ "cr_wt_8_last_year_annual_net_profit-" cr-id)
	         :label "Netto belastbaar inkomen *")
	     (js-label-input (+ "cr_wt_8_write_off-" cr-id)
		 :label "Afschrijving")
	     (js-label-input (+ "cr_wt_8_financial_costs-" cr-id)
	         :label "Financiële kosten")
	     (:br)
	     (js-label-input (+ "cr_wt_8_current_rental_income-" cr-id)
	         :label "Huidige huurinkomsten")
	     (js-label-input (+ "cr_wt_8_future_rental_income-" cr-id)
	         :label "Toekomstige huurinkomsten")
	     (js-label-input (+ "cr_wt_8_other_income-" cr-id)
	         :label "Andere inkomsten"))
	   )))
      ($$ "select[name|='cr_worker_type']" (live "change" (lambda ()
          (let* ((sel-wtype ($$ this (val)))
	     (id-parts (chain ($$ this (attr "id")) (split "-")))
	     (curr-cr-id (elt id-parts
			      (- (@ id-parts length) 1))))
	    ($$ (+ "div[id|='cr_worker_type_div_" curr-cr-id "']") (hide))
	    ($$ (+ "#cr_worker_type_div_" curr-cr-id "-" sel-wtype) (show))
	      ))))
      (defun next-creditor-id ()
	  (let ((retval 1))
	    (loop for i from 1 to 100 
	       do (when (= 0 (@ ($$ (+ "#creditor_div-" i)) length))
		    (setf retval i) (break)))
	    retval))
      ($$ "#add_creditor_btn" 
	(click (lambda ()
	  (let ((next-cr (next-creditor-id)))
	    ($$ "#add_creditor_btn" (before (gen-creditor next-cr)))
	    ($$ (+ "#input_cr_worker_type-" next-cr) (change)))))
	(click))
      ;;edit multiple loans
      (defun gen-loan (ln-id)
	(who-ps-html 
	 (:tr :id (+ "loan_div-" ln-id)
	   (:td (:select :name (+ "ln_type-" ln-id) 
		    :id (+ "input_" "ln_type-" ln-id)
		    (:option :value 1 "Hypothecaire lening")
		    (:option :value 2 "lening op afbetaling")
		    (:option :value 3 "verkoop op afbetaling")
		    (:option :value 4 "Kredietopening (kredietkaarten)")
		    (:option :value 5 "Leasing")))
	   (:td (js-input (+ "ln_bank-" ln-id)))
	   (:td (js-input (+ "ln_amount-" ln-id)))
	   (:td (js-input (+ "ln_outstanding-" ln-id)))
	   (:td (js-input (+ "ln_start_date-" ln-id)))
	   (:td (js-input (+ "ln_maturity-" ln-id)))
	   (:td (js-input (+ "ln_interest_rate-" ln-id)))
	   (:td (js-input (+ "ln_monthly_payment-" ln-id)))
	   (:td (:select :name (+ "ln_take_over-" ln-id) 
			 :id (+ "input_" "ln_take_over-" ln-id)
			 (:option :value 1 "Ja")
			 (:option :value 2 "Nee")))
	   (:td (:button :type "button" :id (+ "remove_loan_btn-" ln-id) "X"))
	   )))
      (defun next-loan-id ()
	  (let ((retval 1))
	    (loop for i from 1 to 100 
	       do (when (= 0 (@ ($$ (+ "#loan_div-" i)) length))
		    (setf retval i) (break)))
	    retval))
      ($$ "#add_loan_btn" 
	(click (lambda ()
          ($$ "#loans_table" (append (gen-loan (next-loan-id))))))
	(click))
      ($$ "[id|='remove_loan_btn']"
        (live "click" (lambda ()
	  (let ((loan-id (elt (chain ($$ this (attr "id")) 
				     (split "-")) 
			      1)))
	    ($$ (+ "#loan_div-" loan-id) (remove))))))
      ($$ "#zml-adv-form" (submit (lambda ()
          (let ((filled ($$ "#zml-adv-form" (clone))))
	    ($$ filled 
		(find "script,button,input[type='button'],input[type='submit']")
		(remove))
	    ($$ filled (find "label") (append ":"))
	    ($$ filled (find "input")
		(each (lambda (i el)
		  ($$ el (after "<br>")
		      (after ($$ this (val)))
		      (remove)))))
	    ($$ filled (find "textarea")
		(each (lambda (i el)
		  ($$ el (after "<br><br>")
		      (after ($$ this (text)))
		      (remove)))))
	    ($$ filled (find "select")
		(each (lambda (i el)
		  ($$ el (after "<br>")
		      (after ($$ this (find "option:selected") (text)))
		      (remove)))))
	    (chain console (log (@ (elt filled 0) inner-h-t-m-l)))
	    ($$ "#input_adv-form-result"
		(val (@ (elt filled 0) inner-h-t-m-l)))
	    #|(return false)|#))))
      #|(alert (calculate-loan (create b10 185000 b19 38500 b12 0 b13 0
				    b29 0.042 b32 360)))|#
      ))))