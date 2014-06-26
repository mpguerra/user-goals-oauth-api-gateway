## 3Scale API Proxy with OAuth2 Authorization Code Flow hosted on Heroku

This is based on Taytay's excellent implementation of a 3scale API Proxy using Heroku: Taytay/api-proxy-3scale-heroku

Please check out his [repo](https://www.github.com/Taytay/api-proxy-3scale-heroku) for the README and basic instructions on setting this up. 

I have added some OAuth extensions on top of this to implement an API Gateway acting as an OAuth2 provider for a simple Address Book App API. I will outline how these work (as well as any additional set up steps where they differ from the original repo) using the [Address Book App API](https://www.github.com/mpguerra/address-book-app) as an example API. 

Motivation
--------

There were a couple of ideas behind this API Gateway implementation: 

1. To have an API Gateway that acts as an OAuth2 provider running on Heroku
2. To show an example of how you might use Nginx to match access_tokens to a particular end user so it will only allow calls through that are targetting that end user with that access token.
3. To make the API Gateway the access token store to keep full control over the access tokens issued - NOT YET IMPLEMENTED

As such you will see that there are a few differences between the Nginx OAuth configuration files downloaded from 3scale and the ones available from this repository in order to implement these. 

#### 1. API Gateway as an OAuth2 provider running on Heroku ####

The 3scale Nginx OAuth2 extension requires redis to be installed on the nginx server so we need to add Redis to our Heroku instance and modify the redis connection code to access the Redis instance. In my case I used RedisToGo.

Installing the RedisToGo addon to your Heroku instance will set up an environment variable (REDISTOGO_URL) which holds the connection string in this format:

`redis://redistogo:<USER_ID>@<HOSTNAME>:<PORT>/`

In order to connect to redis to go, we extract the relevant data from this environment variable and use it to build the connection string, this will require some changes to the connect\_redis function in threescale\_utils.lua :

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

We also need to change the way we call the connect\_redis function from the other \*.lua files, e.g

```lua
    local redis = require 'resty.redis'
    local ts = require 'threescale_utils'
    local red = redis:new()
   
    local ok, err = ts.connect_redis(red)
```

#### 2. Ensuring access token is only valid for user that granted access ####

In order to ensure that an access token is only valid for a the user that granted access, we need some way of linking the user identity to an access\_token. I have chosen to do this by storing the user\_id with the access\_token as such: \<access\_token\>\:\<user\_id\> 

_NB: the maximum length for the access\_token field is 256 chars so you need to make sure that the combination of these 2 values will not exceed that length._

As such, if you compare the files in this repository with the lua files downloaded from 3scale, you will see the following changes:

1. In threescale_utils.lua, we add a new function to split a string on a char, this is already present in the nginx.lua file, so we can just copy it from there
```lua
function string:split(delimiter)
  local result = { }
  local from = 1
  local delim_from, delim_to = string.find( self, delimiter, from )
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from )
  end
  table.insert( result, string.sub( self, from ) )
  return result
end
```
2. In authorized_callback.lua, the user_id is added to the client_data.client_id store
```lua
   ok, err =  red:hmset("c:".. client_data.client_id, {client_id = client_data.client_id,
                   client_secret = client_data.secret_id,
                   redirect_uri = client_data.redirect_uri,
                   pre_access_token = client_data.pre_access_token,
                   code = code,
                   user_id = params.username })
```
3. In get_token.lua, the user_id is added when storing the access token in the 3scale backend
```lua
function generate_access_token_for(client_id)
   local ok, err = ts.connect_redis(red)
   ok, err =  red:hgetall("c:".. client_id) -- code?
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
4. In nginx.lua, when checking for access_token validity for a particular user (in my particular example) we extract the userid from the call to the API and concatenate it with the access_token sent:
```lua
function oauth(params, service)
  local res = ngx.location.capture("/_threescale/toauth_authorize?access_token="..
    params.access_token ..":".. params.username..
    "&user_id="..
    params.access_token,
    { share_all_vars = true })
```


As an additional security measure, in my API backend, I am rejecting any calls that don't come from my API gateway by setting up a shared secret between the two, such that any calls that don't include this secret, will be rejected.

In nginx.sample.conf we add the PROXY\_SECRET\_TOKEN environment variable which will be sent as a header to the API backend

```
    location ~* /api/(.*)/contacts.json {
      set $provider_key null;
      set $cached_key null;
      set $credentials null;
      set $usage null;
      set $service_id 2555417686521;
      set $proxy_pass null;
      set $secret_token "${{PROXY_SECRET_TOKEN}}";

      set $api_path "/api/contacts.json?$args&username=$1";

      proxy_ignore_client_abort on;

      ## CHANGE THE PATH TO POINT TO THE RIGHT FILE ON YOUR FILESYSTEM
      access_by_lua_file nginx.lua;

      proxy_pass $proxy_pass$api_path ;
      proxy_set_header  X-Real-IP  $remote_addr;
      proxy_set_header  Host  address-book-app.herokuapp.com;
      proxy_set_header X-3scale-proxy-secret-token $secret_token;
    }
``` 

We can then check for this header in our API backend to ensure the call is coming from the API Gateway and reject any calls with an incorrect secret token. 

```ruby
module Api
  class ContactsController < ApplicationController
    before_filter :restrict_access
    respond_to :html, :json

    # GET /contacts(.:format)
    def index
      @user = User.find_by username: params[:username]
      respond_to do |format|
        format.json do
          render :json => @user.contacts.to_json
        end
      end
    end

      protected
    def restrict_access
      secret_token = request.headers['X-3scale-proxy-secret-token']
      if secret_token != ENV['SHARED_PROXY_SECRET']
        respond_to do |format|
          format.html
          format.json { render :json => { :outcome => 'Access Denied'} }
        end
        return false
      end
    end

  end
end
```

There are of course many additional measures you can take such as IP address/domain whitelisting but this is just a simple example of what is possible.

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
    env REDISTOGO\_URL;    
3. replace 'listen 80;' with:
    listen ${{PORT}};
4. replace 'access_by_lua_file lua\_tmp.lua;' with:
    access\_by\_lua_file nginx.lua;

See the sample **nginx.sample.conf** file for details, and for notes on other optional changes you can make.

#### Step 6: Test the workflow ####

Once your Proxy is deployed, you can test it's working as expected. However, before you test the OAuth workflow, you will need to make sure that your User Authorization Server will call the /callback endpoint on your proxy once a user grants access, e.g http://\<heroku-app-name\>.herokuapp.com/callback. 

When that's done, you can test your API proxy OAuth2 workflow using the google oauth playground (https://developers.google.com/oauthplayground/) or runscope's OAuth 2 Token Generator (https://www.runscope.com/oauth2_tool) with the oauth credentials (client_id and client_secret) you get from your 3scale control panel, making sure that the redirect url defined in 3scale matches that of the service you are using to test out your OAuth2 workflow (e.g https://www.runscope.com/oauth_tool/callback for Runscope and https://developers.google.com/oauthplayground/ for Google)

The Authorize URL/Authorization endpoint will be: http://\<heroku-app-name\>.herokuapp.com/authorize
The Access Token URL/Token endpoint will be: http://\<heroku-app-name\>.herokuapp.com/oauth/token

This will go through the whole process of requesting an authorization code for a user and exchanging that for an access token which can then be used to access data for that user using the API.

Now that you have an access token, you can call your API through the gateway as usual by sending the access token issued previously:

  `$ curl http://<heroku-app-name>.herokuapp.com/api/<username>/contacts.json?access_token=YOUR_ACCESS_TOKEN`

```json
[{"id":2,"name":"John Doe","phone":12345678,"email":"john.doe@example.com","user_id":1,"created_at":"2013-09-30T15:55:02.627Z","updated_at":"2013-09-30T15:55:02.627Z"},{"id":1,"name":"Jane Doe","phone":98765432,"email":"jane.doe@example.com","user_id":1,"created_at":"2013-09-30T15:54:45.339Z","updated_at":"2013-09-30T15:54:45.339Z"}]
```

Credits
-------

The [OpenResty buildpack](https://github.com/leafo/heroku-openresty) did the hard Heroku work! Thanks!

Our thanks to Taylor Brown [Taytay](http://taytay.com/) for providing the base implementation, configuration and files. 

I'm Maria Pilar Guerra-Arias (aka Pili) an API Solution Engineer at [3scale](http://www.3scale.net)
