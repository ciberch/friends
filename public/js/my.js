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
      console.log($(this).attr("uid"));
      var user_id = $(this).attr("uid");
      console.log(user_id);
      FB.ui({method: 'apprequests',
      message: 'Find the right job here',
      to: user_id,
      }, requestCallback);
    });


    function requestCallback(response) {
        // Handle callback here
    }

    $(".Recommend_to_friend").on("click",function(event){
         console.log($(this).attr("mylink"));
         FB.ui({
          method: 'send',
          name: 'Check out this awesome job',
          link: $(this).attr("mylink"),
          });
    });
