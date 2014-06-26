## 3Scale API Proxy with OAuth2 Authorization Code Flow hosted on Heroku

This is based on Taytay's excellent implementation of a 3scale API Proxy using Heroku: Taytay/api-proxy-3scale-heroku

Please check out his [repo](https://www.github.com/Taytay/api-proxy-3scale-heroku) for the README and basic instructions on setting this up. 

I have added some OAuth extensions on top of this to implement an API Gateway acting as an OAuth2 provider for a simple Address Book App API. I will outline how these work (as well as any additional set up steps where they differ from the original repo) using the [Address Book App API](https://www.github.com/mpguerra/address-book-app-api) as an example API. 

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

```lua
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

And change the connection string to match, e.g

```lua
    local redis = require 'resty.redis'
    local ts = require 'threescale_utils'
    local red = redis:new()
   
    local ok, err = ts.connect_redis(red)
```

#### 2. Ensuring access token is only valid for user that granted access ####

In order to ensure that an access token is only valid for a the user that granted access, we need some way of linking the user identity to an access_token. I have chosen to do this by storing the user_id with the access_token as such: <access_token>:<user_id> Please note that the maximum length for the access_token field is 256 chars so you need to make sure that the combination of these 2 values will not exceed that length.

As such, if you compare the files in this repository with the lua files downloaded from 3scale, you will see the following changes

1. In authorized_callback.lua, the user_id is added to the client_data.client_id store

```lua
   ok, err =  red:hmset("c:".. client_data.client_id, {client_id = client_data.client_id,
                   client_secret = client_data.secret_id,
                   redirect_uri = client_data.redirect_uri,
                   pre_access_token = client_data.pre_access_token,
                   code = code,
                   user_id = params.username })
```
2. In get_token.lua, the user_id is added when storing the access token in the 3scale backend

```lua
function generate_access_token_for(client_id)
   local ok, err = ts.connect_redis(red)
   ok, err =  red:hgetall("c:".. client_id) -- code?
   ts.log(ok)
   if ok[1] == nil then
      ngx.say("expired_code")
      return ngx.exit(ngx.HTTP_OK)
   else
      return red:array_to_hash(ok).pre_access_token..":"..red:array_to_hash(ok).user_id
   end
end
```

And then removed again when returning it to the application

```lua
  access_token = token:split(":")[1]

  ngx.header.content_type = "application/json; charset=utf-8"
  ngx.say({'{"access_token": "'.. access_token .. '", "token_type": "bearer"}'})
```

As an additional security measure, in my API backend, I am rejecting any calls that don't come from my API gateway by setting up a shared secret between the 2, such that any calls that don't include this secret, will be rejected. 


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

1. Add this line to the top of the file
    daemon off;
2. Add this line to make the REDISTOGO_URL environment variable available to the .lua files
    env REDISTOGO_URL;    
3. replace 'listen 80;' with:
    listen ${{PORT}};
4. replace 'access_by_lua_file lua_tmp.lua;' with:
    access_by_lua_file nginx.lua;

See the sample **nginx.sample.conf** file for details, and for notes on other optional changes you can make.

#### Step 6: Test the workflow ####

Once your Proxy is deployed, you can test it's working as expected. However, before you test the OAuth workflow, you will need to make sure that your User Authorization Server will call the /callback endpoint on your proxy once a user grants access, e.g http://<heroku-app-name>.herokuapp.com/callback. 

When that's done, you can test your API proxy OAuth2 workflow using the google oauth playground (https://developers.google.com/oauthplayground/) or runscope's OAuth 2 Token Generator (https://www.runscope.com/oauth2_tool) with the oauth credentials (client_id and client_secret) you get from your 3scale control panel, making sure that the redirect url defined in 3scale matches that of the service you are using to test out your OAuth2 workflow (e.g https://www.runscope.com/oauth_tool/callback for Runscope and https://developers.google.com/oauthplayground/ for Google)

The Authorize URL/Authorization endpoint will be: http://<heroku-app-name>.herokuapp.com/authorize
The Access Token URL/Token endpoint will be: http://<heroku-app-name>.herokuapp.com/oauth/token

This will go through the whole process of requesting an authorization code for a user and exchanging that for an access token which can then be used to access data for that user using the API.

Now that you have an access token, you can call your API through the gateway as usual by sending the access token issued previously:

  `$ curl http://<heroku-app-name>.herokuapp.com/api/<username>/contacts.json?access_token=YOUR_ACCESS_TOKEN`

```json
  {"id":2,"name":"John Doe","phone":12345678,"email":"john.doe@example.com","user_id":1,"created_at":"2013-09-30T15:55:02.627Z","updated_at":"2013-09-30T15:55:02.627Z"},{"id":1,"name":"Jane Doe","phone":98765432,"email":"jane.doe@example.com","user_id":1,"created_at":"2013-09-30T15:54:45.339Z","updated_at":"2013-09-30T15:54:45.339Z"}
```

Credits
-------

The [OpenResty buildpack](https://github.com/leafo/heroku-openresty) did the hard Heroku work! Thanks!

Our thanks to Taylor Brown [Taytay](http://taytay.com/) for providing the base implementation, configuration and files. 

I'm Maria Pilar Guerra-Arias (aka Pili) an API Solution Engineer at [3scale](http://www.3scale.net)
