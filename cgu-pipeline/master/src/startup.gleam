import envoy
import gleam/int
import gleam/result
import gleam/string
import master/storage
import wisp

pub type Startup {
  Startup(
    port: Int,
    database_url: String,
    secret_key_base: String,
    storage_config: storage.Config,
  )
}

pub fn load() -> Startup {
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
    as "DATABASE_URL is required"
  let assert Ok(port) = envoy.get("PORT") |> result.try(int.parse)
    as "PORT is required and must be an integer"
  let assert Ok(bucket_endpoint_scheme) = envoy.get("BUCKET_ENDPOINT_SCHEME")
    as "BUCKET_ENDPOINT_SCHEME is required"
  let assert Ok(bucket_endpoint_host) = envoy.get("BUCKET_ENDPOINT_HOST")
    as "BUCKET_ENDPOINT_HOST is required"
  let assert Ok(bucket_endpoint_port) =
    envoy.get("BUCKET_ENDPOINT_PORT") |> result.try(int.parse)
    as "BUCKET_ENDPOINT_PORT is required and must be an integer"
  let assert Ok(bucket_region) = envoy.get("BUCKET_REGION")
    as "BUCKET_REGION is required"
  let assert Ok(bucket_access_key_id) = envoy.get("BUCKET_ACCESS_KEY_ID")
    as "BUCKET_ACCESS_KEY_ID is required"
  let assert Ok(bucket_secret_access_key) =
    envoy.get("BUCKET_SECRET_ACCESS_KEY")
    as "BUCKET_SECRET_ACCESS_KEY is required"
  let assert Ok(bucket_name) = envoy.get("BUCKET_NAME")
    as "BUCKET_NAME is required"
  let assert Ok(bucket_request_timeout_ms) =
    envoy.get("BUCKET_REQUEST_TIMEOUT_MS") |> result.try(int.parse)
    as "BUCKET_REQUEST_TIMEOUT_MS is required and must be an integer"
  let secret_key_base = wisp.random_string(64)
  let endpoint_scheme = string.lowercase(bucket_endpoint_scheme)
  let assert True = endpoint_scheme == "http" || endpoint_scheme == "https"
    as "BUCKET_ENDPOINT_SCHEME must be either http or https"
  let assert True = bucket_endpoint_port > 0
    as "BUCKET_ENDPOINT_PORT must be greater than zero"
  let assert True = bucket_request_timeout_ms > 0
    as "BUCKET_REQUEST_TIMEOUT_MS must be greater than zero"
  let storage_config =
    storage.Config(
      endpoint_scheme:,
      endpoint_host: bucket_endpoint_host,
      endpoint_port: bucket_endpoint_port,
      region: bucket_region,
      access_key_id: bucket_access_key_id,
      secret_access_key: bucket_secret_access_key,
      bucket_name: bucket_name,
      request_timeout_ms: bucket_request_timeout_ms,
    )

  Startup(port:, database_url:, secret_key_base:, storage_config:)
}
