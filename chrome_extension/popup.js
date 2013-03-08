document.addEventListener('DOMContentLoaded', initialize);

var currentTabUrl = "default";
var lastClicked = "none";
var lastFindText = "";
var lastReplaceText = "";
var existing_posts = [];

function elID(id) { return document.getElementById(id); }
function toggleVis(id, onoff) { elID(id).style.display = onoff ? "" : "none";}
function setHTML(id, htmlContent) { elID(id).innerHTML = htmlContent; }
function listen(id, type, callback) { elID(id).addEventListener(type, callback, false); }
function callcode(object) { chrome.tabs.executeScript(null, object); }

function ajaxCall(command, method, params, callback) {
	chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
		if (tabs.length > 0 && currentTabUrl === "default") { currentTabUrl = tabs[0].url; }
		chrome.tabs.sendMessage(tabs[0].id, {
			meta: { method: method, command: command},
			params: params
		}, callback);
 	});
}

function gotSelection(data) {
  if(data !== null && data.selectionstring !== null) {
	   elID('original').value = data.selectionstring;
	   elID('yttm').value = data.selectionstring;
  }
}
function initialize() {
	toggleVis('logoutbutton', false);
	check_creds();
	callcode({file: "findAndReplaceDOMText.js"});
	listen('sendbutton','click',function(e) { parseFields("sendbutton"); });
	listen('previewbutton','mousedown',function (e) { parseFields("previewbutton"); } );
	listen('main','mouseup',revert);
	listen('loginbutton','click',loginclick);
	listen('logoutbutton','click',logoutclick);
	ajaxCall("getSelection", "GET", {}, function(response) { gotSelection(response); });
}
function check_creds() {
	ajaxCall("loggedin", "", {}, function(response) {
	    if(response.success) { loginStatusChange(true, response.email); }
	 });
}
function logoutclick(e) {
	ajaxCall("logout", "", {}, function(response) {
	    if(response.success) { loginStatusChange(false); }
	 });
}
function loginclick(e) {
	ajaxCall("login", "", { email: elID('email').value}, function(response) {
	    if(response.success) { loginStatusChange(true, response.email); }
		else { setHTML('flash', "Login Failed"); }
	 });
}
function loginStatusChange(in_out, email) {
	setHTML('flash', in_out ? email : "Login");
	toggleVis('emailfield', !in_out);
	toggleVis('loginbutton', !in_out);
	toggleVis('logoutbutton', in_out);
	getExistingPosts();
}
function sendPost() {
	ajaxCall("add_post", "POST", {
		 old_phrase: lastFindText, new_phrase: lastReplaceText, url: currentTabUrl
	}, function(response) { setHTML('flash', "Success: " + response.success); });
}
function getExistingPosts() {
	ajaxCall("get_postcount", "", {}, function(response) {
		ajaxCall("get_postcontents", "", {}, function(response) {
			existing_posts = response.posts;
			populate_posts();
		});
	});
}
function populate_posts() {
	var postsHTML = "";
	for (var i = 0; i < existing_posts.length; i++) {
		var post = existing_posts[i];
		var postdiv = "<button id=\"post_"+i+"\" data-oldphrase=\""+post.phrase_diff.old_phrase+
		"\" data-newphrase=\""+post.phrase_diff.new_phrase+"\">"+(i+1)+": "+post.likecount+" likes</button>";
		postsHTML += postdiv;
	}
	elID('existingposts').innerHTML = postsHTML;
	for (i = 0; i < existing_posts.length; i++) {
		listen('post_'+i, 'mousedown',onPostIDClick);
	}
}
function console_log(string) {
	callcode({code: "console.log('"+string+"');"});
}
function onPostIDClick(e) {
	var post_id = e.target.id.split("_")[1];
	var phrase_diff = existing_posts[post_id].phrase_diff;
	lastClicked = "existingpost";
	elID('original').value = phrase_diff.old_phrase;
	elID('yttm').value = phrase_diff.new_phrase;
	changeText(cleanText(phrase_diff.old_phrase), cleanText(phrase_diff.new_phrase));
}
function cleanText(startText) {
	var find1 = /(^\s+|\s+$|<[^\>]*>|javascript:|[^\w\s\'\"\.\,\;\:\-\+\=\\\?\!\@\#\$\%\&\{\}\[\]\(\)\/])/ig;
	var replace1 = '';
	var find2 = /(\'|\"|\.|\,|\;|\:|\-|\+|\=|\\|\?|\!|\@|\#|\$|\%|\&|\{|\}|\[|\]|\(|\)|\/)/g;
	var replace2 = '\\\$1';
	endText = startText; //.replace(find1,replace1).replace(find2,replace2);
	return endText;
}
function parseFields(buttonid) {
	lastClicked = buttonid;
	var findText = elID('original').value;
	if (findText !== "") { changeText(cleanText(findText),cleanText(elID('yttm').value)); }
}
function revert(e) {
	if(lastFindText !== "") {
		codestring = "var itym_matches = document.body.getElementsByClassName('itym_span'); " + 
		"for (var i = 0; i < itym_matches.length; i++) { if (itym_matches[i].innerHTML === \""+lastReplaceText+"\") itym_matches[i].innerHTML = \""+lastFindText+"\"; }";
		codestring += "findAndReplaceDOMText.revert();";
		callcode({code: codestring});
		lastFindText = "";
		lastReplaceText = "";
	}
}
function changeText(findText, replaceText) {
	var findstring = "/(\\W)("+findText+")(\\W)/ig";
	lastFindText = findText;
	lastReplaceText = replaceText;
	var codestring = "var tempspan = document.createElement('span'); tempspan.className = 'itym_span'; tempspan.style.background = '#FFFFDD'; " +
	"findAndReplaceDOMText("+findstring+", document.body, tempspan, '"+replaceText+"', 2);";
	callcode({code: codestring});
	if (lastClicked === "sendbutton") {
		sendPost();
		window.close();
	}
}