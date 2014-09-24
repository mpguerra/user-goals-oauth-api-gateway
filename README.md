Background
==========

https://github.com/mpguerra/address-book-app-api-gateway

Deploy
======

1. Clone repo
2. `heroku apps:create --buildpack http://github.com/leafo/heroku-buildpack-lua.git user-goals-oauth-api-gateway`
3. `heroku addons:add redistogo`
4. `heroku addons:add threescale`
5. `heroku addons:open threescale`
6. Get service_id and set environment variable
`heroku config:set THREESCALE_SERVICE_ID={SERVICE_ID}`
7. `git push heroku master`

3scale set up
=============

1. Open up 3scale
2. Change auth mode
3. Create new account
4. Set redirect url to: `https://www.getpostman.com/oauth2/callback` if using POSTMAN.

Test
====
1. Get access token using POSTMAN
2. Get user data for user identified by access token