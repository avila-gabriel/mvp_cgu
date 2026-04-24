import gleam/dynamic/decode
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri}

pub opaque type Url {
  Url(Uri)
}

pub fn parse(attempt: String) -> Result(Url, Nil) {
  string.trim(attempt)
  |> uri.parse
  |> result.try(fn(uri) {
    case uri {
      uri.Uri(scheme: Some("http"), host: Some(host), ..) if host != "" ->
        Ok(Url(uri))
      uri.Uri(scheme: Some("https"), host: Some(host), ..) if host != "" ->
        Ok(Url(uri))
      _ -> Error(Nil)
    }
  })
}

pub fn to_string(url: Url) -> String {
  let Url(uri) = url
  uri.to_string(uri)
}

pub fn decoder() -> decode.Decoder(Url) {
  decode.string
  |> decode.then(fn(raw) {
    case parse(raw) {
      Ok(url) -> decode.success(url)
      Error(Nil) -> decode.failure(Url(uri.empty), "Url")
    }
  })
}
