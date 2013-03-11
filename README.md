ityms - I Think You Meants - live on www.ityms.com
=====

A social network for grammar police. The same core functionality of Twitter, but instead of just 140 characters, you share three things:

1. The URL of the offending web page
2. The phrase with the grammar/spelling/whatever mistake
3. What the phrase should actually read

The code includes a Sinatra site, plus a Chrome extension for previewing/adding/seeing these "ityms" live on web pages.

This is a simple site on purpose. The only javascript used is for double-checking forms and degrades gracefully so interaction is straightforward.

This is a fast site for being on Heroku's free plan. It uses Redis so even though I avoided AJAX, the backend is very quick. 

I wrote the signup/login/security and other user flows on purpose too, to better understand a right way of doing things from scratch. I have used gems and frameworks for those flows, but this is to show I understand the fundamentals.

My last goal (and this is an exercise, not an excuse) is to make all of the code clear without comments, and I'd like help making sure of that. So if there's code that you think are unclear (and/or have suggestions to improve it without adding comments) then please comment, message or issue a pull request.


So, to recap:
   Site for grammar police, acts like Twitter + Find/Replace
   Sinatra+Redis, designed to be simple, fast, almost from scratch and so clear the code doesn't need documentation.

Sadly this is my only open source repo because I mostly work on "valuable" code that can't be released. So please critique my one "valueless" little toddler of a site. 

-Ben Donaldson
