import gleam/option.{Some}
import gleam/string
import gleam/uri

pub const archive = "web.archive.org"

pub fn from_url(url: String) -> Result(String, Nil) {
  case uri.parse(url) {
    Ok(uri.Uri(scheme: Some("http"), host: Some(host), ..)) if host != "" ->
      Ok(normalise(host))
    Ok(uri.Uri(scheme: Some("https"), host: Some(host), ..)) if host != "" ->
      Ok(normalise(host))
    _ -> Error(Nil)
  }
}

fn normalise(host: String) -> String {
  host
  |> string.trim
  |> string.lowercase
}
