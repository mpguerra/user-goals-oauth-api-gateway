## 3Scale API Proxy with OAuth2 Authorization Code Flow hosted on Heroku

This is based on Taytay's excellent implementation of a 3scale API Proxy using Heroku: Taytay/api-proxy-3scale-heroku

Please check out his [repo](Taytay/api-proxy-3scale-heroku) for the README and basic instructions on setting this up. 

I have added some OAuth extensions on top of this to implement an API Gateway acting as an OAuth2 provider for a simple Address Book App API. I will outline how these work (as well as any additional set up steps where they differ from the original repo) using the [Address Book App API](mpguerra/address-book-app-api) as an example API. 

Usage
---------

#### Step 1: Get 3Scale and Heroku Accounts ####

##### Step 1a: Get RedisToGo addon for Heroku #####

The 3scale Nginx OAuth2 extension requires redis to be installed on the nginx server so we need to add Redis to our Heroku instance and modify the redis connection code to access the Redis instance. In my case I used RedisToGo since it was the only redis addon that offers a free option. 

#### Step 2: Configure 3Scale Api Proxy and download Nginx config files ####

You will need to choose oauth authentication mode from the API Settings for Authentication Mode. The following How To explains how to set this up for OAuth: https://support.3scale.net/howtos/api-configuration#oauth-nginx-proxy

#### Step 3: Clone this repo ####

#### Step 4: Rename the generated .conf files ####

Personally I renamed mine to nginx.conf and nginx.lua, but you can call them anything you like as long as you refer to them correctly where necessary (e.g in nginx.conf )

#### Step 5: Modify nginx.conf ####
Make the following mandatory modifications to the nginx.conf file:

#1. Add this line to the top of the file
    daemon off;
#2. Add this line to make the REDISTOGO_URL environment variable available to the .lua files
    env REDISTOGO_URL;    
#2. replace 'listen 80;' with:
    listen ${{PORT}};
#3. replace 'access_by_lua_file lua_tmp.lua;' with:
    access_by_lua_file nginx.lua;

See the sample **nginx.sample.conf** file for details, and for notes on other optional changes you can make.


Test your API proxy using an app_id and app_key you get from your 3scale control panel. More info about these credentials [here](https://support.3scale.net/howtos/api-configuration/nginx-proxy)

    $ curl http://<heroku-app-name>.herokuapp.com/v1/word/awesome.json\?app_id\=YOUR_USER_APP_ID\&app_key\=YOUR_USER_APP_KEY

    {"word":"awesome","sentiment":4}%

Motivation
--------

There were a couple of ideas behind this API Gateway implementation: 

1. To have an API Gateway that acts as an OAuth2 provider running on Heroku
2. To allow the access_tokens to be linked to a particular user so that we can be sure that they are only used to access data that was granted access to.
3. To make the API Gateway the access token store to keep full control over the access tokens issued - NOT YET IMPLEMENTED

As such there are a few changes to the Nginx OAuth configuration files downloaded from 3scale in order to make this possible.

#### 1. API Gateway as an OAuth2 provider running on Heroku ####

The 3scale Nginx OAuth2 extension requires redis to be installed on the nginx server so we need to add Redis to our Heroku instance and modify the redis connection code to access the Redis instance. In my case I used RedisToGo.

Installing the RedisToGo addon to your Heroku instance will set up an environment variable (REDISTOGO_URL) which holds the connection string in this format:

redis://redistogo:<USER_ID>@<HOSTNAME>:<PORT>/

In order to connect to redis to go, you need to extract the relevant data from this environment variable and use it to build your connection string:

```
function M.connect_redis(red)
  redisurl = os.getenv("REDISTOGO_URL")
  redisurl_connect = string.split(redisurl, ":")[3]
  redisurl_user = string.split(redisurl_connect, "@")[1]
  redisurl_host = string.split(redisurl_connect, "@")[2]
  redisurl_port = string.sub(string.split(redisurl, ":")[4],1,-2)
  
  local ok, err = red:connect(redisurl_host, tonumber(redisurl_port))
  
  if not ok then
    ngx.say("failed to connect: ", err)
    ngx.exit(ngx.HTTP_OK)
  end

  local res, err = red:auth(redisurl_user)
  if not res then
    ngx.say("failed to authenticate: ", err)
    return
  end

  return ok, err
end
```

#### 2. Ensuring access token is only valid for user that granted access ####



Credits
-------

The [OpenResty buildpack](https://github.com/leafo/heroku-openresty) did the hard Heroku work! Thanks!

Our thanks to Taylor Brown [Taytay](http://taytay.com/) for providing the base configuration and files. 

I'm Maria Pilar Guerra-Arias (aka Pili) an API Solution Engineer at [3scale](http://www.3scale.net)
