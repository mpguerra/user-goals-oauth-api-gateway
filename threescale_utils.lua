-- threescale_utils.lua
local M = {} -- public interface

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

-- private
-- Logging Helpers
function M.show_table(t, ...)
   local indent = 0 --arg[1] or 0
   local indentStr=""
   for i = 1,indent do indentStr=indentStr.."  " end

   for k,v in pairs(t) do
     if type(v) == "table" then
	msg = indentStr .. M.show_table(v or '', indent+1)
     else
	msg = indentStr ..  k .. " => " .. v
     end
     M.log_message(msg)
   end
end

function M.log_message(str)
   ngx.log(0, str)
end

function M.newline()
   ngx.log(0,"  ---   ")
end

function M.log(content)
   if enabled == true then
  if type(content) == "table" then
     M.log_message(M.show_table(content))
  else
     M.log_message(content)
  end
  M.newline()
end
end

-- End Logging Helpers

-- Table Helpers
function M.keys(t)
   local n=0
   local keyset = {}
   for k,v in pairs(t) do
      n=n+1
      keyset[n]=k
   end
   return keyset
end
-- End Table Helpers


function M.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
	 if type(k) ~= 'number' then k = '"'..k..'"' end
	 s = s .. '['..k..'] = ' .. M.dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function M.sha1_digest(s)
   local str = require "resty.string"
   return str.to_hex(ngx.sha1_bin(s))
end

-- returns true iif all elems of f_req are among actual's keys
function M.required_params_present(f_req, actual)
   local req = {}
   for k,v in pairs(actual) do
      req[k] = true
   end
   for i,v in ipairs(f_req) do
      if not req[v] then
	 return false
      end
   end
   return true
end

function M.connect_redis(red)
  redisurl = os.getenv("REDISTOGO_URL")
  ngx.log(0,"Redis to go url: "..redisurl)
  redisurl_connect = string:split(redisurl, ":")[3]
  ngx.log(0, "Connect string: "..redisurl_connect)
  redisurl_user = string:split(redisurl_connect, "@")[1]
  ngx.log(0, "Password: "..redisurl_user)
  redisurl_host = string:split(redisurl_connect, "@")[2]
  ngx.log(0, "Host: "..redisurl_host)
  redisurl_port = tonumber(string:split(redisurl, ":")[4])
  ngx.log(0, "Port: "..redisurl_port)
  
  local ok, err = red:connect(redisurl_host, redisurl_port)
  --local ok, err = red:connect("viperfish.redistogo.com", 9191)
  if not ok then
    ngx.say("failed to connect: ", err)
    ngx.exit(ngx.HTTP_OK)
  end

  local res, err = red:auth("0925e54ca0456ef7818ae3b97e90c6d6")
  if not res then
    ngx.say("failed to authenticate: ", err)
    return
  end

  return ok, err
end

-- error and exist
function M.error(text)
   ngx.say(text)
   ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

function M.missing_args(text)
   ngx.say(text)
   ngx.exit(ngx.HTTP_OK)
end

return M

-- -- Example usage:
-- local MM = require 'mymodule'
-- MM.bar()
