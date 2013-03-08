var enabled = false;
var badgeBGColor = [40,190,190,60];
//tellCurrentTab();
setBadgeText("");
chrome.extension.onMessage.addListener(handleMessage);
chrome.tabs.onHighlighted.addListener(function(highlightInfo) {
	//tellCurrentTab();
	setBadgeText("");
});
chrome.windows.onFocusChanged.addListener(function(windowId) {
	//tellCurrentTab();
	setBadgeText("");
});
function tellCurrentTab() {
	chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
		var enabledTab = tabs[0].url.match(/http:\/\/|https:\/\//ig) ? true : false;
		if(enabledTab) {
			setEnabled(true);
			if(tabs.length > 0 && enabledTab) { 
				chrome.tabs.sendMessage(tabs[0].id, {
				meta: { method: "GET", command: "get_postcount"}, params: {} }, function() {}); 
			} else setBadgeText("0");
		} else {
			setEnabled(false);
			setBadgeText("");
		}
	});
}
function handleMessage(request, sender, sendResponse) {
	command = request.meta.command;
    if (command == "setBadgeText") { 
		setBadgeText(request.params.text);
		sendResponse({success: true});
	}
	return true;
}
function setEnabled(onoff) {
	if(enabled != onoff) {
		enabled = onoff;
		chrome.browserAction.setPopup({popup: enabled ? "popup.html" : ""});
		chrome.browserAction.setIcon({path: enabled ? "icon.png" : "icon-disabled.png"});
	}
}
function setBadgeText(badgeText) {
	chrome.browserAction.setBadgeText({text: badgeText});
	chrome.browserAction.setBadgeBackgroundColor({color: badgeBGColor});
}