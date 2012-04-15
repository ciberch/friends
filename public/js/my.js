 window.fbAsyncInit = function() {
      FB.init({
        appId      : app_id, // App ID
        channelUrl : '//friends.cloudfoundry.com/channel.html', // Channel File
        status     : true, // check login status
        cookie     : true, // enable cookies to allow the server to access the session
        xfbml      : true  // parse XFBML
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
      candidate = user_id;
    });


    function requestCallback(response) {
        // Handle callback here
    }

    $(".Recommend_to_friend").on("click",function(event){
        parent.FB.ui({
          to: parent.candidate,
          method: 'feed',
          link: $(this).attr("mylink"),
          picture: parent.site_image,
          name: 'Trabaja Friends',
          caption: 'Find a Summer Job',
          description: 'You have been chosen as an excellent candidate for this job'
        }, function(response) {console.log("Saved as post: " + response['post_id'])});
    });
