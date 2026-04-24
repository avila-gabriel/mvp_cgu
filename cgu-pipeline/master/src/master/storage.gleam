import brot
import bucket.{type BucketError}
import bucket/create_bucket
import bucket/get_object
import bucket/head_bucket
import bucket/put_object
import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/httpc
import gleam/int
import gleam/result
import gleam/string

pub const content_encoding = "br"

pub type Config {
  Config(
    endpoint_scheme: String,
    endpoint_host: String,
    endpoint_port: Int,
    region: String,
    access_key_id: String,
    secret_access_key: String,
    bucket_name: String,
    request_timeout_ms: Int,
  )
}

pub type StoredBody {
  StoredBody(
    storage_url: String,
    body_sha256: String,
    body_size_bytes: Int,
    storage_sha256: String,
    storage_size_bytes: Int,
    storage_content_encoding: String,
  )
}

pub type StorageError {
  CompressionError
  BucketHttpError(detail: String)
  BucketApiError(detail: String)
}

pub fn ensure_bucket(config: Config) -> Result(Nil, StorageError) {
  let creds = credentials(config)
  let http = http_client(config)

  let exists_request =
    head_bucket.request(name: config.bucket_name)
    |> head_bucket.build(creds)

  use exists_response <- result.try(
    httpc.dispatch_bits(http, exists_request)
    |> result.map_error(fn(error) {
      BucketHttpError(http_error_to_string(error))
    }),
  )

  use exists <- result.try(
    head_bucket.response(exists_response)
    |> result.map_error(fn(error) {
      BucketApiError(bucket_error_to_string(error))
    }),
  )

  case exists {
    True -> Ok(Nil)
    False -> {
      let create_request =
        create_bucket.request(name: config.bucket_name)
        |> create_bucket.build(creds)

      use create_response <- result.try(
        httpc.dispatch_bits(http, create_request)
        |> result.map_error(fn(error) {
          BucketHttpError(http_error_to_string(error))
        }),
      )

      create_bucket.response(create_response)
      |> result.map_error(fn(error) {
        BucketApiError(bucket_error_to_string(error))
      })
    }
  }
}

pub fn store(
  config: Config,
  body: BitArray,
) -> Result(StoredBody, StorageError) {
  let body_sha256 =
    crypto.hash(crypto.Sha256, body)
    |> bit_array.base16_encode
    |> string.lowercase
  use compressed_body <- result.try(
    brot.encode(body)
    |> result.map_error(fn(_) { CompressionError }),
  )
  let storage_sha256 =
    crypto.hash(crypto.Sha256, compressed_body)
    |> bit_array.base16_encode
    |> string.lowercase
  let body_size_bytes = bit_array.byte_size(body)
  let storage_size_bytes = bit_array.byte_size(compressed_body)
  let key = object_key(body_sha256)
  let storage_url = "s3://" <> config.bucket_name <> "/" <> key

  use _ <- result.try(put(config, key, compressed_body))

  Ok(StoredBody(
    storage_url:,
    body_sha256:,
    body_size_bytes:,
    storage_sha256:,
    storage_size_bytes:,
    storage_content_encoding: content_encoding,
  ))
}

pub fn load(
  config: Config,
  storage_url: String,
) -> Result(BitArray, StorageError) {
  use key <- result.try(storage_key(storage_url))
  let request =
    get_object.request(bucket: config.bucket_name, key: key)
    |> get_object.build(credentials(config))

  use response <- result.try(
    httpc.dispatch_bits(http_client(config), request)
    |> result.map_error(fn(error) {
      BucketHttpError(http_error_to_string(error))
    }),
  )

  use outcome <- result.try(
    get_object.response(response)
    |> result.map_error(fn(error) {
      BucketApiError(bucket_error_to_string(error))
    }),
  )
  use compressed_body <- result.try(case outcome {
    get_object.Found(body) -> Ok(body)
    get_object.NotFound -> Error(BucketApiError("object not found"))
  })

  brot.decode(compressed_body)
  |> result.map_error(fn(_) { CompressionError })
}

pub fn describe_error(error: StorageError) -> String {
  case error {
    CompressionError -> "Artifact compression failed"
    BucketHttpError(detail) -> "Bucket request failed: " <> detail
    BucketApiError(detail) -> "Bucket API returned an error: " <> detail
  }
}

fn put(
  config: Config,
  key: String,
  body: BitArray,
) -> Result(Nil, StorageError) {
  let request =
    put_object.request(bucket: config.bucket_name, key: key, body: body)
    |> put_object.build(credentials(config))

  use response <- result.try(
    httpc.dispatch_bits(http_client(config), request)
    |> result.map_error(fn(error) {
      BucketHttpError(http_error_to_string(error))
    }),
  )

  put_object.response(response)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(error) {
    BucketApiError(bucket_error_to_string(error))
  })
}

fn credentials(config: Config) -> bucket.Credentials {
  bucket.credentials(
    config.endpoint_host,
    config.access_key_id,
    config.secret_access_key,
  )
  |> bucket.with_region(config.region)
  |> bucket.with_port(config.endpoint_port)
  |> bucket.with_scheme(scheme(config.endpoint_scheme))
}

fn scheme(value: String) -> http.Scheme {
  case value {
    "http" -> http.Http
    _ -> http.Https
  }
}

fn http_client(config: Config) -> httpc.Configuration {
  httpc.configure()
  |> httpc.timeout(config.request_timeout_ms)
  |> httpc.follow_redirects(False)
}

fn object_key(body_sha256: String) -> String {
  "artifacts/sha256/" <> body_sha256 <> ".br"
}

fn storage_key(storage_url: String) -> Result(String, StorageError) {
  case string.starts_with(storage_url, "s3://") {
    False -> Error(BucketApiError("unsupported storage URL"))
    True -> {
      let without_scheme = string.drop_start(storage_url, 5)
      case string.split_once(without_scheme, "/") {
        Ok(#(_, key)) -> Ok(key)
        Error(Nil) -> Error(BucketApiError("invalid storage URL"))
      }
    }
  }
}

fn bucket_error_to_string(error: BucketError) -> String {
  case error {
    bucket.InvalidXmlSyntaxError(detail) -> "invalid XML syntax: " <> detail
    bucket.UnexpectedXmlFormatError(detail) ->
      "unexpected XML format: " <> detail
    bucket.UnexpectedResponseError(response) ->
      "unexpected HTTP response " <> int.to_string(response.status)
    bucket.S3Error(status, error) ->
      "HTTP "
      <> int.to_string(status)
      <> " "
      <> error.code
      <> ": "
      <> error.message
  }
}

fn http_error_to_string(error: httpc.HttpError) -> String {
  case error {
    httpc.InvalidUtf8Response -> "response body was not valid UTF-8"
    httpc.ResponseTimeout -> "response timed out"
    httpc.FailedToConnect(ip4, ip6) ->
      "failed to connect over IPv4 ("
      <> connect_error_to_string(ip4)
      <> ") or IPv6 ("
      <> connect_error_to_string(ip6)
      <> ")"
  }
}

fn connect_error_to_string(error: httpc.ConnectError) -> String {
  case error {
    httpc.Posix(code) -> code
    httpc.TlsAlert(code, detail) -> code <> ": " <> detail
  }
}
