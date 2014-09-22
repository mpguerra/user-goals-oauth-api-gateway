Steps
=====

1. `heroku apps:create --buildpack http://github.com/leafo/heroku-buildpack-lua.git user-goals-oauth-api-gateway`
2. `heroku addons:add redistogo`
3. `heroku addons:add threescale`
4. `heroku addons:open threescale`
5. Get service_id and set environment variable
`heroku config:set THREESCALE_SERVICE_ID={SERVICE_ID}`
6. Change auth mode
7. Create new account
8. Set redirect url to: `https://www.getpostman.com/oauth2/callback`
9. `git push heroku master`
10. Get access token using POSTMAN
11. Get user data for user identified by access token