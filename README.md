Background
==========

https://github.com/mpguerra/address-book-app-api-gateway

Deploy
======

1. Clone repo: ` git clone git@github.com:mpguerra/user-goals-oauth-api-gateway.git <NEW REPO NAME>`
2. `heroku apps:create --buildpack http://github.com/leafo/heroku-buildpack-lua.git <APP NAME>`
3. `heroku addons:add redistogo`
4. `heroku addons:add threescale`
7. `git push heroku master`

3scale set up
=============

1. Open up 3scale admin console `heroku addons:open threescale`
2. Get service_id and set environment variable
`heroku config:set THREESCALE_SERVICE_ID={SERVICE_ID}`
3. Change auth mode
4. Create new account
5. Set redirect url to: `https://www.getpostman.com/oauth2/callback` if using POSTMAN.

Test
====
1. Get access token using POSTMAN
2. Get user data for user identified by access token