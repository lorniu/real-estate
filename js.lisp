(in-package :re)

(ql:quickload :parenscript)

(defpsmacro $$ (selector &body chains)
  `(chain (j-query ,selector)
      ,@chains))

(defpsmacro += (var &rest what-to-append)
      `(setf ,var (+ ,var ,@what-to-append)))

(defun re-formulas-js ()
  (ps
    (defun parse-percent (v)
      (var r (/ (parse-float (chain v (replace " " "")
				    (replace "%" "")
				    (replace "," "."))) 100))
      r)
    (lisp (financial-formulas))))

(defun re-main-js ()
  (+s 
   "
   //by default, one page = 9x4 images
   var imgsPerRow = 9;
   var imgsPerCol = 4;
   var bigImgsPerPage = 2;
   
   //ch - img count horizontally, cv - img count vertically
   function imgsNeededPerPage (ch, cv, bigImgCount){
     return ch * cv - bigImgCount * 3;
   }
   
   function imgsLoadedForNow(){
     return $('.fp-estate-link').length;
   }
   
   var currPage = 1;
   var lastPage = 1;//max. page no. that's currently loaded
   var wCarImg = 1300;//carousel image width
   var fAllowFurtherScrolling = true;

   $('html').mousewheel(function(event, delta) {
     if(fAllowFurtherScrolling){
       $('html')[0].scrollLeft -= (delta * 20);
       if(document.location.href.toString().indexOf('edit-estate') == -1){
         event.preventDefault();
       }
       //
       var carScroll = $('html')[0].scrollLeft;
       if((1 + (carScroll - carScroll%wCarImg)/wCarImg) != lastPage){
         currPage = 1 + ((carScroll - carScroll%wCarImg)/wCarImg);
         if(currPage >= lastPage){
           fAllowFurtherScrolling = false;
           loadResults({ 
             count: 3 * imgsNeededPerPage(imgsPerRow, imgsPerCol, 
                    bigImgsPerPage), 
             offset: imgsLoadedForNow(), 
             callback: function(){
               fAllowFurtherScrolling = true;
               lastPage += 3;
             }, clearPrevs: false });
         }
       }
     }
   });

   function estateIdFromArgument(a){
     var m = a.match('estate-[0-9]+');
     if(m){
       var d = m[0].toString().match('[0-9]+');
       return d ? d[0] : 0;
     }
     else{
       return 0;
     }
   }
   function linkForEstate (ix){
     return 'http://' + document.location.host + '/#estate-' + ix;
   }
  function fullLinkForSharing (link){
     return 'http://' + document.location.host + link;
   }
  
   "
   (ps:ps
     
     (defun input-filled (selector)
       (let ((input-value ($$ selector (val))))
	 (and (not (= "undefined" (typeof input-value)))
	      (< 0 (@ input-value length)))))
     
     (defun get-estate (id callback)
       (chain 
	$ (ajax
	   (create
	    url "./get-estate"
	    data (create id id)
	    data-type "json"
	    success (lambda (d)
		      (callback d))
	    error (lambda ())
	    )))
       (return false))
     
     (defun gen-estate-div (e)
       (let ((fields (@ e fields))
	     (main-pic (@ e main-pic))
	     (other-pics (@ e other-pics))
	     (can-fav (@ e can-fav))
	     (is-fav (@ e is-fav))
	     (broker-url (@ e broker-url))
	     (broker-logo (@ e broker-logo)))
	 (var div "<div>")
	 (+= div "<div id='estate-images'>")
	 (when can-fav
	   (+= div "<a id='estate-toggle-fav' href='javascript:;' class='fav-" 
	       (if is-fav "yes" "no") "' ixestate='" (@ e ix-estate) "'>" 
	       ;;(if is-fav "Favorited" "Add to favorites") 
	       "</a>"))
	 (+= div "<a href='" (@ main-pic path) 
	     "' id='estate-main-img-a' rel='estate-gallery'>" 
	     "<img id='estate-main-img' src='" (@ main-pic path) "' />" 
	     "<span class='price-overlay'>" (lisp (re-tr :price)) ": " 
	     (aref fields "price") " &euro;, " 
	     (-math.round (calculate-monthly-payment (aref fields "price")) 2)
	     "&euro;/month" "</span>" 
	     "</a>")
	 (+= div "<div id='other-imgs'>")
	 (for-in 
	  (op other-pics)
	  (let ((next-img (@ (aref other-pics op) path)))
	    (+= div "<a href='" next-img "' rel='estate-gallery'>"
		"<img src='" next-img "' /></a>")))
	 (+= div "</div>");</#other-imgs>
	 (+= div (fb-like-btn (full-link-for-sharing (@ e link))) "<br><br>")
	 (+= div (fb-share-btn (full-link-for-sharing (@ e link))) "<br><br>")
	 (+= div (tweet-btn (full-link-for-sharing (@ e link))) "<br><br>")
	 (if (< 0 (@ broker-logo length))
	     (+= div "<img src='" broker-logo "' id='estate-broker-logo' />" 
		 "<br><br>"))
	 (+= div "<a href='" broker-url "' target='_blank' class='underline'>" 
	     "Broker web-site</a>" "<br><br>")
	 (if (= "true" (@ e has-edit-link)) 
	     (+= div "<a class='view-estate-edit-link' " 
		 " href='./edit-estate?ix-estate=" (@ e ix-estate) 
		 "' >Edit estate</a>") "")
	 (if (= "true" (@ e has-edit-link)) 
	     (+= div "<a class='view-estate-remove-link' " 
		 " href='./remove-estate?ix-estate=" (@ e ix-estate) 
		 "' onclick='return confirm(\"Are you sure to delete it?\");'>"
		 "Delete estate</a>") "")
	 (+= div "</div>");</#estate-images>
	 (+= div "<div id='estate-fields'>")
	 (for-in (k fields)
		 (if (and (not (= k "desc"))
			  (not (= k "price")))
		     (+= div k ": " (aref fields k) "<br>")))
	 (+= div "</div>");</#estate-fields>
	 (+= div "<div id='estate-map-div'>")
	 (+= div "<div id='single-estate-map'>")
	 (+= div "</div>");</#estate-map>
	 (+= div "<div id='estate-desc-div'>" 
	     (aref fields "desc") "</div>")
	 (+= div "</div>");</#estate-map-div>
	 (+= div "</div>")
	 div))

     (defun fill-estate-div (estate-div)
       ($$ "#view-estate-inner" (html estate-div)))

     (defun show-estate-div ()
       ($$ "#view-estate" (show)))
     
     (defun hide-estate-div ()
       ($$ "#view-estate" (hide))
       ;;remove #estate-\d+ from the url after closing
       (if (< 0 (@ document.location.hash length))
	   (setf document.location.href 
		 (chain document.location.href
			(replace document.location.hash 
				 "#")))))
     
     (defun view-e (id)
       ($$ "#fp-preloader" (show))
       (get-estate 
	id (lambda (e)
	     (if (!= e null)
		 (progn 
		   (fill-estate-div (gen-estate-div e))
		   ($$ "#estate-main-img-a,#other-imgs > a" (fancybox))
					;($$ "" (fancybox))
		   (when (not (= "undefined" (typeof google)))
		     (defvar estate-loc (new (google.maps.-lat-lng 
					      (@ e loc-lat)
					      (@ e loc-lat))))
		     (defvar estate-map 
		       (create-map-for-id "single-estate-map"))
		     (defvar loc-marker 
		       (create-marker "Real estate map location"
				      estate-loc))
		     (chain loc-marker (set-map estate-map))
		     (chain estate-map (set-center estate-loc)))
		   ;;hide search bar just before opening estate details
		   (if f-search-open (toggle-search-bar))
		   (show-estate-div))
		 (alert "Loading estate failed, please try again."))
	     e))
       ($$ "#fp-preloader" (hide))
       (return false))

     ($$ ".fp-estate-link"
	 (live "click" (lambda () 
			 (view-e ($$ this (attr "ixestate")))
			 ;;return true so #estate-\d+ becomes current url
			 t)))
     );end ps:ps
     "
    function createMapForId (id, options){
      if('undefined' != typeof google){
    	var initPos = new google.maps.LatLng(51.209895,4.399338);
        var DefaultOptions = {
          center: initPos,
          zoom: 8,
          mapTypeId: google.maps.MapTypeId.ROADMAP
        };
        options = options || {};
        for(var argOpt in options){
            DefaultOptions[argOpt] = options[argOpt];
        }
        var map = new google.maps.Map(document.getElementById(id),
            DefaultOptions);
        return map;
      }
      else { return null; }
    }
    function createMarker(title, pos){
      var marker = new google.maps.Marker({
    	position: pos,
    	title:    title
      });
      return marker;
    }
    function MapMarkerACCombo (selInput, selLat, selLong, argMap, argMarker) {
            var geocoder = new google.maps.Geocoder();
	    $(selInput).autocomplete({
	      //This bit uses the geocoder to fetch address values
	      source: function(request, response) {
		geocoder.geocode( {'address': request.term }, 
                                  function(results, status) {
		  response($.map(results, function(item) {
		    return {
		      label:  item.formatted_address,
		      value: item.formatted_address,
		      latitude: item.geometry.location.lat(),
		      longitude: item.geometry.location.lng()
		    }
		  }));
		})
	      },
	      //This bit is executed upon selection of an address
	      select: function(event, ui) {
		$(selLat).val(ui.item.latitude);
		$(selLong).val(ui.item.longitude);
		var location = new google.maps.LatLng(ui.item.latitude, 
                                                      ui.item.longitude);
		argMarker.setPosition(location);
		argMap.setCenter(location);
	      }
	    });
		
	  //Add listener to marker for reverse geocoding
	  google.maps.event.addListener(argMarker, 'drag', function() {
	    geocoder.geocode({'latLng': argMarker.getPosition()}, 
                             function(results, status) {
	      if (status == google.maps.GeocoderStatus.OK) {
		if (results[0]) {
		  $(selInput).val(results[0].formatted_address);
		  $(selLat).val(argMarker.getPosition().lat());
		  $(selLong).val(argMarker.getPosition().lng());
		}
	      }
	    });
	  });	  
    }
    /*end function MapMarkerACCombo*/
    
    /* facebook share */
    function fbs_click() {u=location.href;t=document.title;
        window.open('http://www.facebook.com/sharer.php?u='
        + encodeURIComponent(u)+'&t='+encodeURIComponent(t),'sharer',
        'toolbar=0,status=0,width=626,height=436');return false;
    }
    /* end facebook share */
    /* generate fb like btn */
    function fbLikeBtn(arg_url){
      var url = encodeURIComponent(arg_url);
      var w = 170;
      var h = 35;
      return '<iframe src=\\'//www.facebook.com/plugins/like.php?href=' + url + '&amp;send=false&amp;layout=standard&amp;width='+ w + '&amp;show_faces=false&amp;action=like&amp;colorscheme=dark&amp;font=arial&amp;height=' + h + '\\' scrolling=\\'no\\' frameborder=\\'0\\' style=\\'border:none; overflow:hidden; width:' + w + 'px; height:' + h + 'px;\\' allowTransparency=\\'true\\'></iframe>';
    }
    /* end generate fb like btn */
    /* generate facebook share btn */
    function fbShareBtn (url, arg_caption){
      var caption = arg_caption ? arg_caption : 'Share on Facebook';
      return '<a rel=\\'nofollow\\' href=\\'http://www.facebook.com/share.php?u=' + url + '\\' onclick=\\'return fbs_click()\\' target=\\'_blank\\' class=\\'fb_share_link\\'>' + caption + '</a>';
    }
    /* end generate facebook share btn */
    
    function tweetBtn (url){
        //url is not needed;
        return \"<a href='https://twitter.com/share' class='twitter-share-button' data-lang='nl' data-related='RGCFINANCE_INFO'>Tweeten</a><script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0];if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src='//platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document,'script','twitter-wjs');</script>\";
    }
    
    "))

(defun fp-search-js ()
  (+s 
   (if (session-value 'logged-in-p) 
       (ps:ps (var ix-user (lisp (ix-user (session-value 'user-authed))))) 
       "")
   "
  var fSearchOpen = false;
  function toggleSearchBar(){
    hideEstateDiv();
    $('#search-bar').animate({ 'left' : fSearchOpen ? -272 : 0 }, 'slow');
    /*$('#top-menu').animate({ 'padding-left' : fSearchOpen ? 12 : 282 }, 
      'slow');*/
    $('#main').animate({ 'padding-left' : fSearchOpen ? 0 : 250 }, 'slow');
    fSearchOpen = !fSearchOpen;
  }
  $('#btn-toggle-search').click(function(){
    toggleSearchBar();
  });
  "
   (ps
     (defun inp-pos-val (selector)
       (let ((val ($$ selector (val))))
	 (and (< 0 (@ val length))
	      (< 0 val))))

     (defun gen-json-filter ()
       (var ff (create 
		:apt-type ($$ "#input_apt-type" (val))
		:status ($$ "#input_status" (val))
		:ix-country ($$ "#input_ix-country" (val))
		:constr ($$ "#input_counstr" (val))
		:terrace (@ (@ ($$ "#input_terrace") 0) :checked)
		:garden (@ (@ ($$ "#input_garden") 0) :checked)
		:building-permit (@ (@ ($$ "#input_building-permit") 0) 
                                    :checked)
		:summons ($$ "#input_summons" (val))
		:preemption ($$ "#input_preemption" (val))
		:subdiv-permit ($$ "#input_subdiv-permit" (val))
		))
       (if (and (< 0 ($$ "#input_only-my-estates" length))
		(@ (@ ($$ "#input_only-my-estates") 0) :checked))
	   (setf (@ ff :ix-user) 
		 (chain (@ window ix-user) (to-string))))
       (if (and (< 0 ($$ "#input_only-my-favs" length))
		(@ (@ ($$ "#input_only-my-favs") 0) :checked))
	   (setf (@ ff :only-favs-of-user) 
		 (chain (@ window ix-user) (to-string))))
       (if (inp-pos-val "#input_total-min")
	   (setf (@ ff :total-min) ($$ "#input_total-min" (val))))
       (if (inp-pos-val "#input_total-max")
	   (setf (@ ff :total-max) ($$ "#input_total-max" (val))))
       (if (inp-pos-val "#input_price-min") 
	   (setf (@ ff :price-min) ($$ "#input_price-min" (val))))
       (if (inp-pos-val "#input_price-max")
	   (setf (@ ff :price-max) ($$ "#input_price-max" (val))))
       (if (inp-pos-val "#input_desired-monthly-pay") 
	   (setf (@ ff :desired-monthly-pay) 
		 ($$ "#input_desired-monthly-pay" (val))))
       (if (inp-pos-val "#input_bedrooms-min")
	   (setf (@ ff :bedrooms-min) ($$ "#input_bedrooms-min" (val))))
       (if (inp-pos-val "#input_bedrooms-max")
	   (setf (@ ff :bedrooms-max) ($$ "#input_bedrooms-max" (val))))
       (if (inp-pos-val "#input_bathrooms-min") 
	   (setf (@ ff :bathrooms-min) ($$ "#input_bathrooms-min" (val))))
       (if (inp-pos-val "#input_bathrooms-max") 
	   (setf (@ ff :bathrooms-max) ($$ "#input_bathrooms-max" (val))))
       (if (inp-pos-val "#input_epc-max") 
	   (setf (@ ff :epc-max) ($$ "#input_epc-max" (val))))
       (if (inp-pos-val "#input_postcode-1") 
	   (setf (@ ff :postcode-1) ($$ "#input_postcode-1" (val))))
       (if (inp-pos-val "#input_postcode-2") 
	   (setf (@ ff :postcode-2) ($$ "#input_postcode-2" (val))))
       (if (inp-pos-val "#input_postcode-3") 
	   (setf (@ ff :postcode-3) ($$ "#input_postcode-3" (val))))
       ff)
     
     (defun load-results (args)
       (let* ((args (or args (create)))
	      (count (or (@ args count) (* 3 (imgs-needed-per-page 
					      imgs-per-row imgs-per-col 
					      big-imgs-per-page))))
	      (offset (or (@ args offset) 0))
	      (callback (@ args callback))
	      (clear-prevs (if (not (= "undefined" 
				       (typeof (@ args clear-prevs))))
			       (@ args clear-prevs)
			       true)))
	 ($$ "#fp-preloader" (show))
	 ($.ajax
	  (create
	   ;; ./filter works on both ht and apache, but /filter works only on ht
	   url "/filter" type :post data-type :json
	   data (create :preds (-j-s-o-n.stringify 
				(gen-json-filter))
			:short "t" 
			:count count
			:offset offset)
	   success 
	   (lambda (data)
	     ($$ "#fp-preloader" (hide))
	     ;;store received estates in es
	     (var es (new (-array)))
	     (for-in (raw-e data)
		     (chain es (push (eval (+ "(" (aref data raw-e) ")")))))
	     ;;clear existing estates
	     (if clear-prevs 
		 ($$ "#fp-pics-table-tr > td" (remove)))
	     ;;add received estates to document
	     (var tbl-def 
		  (+ "<td align='left' valign='top'>" 
		     "<table border='0' cellspacing='0' cellpadding='0'><tr>"))
	     (var tbl tbl-def)
	     (let ((img-per-row 9) (img-per-col 4)
		   (row-offset 0) (col-offset 0)
		   (this-row-skip-count 0)
		   (next-row-skip-count 0))
	       (for-in 
		(ie es)
		(when
		    (and (@ (aref es ie) ix-estate) 
			 (@ (aref es ie) main-pic))
		  (var this-pic-4x-p false)
		  (if (or (and (== col-offset 1) (== row-offset 1))
			  (and (== col-offset 5) (== row-offset 0)))
		      (setf this-pic-4x-p true))
		  (when this-pic-4x-p 
		    (+= this-row-skip-count 1)
		    ;;prepare a count of how many images to skip on next row
		    (+= next-row-skip-count 2))
		  (var td-4x-spec (if this-pic-4x-p
				      " class='td-4x' colspan='2' rowspan='2' "
				      ""))
		  (let ((e (aref es ie)))
		    (var e-pic-path (if this-pic-4x-p
					(@ (@ e main-pic) path-300x300)
					(@ (@ e main-pic) path-150x150)))
		    (var 
		     e-gen 
		     (+ "<td align='left' valign='top' " 
			td-4x-spec ">" 
			"<a href='" (@ e link) "' " 
			" class='fp-estate-link'" 
			" ixestate='" (@ e ix-estate) "'>"
			"<img src='" e-pic-path  
			"' /></a></td>"))
		    (+= tbl e-gen))
		  (+= col-offset 1)
		  ;;start new tr
		  (when (>= (+ col-offset this-row-skip-count) img-per-row) 
		    (+= tbl "</tr>")
		    (setf col-offset 0)
		    (+= row-offset 1)
		    ;;here, we are starting a new row
		    ;;on this row, skip images 2x count of this row's 4x images
		    (setf this-row-skip-count next-row-skip-count)
		    ;;ain't no big imgs on new row yet,so there's nothing to skip
		    (setf next-row-skip-count 0)
		    ;;start new table
		    (when (>= row-offset img-per-col)
		      (setf row-offset 0)
		      (+= tbl (+ "</table></div>" tbl-def)))
		    (+= tbl "<tr>"))
		  )))
	     (+= tbl "</tr></table></td>")
	     ($$ "#fp-pics-table-tr" (append tbl))
	     (if (not (= "undefined" (typeof callback)))
		 (chain callback (call))))
	   ))))

     (var timeout-on-change 0)
     ($$ "#search-bar select"
	 (change (lambda () 
		   (load-results))))

     ($$ "#search-bar input"
	 (keydown (lambda ()
		    ;;when the user types filters, update results
		    ;;but update according only to last change
		    (clear-timeout timeout-on-change)
		    (setf timeout-on-change 
			  (set-timeout 
			   (lambda ()
			     (load-results))
			   2200))
		    t)))
     ($$ "#search-bar input[type='checkbox']"
	 (change (lambda ()
		   (load-results))))
     ($$ "#btn-toggle-adv-search" 
	 (click (lambda () ($$ "#search-adv" (toggle)))))
     ($$ "body" (keydown
		 (lambda (evt)
		   ;;hide opened estate div on ESC
		   (if (== 27 evt.key-code) (hide-estate-div))
		   ;;scroll to the start on Home key
		   (when (== 36 evt.key-code) 
		       (setf (@ (aref ($ "html") 0) scroll-left) 0)
		       (setf curr-page 1))
		   t)))
     ($$ "#top-login-link" (fancybox))
     ($$ "#top-reg-link" (fancybox))
     ($$ "#top-reg-broker-link" (fancybox))
     ($$ "#top-contact-link" (fancybox))
     ($$ "#top-faq-link" (fancybox))
     ;;upon clicking on empty area in opened estate, hide it
     ($$ "#view-estate" 
	 (click (lambda (event)
		  (when (== event.target event.current-target)
		    (hide-estate-div)))))
     ($$ "#estate-toggle-fav"
	 (live "click" 
	       (lambda ()
		 ($.ajax 
		  (create 
		   url "./set-fav-handler"
		   type "post"
		   data (create 
			 ixestate ($$ this (attr "ixestate"))
			 shouldexist (if ($$ this (has-class "fav-yes"))
					  0 1))
		   data-type "json"
		   success 
		   (lambda (data)
		     (if (== (@ data result) "success")
			 (progn (alert (+ "Property "
					  (if (= (@ data action) "add-fav")
					      "favorited" 
					      "removed from favorites") "!"))
				(document.location.reload))
			 (alert (+ "Could not " 
				   (if (= (@ data action) "add-fav")
				       "add" "remove") 
				   " property to favorites!"))))
		   error (lambda () (alert (+ "Error occured while "
					      (if (= (@ data action) "add-fav")
						  "adding" "removing")
					      " property to favorites!"))))))))
     ($$ document (ready (lambda ()
			   (load-results))))
     ;;if the querystring was like /#estate-\d+, open estate with ix \d+
     (let ((arg-estate-id (estate-id-from-argument document.location.href)))
       (if (> arg-estate-id 0)
	   (view-e arg-estate-id)))
     (if (< 0 (chain document.location.href (index-of "register-success")))
	 ($$ "<a href='#reg-success-div'></a>" 
	     (fancybox (create :type "inline")) (click)))
     (if (< 0 (chain document.location.href (index-of "login")))
	 ($$ "<a href='#login-form-div'></a>" 
	     (fancybox (create :type "inline")) (click)))
     (if (< 0 (chain document.location.href (index-of "couldnt-login")))
	 ($$ "#login-form-div .warning" 
	     (html "Incorrect username or password!") 
	     (show)))
     (if (< 0 (chain document.location.href (index-of "activation-success")))
	 ($$ "<a href='#div-activation-success'></a>" 
	     (fancybox (create :type "inline")) (click)))
     (if (< 0 (chain document.location.href (index-of "already-activated")))
	 ($$ "<a href='#div-already-activated'></a>" 
	     (fancybox (create :type "inline")) (click)))
     )))

(defun re-fb-auth-code ()
  "
    // Here we subscribe to the auth.authResponseChange JavaScript event. This event is fired
  // for any authentication related change, such as login, logout or session refresh. This means that
  // whenever someone who was previously logged out tries to log in again, the correct case below 
  // will be handled. 
  FB.Event.subscribe('auth.authResponseChange', function(response) {
    // Here we specify what we do with the response anytime this event occurs. 
    if (response.status === 'connected') {
      // The response object is returned with a status field that lets the app know the current
      // login status of the person. In this case, we're handling the situation where they 
      // have logged in to the app.
      fbLoginHandler();
    } else if (response.status === 'not_authorized') {
      // In this case, the person is logged into Facebook, but not into the app, so we call
      // FB.login() to prompt them to do so. 
      // In real-life usage, you wouldn't want to immediately prompt someone to login 
      // like this, for two reasons:
      // (1) JavaScript created popup windows are blocked by most browsers unless they 
      // result from direct interaction from people using the app (such as a mouse click)
      // (2) it is a bad experience to be continually prompted to login upon page load.
      FB.login();
    } else {
      // In this case, the person is not logged into Facebook, so we call the login() 
      // function to prompt them to do so. Note that at this stage there is no indication
      // of whether they are logged into the app. If they aren't then they'll see the Login
      // dialog right after they log in to Facebook. 
      // The same caveats as above apply to the FB.login() call here.
      FB.login();
    }
  });
  
    // Here we run a very simple test of the Graph API after login is successful. 
  // This fbLoginHandler() function is only called in those cases. 
  function fbLoginHandler() {
    console.log('Welcome!  Fetching your information.... ');
    FB.api('/me', function(response) {
      console.debug(response);
      console.log('Good to see you, ' + response.name + '.');
      //TODO here:
      //1. open login div and fill the fields with local var response attributes
      //2. user should have an additional fb-id field
      //3. from here, set hidden field fb-id in login div to response.id
      //4. in the register handler set the user's fb-id field to hidden fb-id val
    });
  }
  ")