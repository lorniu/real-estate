(in-package :re)

(ql:quickload :css-lite)

(defun abs-pos (div x y w h)
  (css-lite:css ((div) ((:position "absolute")
	       (:left x) (:top y) (:width w) (:height h)))))

(defun style-firstpage ()
  (+s
   "
  body { background-color:black; }
  
  #top-menu { height:32px; background-color:#111; padding:9px 0px 0px 32px; }
  #top-menu a { color:white; background-color:#444; border-radius:3px;
    padding:4px 6px; margin-right:20px; display:block; float:left; }
  #top-menu #top-contact-link { float:right; }
  
  #search-bar { position:fixed; left:-250px; top:0px; width:250px; height:100%;
    background:transparent url(css/img/gray-bg.png) left top repeat; 
    padding:12px 10px 0px 12px; }
  #btn-toggle-search { position:absolute; right:-25px; top:45%; color:white;
    display:block; width:45px; height:45px;
    background:transparent url(css/img/search-btn.png) left top no-repeat; }
  
  .fancybox-skin { background:transparent url(css/img/gray-bg.png) 
      left top repeat !important; }

  #search-bar input,#search-bar label,#search-bar select 
      { float:left; display:block; margin-bottom:4px; }
  #search-bar label { width:100px; color:#ccc; }
  #search-bar label.label-left { clear: left; }
  #search-bar label.label-right { clear: right; }
  #search-bar input[type='checkbox'] { clear:left; }

  #fp-pics { /*height:100%;*/ }
  /*#fp-pics a img {  }*/
  .fp-estate-link img { width:150px; height:150px; margin:0px 1px 0px 1px; }
  td.td-4x a img { width:300px; height:300px; }
  
  #fp-preloader { position:absolute; left:50%; top:50%; z-index:3000; }
  
  .grid-10 { width:20%; float:left; height:100%; }
  .grid-10 a { width:100%; height:18.6%; display:block; margin:1px; }
  #view-estate { display:none; width:100%; height:100%; color:white;
    position:absolute; left:0px; top:0px;
    background:transparent url(css/img/gray-bg.png) left top repeat; }
  #e-close-btn { display:block; position:absolute; right:20px; top:20px;
    background:transparent url(css/fancybox/fancybox_sprite.png) 
      0px 0px no-repeat; width:36px; height:36px; cursor:pointer;
    z-index:6045; }
  #view-estate-inner { padding:30px 60px; }
  #view-estate #estate-main-img { width:250px; height:250px; }
  #view-estate #estate-images { width:250px; float:left; margin-right:20px; }
  #view-estate #other-imgs { width:250px; }
  #view-estate #other-imgs img { width:50px; height:50px; }
  #view-estate #estate-fields { width:250px; float:left; margin-right:20px; }
  #view-estate #estate-map-div { width:250px; float:left; height:250px;
      margin-right:20px; }
  #view-estate #single-estate-map { width:250px; height:250px; }
  
  
  
  html .fb_share_link { padding:2px 0 0 20px; height:16px; 
    background:url(http://static.ak.facebook.com/images/share/facebook_share_icon.gif?6:26981) no-repeat top left; }

  "))

(defun style-edit-estate-form ()
  "
  #edit-estate-form-div { background-color:white; }
  #edit-estate-form-div { padding:20px; }
  #edit-estate-form-div iframe { border:0; height:auto; width:auto; 
    width:400px; height:150px;
  }
  #edit-estate-map { width:300px; height:300px; }
  
  #edit-estate-form-div h4 { clear:both; }
  #edit-estate-form-div input,#edit-estate-form-div label
   ,#edit-estate-form-div select { float:left; display:block;
      margin-bottom:4px; }
  #edit-estate-form-div label { width:150px; }
  #edit-estate-form-div label.label-left { clear: left; }
  #edit-estate-form-div label.label-right { clear: right; }
  #edit-estate-form-div input[type='checkbox'] 
      { clear:left; margin-right:135px; }
  #edit-estate-form-div input[type='submit'] 
      { clear:both; }
  
  #estate-pics { clear:both; }
  ")

(defun style-pic-box-iframe()
  "
  .div-in-pic-box-iframe img { max-width:150px; height:80px; }
  ")

(defun style-contact-page()
  "
  h1 { color:white; font-size:16px; }
  .text { color:white; color:12px; }
  ")

(defun re-gen-css ()
  (+s
   (css-lite:css
     (("body") ((:height "100%")))
     (("#main-container") ((:position "absolute") (:left "0px") 
			   (:top "0px") (:width "100%" :height "100%")))
     (("#main") ((:position "absolute") (:left "0px") (:top "0px")
		 (:width "100%" :height "100%")))
     ((".grid-10") ((:width "10%") (:float "left") (:height "100%"))))
   (style-firstpage)
   (style-edit-estate-form)))