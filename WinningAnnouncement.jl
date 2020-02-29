module WinningAnnouncement

using Base64
using Dates
using HTTP
using JSON
using Lazy
using Random
using SHA

struct Authorization
  consumer_key::String
  consumer_secret::String
  api_token::String
  api_token_secret::String
end

function authorize(consumer_key::String, consumer_secret::String, api_token::String, api_token_secret::String)
  @eval bearer = generate_bearer($consumer_key, $consumer_secret)
  @eval authorization = Authorization($consumer_key, $consumer_secret, $api_token, $api_token_secret)
end

function post(message::String, in_reply_to_status_id::Int)
  POST_ENDPOINT = "https://api.twitter.com/1.1/statuses/update.json"

  raw_body = Dict(
    "status" => message,
    "in_reply_to_status_id" => in_reply_to_status_id,
  )

  authorization_header = create_authorization_header(
    "POST",
    POST_ENDPOINT,
    raw_body,
    authorization.consumer_key,
    authorization.consumer_secret,
    authorization.api_token,
    authorization.api_token_secret,
  )

  headers = [
    "Authorization" => authorization_header,
    "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8",
  ]

  body = HTTP.escapeuri(raw_body)

  HTTP.post(
    POST_ENDPOINT,
    headers,
    body,
  ) |> load
end

const OAUTH_SIGNATURE_METHOD = "HMAC-SHA1"
const OAUTH_VERSION = 1.0

create_authorization_header(http_method::String, url::String, request_parameters::Dict, oauth_consumer_key::String, oauth_consumer_secret::String, oauth_token::String, oauth_token_secret::String) = create_authorization_header(http_method, url, Dict(string(k)=>string(v) for (k,v)=request_parameters), oauth_consumer_key, oauth_consumer_secret, oauth_token, oauth_token_secret)
function create_authorization_header(http_method::String, url::String, request_parameters::Dict{String,String}, oauth_consumer_key::String, oauth_consumer_secret::String, oauth_token::String, oauth_token_secret::String)
  parameters = Dict(
    "oauth_consumer_key" => oauth_consumer_key,
    "oauth_nonce" => randstring(32),
    "oauth_signature_method" => OAUTH_SIGNATURE_METHOD,
    "oauth_timestamp" => Dates.now() |> Dates.datetime2unix |> x->trunc(Int, x),
    "oauth_token" => oauth_token,
    "oauth_version" => OAUTH_VERSION,
  )

  parameter_string = create_parameter_string(merge(parameters, request_parameters))
  signing_key = create_signing_key(oauth_consumer_secret, oauth_token_secret)
  signature_base_string = create_signature_base_string(http_method, url, parameter_string)
  parameters["oauth_signature"] = create_oauth_signature(signing_key, signature_base_string)

  create_authorization_header_string(parameters)
end

create_authorization_header_string(parameters::Dict{String,Any}) = create_authorization_header_string([k=>string(v) for (k,v)=parameters])
create_authorization_header_string(parameters::Array{Pair{String,String}}) = parameters |> sort |> x->"OAuth $(join(["$(HTTP.escapeuri(k))=\"$(HTTP.escapeuri(v))\"" for (k,v)=x], ", "))"

create_oauth_signature(signing_key::String, signature_base_string::String) = SHA.hmac_sha1(signing_key |> collect .|> UInt8, signature_base_string) |> Base64.base64encode

create_signing_key(consumer_secret::String, oauth_token_secret::String) = join([consumer_secret, oauth_token_secret], '&')

create_signature_base_string(http_method::String, url::String, parameter_string::String) = join([http_method, url |> HTTP.escapeuri, parameter_string |> HTTP.escapeuri], '&')

create_parameter_string(parameters::Dict{Any,Any}) = create_parameter_string([string(k)=>string(v) for (k,v)=parameters])
create_parameter_string(parameters::Dict{String,Any}) = create_parameter_string([k=>string(v) for (k,v)=parameters])
create_parameter_string(parameters::Dict{String,String}) = create_parameter_string([k=>v for (k,v)=parameters])
create_parameter_string(parameters::Array{Pair{String,String}}) = parameters |> sort |> HTTP.escapeuri

function exec(template::String, tweet_id::Int, range::UnitRange)
  @> create_message(template, retweeter_screen_names(tweet_id, range)) post(tweet_id)
end

function create_message(template::String, screen_names::Array{String})
  message = template

  for (index, screen_name) = enumerate(screen_names)
    message = replace(message, "#{$index}" => screen_name)
  end

  message
end

function retweeter_screen_names(tweet_id::Int, range::UnitRange)
  retweeter_ids(tweet_id) |> Random.shuffle |> x->x[range] .|> screen_name
end

function screen_name(user_id::Int)
  USER_ENDPOINT = "https://api.twitter.com/1.1/users/show.json"

  headers = [
    "Authorization" => "Bearer $bearer",
  ]

  HTTP.get(
    "$USER_ENDPOINT?id=$user_id",
    headers
  ) |> load |> x -> x["screen_name"]
end

function retweeter_ids(tweet_id::Int)
  RETWEETERS_ENDPOINT = "https://api.twitter.com/1.1/statuses/retweeters/ids.json"

  headers = [
    "Authorization" => "Bearer $bearer",
  ]

  HTTP.get(
    "$RETWEETERS_ENDPOINT?count=100&id=$tweet_id",
    headers
  ) |> load |> x -> x["ids"]
end

function generate_bearer(api_token::String, api_token_secret::String)
  credencials = Base64.base64encode("$api_token:$api_token_secret")

  header = [
    "Authorization" => "Basic $credencials",
    "Content-Type" => "application/x-www-form-urlencoded;charset=UTF-8",
  ]

  body = HTTP.escapeuri([
    "grant_type" => "client_credentials"
  ])

  HTTP.post(
    "https://api.twitter.com/oauth2/token",
    header,
    body,
  ) |> load |> x->x["access_token"]
end

function load(response::HTTP.Response)
  response.body |> String |> JSON.parse
end

end
