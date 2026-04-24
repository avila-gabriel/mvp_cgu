import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

pub fn parse(header: Option(String)) -> Option(Float) {
  case header {
    None -> None
    Some(value) -> parse_seconds(value)
  }
}

fn parse_seconds(value: String) -> Option(Float) {
  let value = string.trim(value)

  case int.parse(value) {
    Ok(seconds) if seconds >= 0 -> Some(int.to_float(seconds))
    _ ->
      case float.parse(value) {
        Ok(seconds) if seconds >=. 0.0 -> Some(seconds)
        _ -> None
      }
  }
}
