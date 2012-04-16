 window.fbAsyncInit = function() {
      FB.init({
        appId      : app_id, // App ID
        channelUrl : '//magizhapp.cloudfoundry.com/channel.html', // Channel File
        status     : true, // check login status
        cookie     : true, // enable cookies to allow the server to access the session
        xfbml      : true,  // parse XFBML
        frictionlessRequests: true
      });

      // Additional initialization code here
    };

    // Load the SDK Asynchronously
    (function(d){
       var js, id = 'facebook-jssdk', ref = d.getElementsByTagName('script')[0];
       if (d.getElementById(id)) {return;}
       js = d.createElement('script'); js.id = id; js.async = true;
       js.src = "//connect.facebook.net/en_US/all.js";
       ref.parentNode.insertBefore(js, ref);
     }(document));



    $(".Recommend").on("click",function(event){
      var user_id = $(this).attr("uid");
      var selectButton = $(this).children(0);
      selectButton.toggleClass('icon-star-empty').toggleClass('icon-star');
      if (prevButton != null) {
        prevButton.toggleClass('icon-star-empty').toggleClass('icon-star');
      }
      prevButton = selectButton;
      candidate = user_id;
    });


    function requestCallback(response) {
        // Handle callback here
    }

    $("#invite").on("click",function(event){
        FB.ui({method: 'apprequests', message: 'Find the right job here', link: $(this).attr("mylink")},requestCallback);
    });

    $(".Recommend_to_friend").on("click",function(event){
        parent.FB.ui({
          to: parent.candidate,
          method: 'feed',
          link: $(this).attr("mylink"),
          picture: parent.site_image,
          name: $(this).val(),
          caption: 'Check out this job',
          description: 'You have been chosen as an excellent candidate for this job'
        }, function(response) {console.log("Saved as post: " + response['post_id'])});
    });
