# To test

- Get Access Token

`curl -v -X POST "http://nginx-oauth.herokuapp.com/oauth/token" -d "client_id=&client_secret=&grant_type=client_credentials"`

- Call API

`curl -v -X GET "http://nginx-oauth.herokuapp.com/v1/words/happy.json?client_id=&client_secret="`