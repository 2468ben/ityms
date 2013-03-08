var user_email = "";
var user_api_token = "";
var user_token_expiry = "";
var show_login = true;
var currentTabUrl = window.location.href;
var api_baseurl = "http://www.ityms.com/api/";
var api_endpoints = ["url_posts","add_post","get_token"];
var existing_posts = [];

chrome.extension.onMessage.addListener(handleMessage);

chrome.storage.sync.get({"email":"","api_token":"","token_expiry":""}, function(response) {
	if(response.email !== "") {
		user_email = response.email;
		if(response.api_token !== "" && response.token_expiry !== "") {
			user_api_token = response.api_token;
			user_token_expiry = response.token_expiry;
			if(token_valid) { show_login = false; }
			else { login(function(response) {
				if(response.success) { show_login = false; }
			}); }
		}
	}
	//if(!show_login) { get_existing_posts(function(response) {}); }
});
	
function token_valid() { return user_token_expiry < parseInt(new Date().getTime() * 0.001, 10); }

function set_email(email) {
	user_email = email;
	chrome.storage.sync.set({"email":user_email}, function(response) {});
}
function set_api_token(token, expiry) {
	user_api_token = token;
	user_token_expiry = expiry;
	chrome.storage.sync.set({"api_token":user_api_token, "token_expiry":user_token_expiry}, function(response) {});
}
function loggedin(request, callback) {
	var logged_in = (user_email !== "" && user_api_token !== "");
	callback({success: logged_in, email: user_email});
}
function login(callback) {
	if(user_email) {
		ajaxCall("get_token", "GET", {}, function(response) { 
			if(response.token) {
				set_api_token(response.token, response.expiry);
				callback({success: true, email: user_email});
				get_existing_posts(function(response) {});
			} else { callback({success: false}); }
		});
	} else { callback({success: false}); }
}
function login_frompopup(request, callback) {
	if(request.params.email) {
		set_email(request.params.email);
		login(callback);
	}
}
function logout(request, callback) {
	set_email("");
	set_api_token("");
	existing_posts = [];
	callback({success: true});
}
function get_existing_posts(callback) {
	if(existing_posts.length > 0) { updatePostCount(callback); }
	else { ajaxCall("url_posts", "GET", {url: currentTabUrl}, function(response) { 
		if(response.posts) {
			existing_posts = response.posts;
			parseExistingPosts();
			updatePostCount(callback);
		} else { callback({success: false}); }
	}); }
}
function parseExistingPosts() {
	for (var i = 0; i < existing_posts.length; i++) {
		var post = existing_posts[i];
		var remdel = /\<del[^\/]*\/del\>/g;
		var remins = /\<ins[^\/]*\/ins\>/g;
		var remtags = /\<[^\>]*\>/g;
		var old_phrase = post.phrase_diff.replace(remins,"").replace(remtags,"");
		var new_phrase = post.phrase_diff.replace(remdel,"").replace(remtags,"");
		existing_posts[i].phrase_diff = {old_phrase: old_phrase, new_phrase: new_phrase};
	}
}
function updatePostCount(callback) {
	chrome.extension.sendMessage({meta: {command: "setBadgeText"}, params: {text: existing_posts.length.toString()}}, function(r) {});
	callback({success: true});
}
function sendPosts(callback) {
	callback({posts: existing_posts});
}
function ajaxCall(command, method, params, callback) {
	handleMessage({ meta: {method: method, command: command}, params: params}, "", callback);
}
function handleMessage(request, sender, sendResponse) {
	command = request.meta.command;
    if (command == "getSelection") { sendResponse({selectionstring: window.getSelection().toString()}); }
	else if (command == "loggedin") { loggedin(request, sendResponse); }
	else if (command == "login") { login_frompopup(request, sendResponse); }
	else if (command == "logout") { logout(request, sendResponse); }
	else if (command == "get_postcount") { get_existing_posts(sendResponse); }
	else if (command == "get_postcontents") { sendPosts(sendResponse); }
	else if (api_endpoints.indexOf(command) > -1) { call_api_check(request, sendResponse); }
	return true;
}
function call_api_check(request, callback) {
	if(token_valid) { call_api(request, callback); }
	else { login(function(response) {
		if(response.success) { call_api(request, callback); }
	}); }
}
function call_api(request, callback) {
	var params = request.params;
	params.email = user_email;
	params.api_token = btoa(user_api_token);
	params = EncodeQueryData(params);
	var requestmethod = request.meta.method;
	var url = api_baseurl + request.meta.command;
	if (requestmethod === "GET") { url = url + "?" + params; }
	var xhr = new XMLHttpRequest();
	xhr.open(requestmethod, url, true);
	if (requestmethod === "POST") { xhr.setRequestHeader("Content-type", "application/x-www-form-urlencoded"); }
	xhr.onreadystatechange = function() { if (xhr.readyState === 4) { 
		callback(xhr.responseText !== "" ? JSON.parse(xhr.responseText) : {});
	} };
	xhr.send(requestmethod === "POST" ? params : null);
}
function EncodeQueryData(data) {
   var ret = [];
   for (var d in data) { ret.push(encodeURIComponent(d) + "=" + encodeURIComponent(data[d])); }
   return ret.join("&");
}