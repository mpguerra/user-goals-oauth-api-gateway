## 3Scale API Proxy with OAuth2 Authorization Code Flow hosted on Heroku

This is based on Taytay's excellent implementation of a 3scale API Proxy using Heroku: Taytay/api-proxy-3scale-heroku

Please check out his [repo](Taytay/api-proxy-3scale-heroku) for the README and basic instructions on setting this up. 

I have added some OAuth extensions on top of this to implement an API Gateway acting as an OAuth2 provider for my simple Address Book App API. I will outline how these work (as well as any additional set up steps where they differ from the original repo) and how to use them in conjunction with the example [Address Book App API](mpguerra/address-book-app-api)

Usage
---------

#### Step 1: Get 3Scale and Heroku Accounts ####

##### Step 1a: Get RedisToGo addon for Heroku #####

TODO: Instructions for installing and connecting to ReidsToGo

#### Step 2: Configure 3Scale Api Proxy and download Nginx config files ####

You will need to choose oauth authentication mode from the API Settings for Authentication Mode.

#### Step 3: Clone this repo ####

#### Step 4: Rename the generated .conf files ####

#### Step 5: Modify nginx.conf ####
Make the following mandatory modifications to the nginx.conf file:

    #1. Add this line to the top of the file
    daemon off;
    #2. replace 'listen 80;' with:
    listen ${{PORT}};
    #3. replace 'access_by_lua_file lua_tmp.lua;' with:
    access_by_lua_file nginx_3scale_access.lua;

See the sample **nginx.sample.conf** file for details, and for notes on other optional changes you can make.


Test your API proxy using an app_id and app_key you get from your 3scale control panel. More info about these credentials [here](https://support.3scale.net/howtos/api-configuration/nginx-proxy)

    $ curl http://<heroku-app-name>.herokuapp.com/v1/word/awesome.json\?app_id\=YOUR_USER_APP_ID\&app_key\=YOUR_USER_APP_KEY

    {"word":"awesome","sentiment":4}%


Credits
-------

The [OpenResty buildpack](https://github.com/leafo/heroku-openresty) did the hard Heroku work! Thanks!

Our thanks to Taylor Brown [Taytay](http://taytay.com/) for providing the base configuration and files. 

I'm Maria Pilar Guerra-Arias (aka Pili) an API Solution Engineer at [3scale](http://www.3scale.net)
