var page = new WebPage(), testindex = 0, loadInProgress = false;

page.onConsoleMessage = function(msg) {
  console.log(msg);
};

page.onLoadStarted = function() {
  loadInProgress = true;
  console.log("load started");
};

page.onLoadFinished = function() {
  loadInProgress = false;
  console.log("load finished");
};

var steps = [
  function() {
    //Load Login Page
    //page.open("http://localhost/");
    page.open("http://localhost:4567/oauth/connect");
  },
  function() {
    //Enter Credentials
    page.evaluate(function() {


      var form = document.getElementById("login-form");
      var i;

      //for (i=0; i < arr.length; i++) { 
        if (form.getAttribute('method') == "POST") {
          console.log("Hurray");
          form.elements["username"].value="ymjester";
          form.elements["password"].value="broadway";
          return;
        }
      //}

      //document.getElementById("user_name").value="foo";
      //document.getElementById("user_password").value="bar";
    });
  }, 
  function() {
    //Login
    page.evaluate(function() {
      var form = document.getElementById("login-form");
      var i;

      //for (i=0; i < arr.length; i++) {
        if (form.getAttribute('method') == "POST") {
          form.submit();
          return;
          //return document.querySelectorAll('html')[0].outerHTML;
        }
      //}

      //document.getElementById("login_button").click();
    });
  }, 
  function() {
    //echo page load time 
    page.evaluate(function() {
      console.log(document.querySelectorAll('html')[0].outerHTML);
    });
  }
];


interval = setInterval(function() {
  if (!loadInProgress && typeof steps[testindex] == "function") {
    console.log("step " + (testindex + 1));
    steps[testindex]();
    //page.render("images/step" + (testindex + 1) + ".png");
    testindex++;
  }
  if (typeof steps[testindex] != "function") {
    console.log("test complete!");
    phantom.exit();
  }
}, 50);