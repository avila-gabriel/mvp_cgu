import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import server/monitor/model

pub fn evidence(evidence: List(model.Evidence)) -> List(model.Classified) {
  list.map(evidence, page)
}

pub fn page(evidence: model.Evidence) -> model.Classified {
  model.Classified(
    evidence:,
    noise: collect([
      style_sheet(evidence),
      style_tag(evidence),
      inline_style(evidence),
      whitespace(evidence),
      timestamp(evidence),
      query(evidence),
    ]),
  )
}

pub fn style_sheet(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect stylesheet only churn that should not count as a meaningful page change"
}

pub fn style_tag(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect style tag only churn that should not count as a meaningful page change"
}

pub fn inline_style(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect inline style attribute churn that should not count as a meaningful page change"
}

pub fn class(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect class name only changes that do not alter the monitored meaning of the page"
}

pub fn id(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect id only changes that do not alter the monitored meaning of the page"
}

pub fn script(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect script tag changes that should not count as a page change candidate"
}

pub fn token(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect JavaScript generated tokens that should not count as a meaningful change"
}

pub fn analytics(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect analytics and tracking script churn that should be ignored by monitoring"
}

pub fn timestamp(evidence: model.Evidence) -> Option(model.Noise) {
  case pages(evidence) {
    Error(Nil) -> None
    Ok(#(before, after)) ->
      case
        normalize_timestamp(before.text) == normalize_timestamp(after.text)
        && before.text != after.text
        && before.heading == after.heading
        && before.link == after.link
      {
        True -> Some(model.Timestamp)
        False -> None
      }
  }
}

pub fn query(evidence: model.Evidence) -> Option(model.Noise) {
  case pages(evidence) {
    Error(Nil) -> None
    Ok(#(before, after)) ->
      case
        before.text == after.text
        && before.heading == after.heading
        && list.map(before.link, strip_query)
        == list.map(after.link, strip_query)
        && before.link != after.link
      {
        True -> Some(model.Query)
        False -> None
      }
  }
}

pub fn whitespace(evidence: model.Evidence) -> Option(model.Noise) {
  case pages(evidence) {
    Error(Nil) -> None
    Ok(#(before, after)) ->
      case
        normalize_whitespace(before.html) == normalize_whitespace(after.html)
        && before.html != after.html
        && before.text == after.text
        && before.heading == after.heading
        && before.link == after.link
      {
        True -> Some(model.Whitespace)
        False -> None
      }
  }
}

pub fn formatting(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect formatting only HTML rearrangements that preserve the same visible content"
}

pub fn wrapper(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect DOM wrapper churn that preserves the same visible content"
}

pub fn footer(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect footer only updates that should not count as a meaningful candidate change"
}

pub fn header(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect header only decorative updates that should not count as a meaningful candidate change"
}

pub fn cookie_banner(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect cookie banner churn that should not count as a meaningful candidate change"
}

pub fn privacy_banner(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect privacy banner churn that should not count as a meaningful candidate change"
}

pub fn accessibility_widget(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect accessibility widget churn that should not count as a meaningful candidate change"
}

pub fn chat_widget(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect chat widget churn that should not count as a meaningful candidate change"
}

pub fn carousel(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect rotating carousel churn that should not count as a meaningful candidate change"
}

pub fn ad_slot(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect ad slot churn that should not count as a meaningful candidate change"
}

pub fn session_content(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect session specific dynamic content that should not count as a meaningful candidate change"
}

pub fn forgery_token(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect CSRF or anti forgery token churn that should not count as a meaningful candidate change"
}

pub fn random_identifier(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect random element identifier churn that should not count as a meaningful candidate change"
}

pub fn asset_hash(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect asset hash changes that should not count as a meaningful candidate change"
}

pub fn image_version(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect image URL hash or version churn when the image meaning and alt text stay the same"
}

pub fn repeated_pattern(_evidence: model.Evidence) -> Option(model.Noise) {
  todo as "detect repeated noise patterns that were previously classified as irrelevant"
}

fn collect(noise: List(Option(model.Noise))) -> List(model.Noise) {
  list.fold(noise, [], fn(collected, found) {
    case found {
      Some(value) -> [value, ..collected]
      None -> collected
    }
  })
  |> list.reverse
}

fn pages(evidence: model.Evidence) -> Result(#(model.Page, model.Page), Nil) {
  let model.Evidence(before:, after:, ..) = evidence

  case before {
    Some(value) -> Ok(#(value, after))
    None -> Error(Nil)
  }
}

fn normalize_whitespace(text: String) -> String {
  text
  |> string.replace(each: "\n", with: " ")
  |> string.replace(each: "\t", with: " ")
  |> string.replace(each: "\r", with: " ")
  |> collapse_spaces
  |> string.trim
}

fn collapse_spaces(text: String) -> String {
  let collapsed = string.replace(text, each: "  ", with: " ")

  case collapsed == text {
    True -> text
    False -> collapse_spaces(collapsed)
  }
}

fn normalize_timestamp(text: String) -> String {
  text
  |> normalize_whitespace
  |> string.split(on: " ")
  |> list.map(fn(token) {
    case timestamp_token(token) {
      True -> "<timestamp>"
      False -> token
    }
  })
  |> string.join(with: " ")
}

fn timestamp_token(token: String) -> Bool {
  let token = string.trim(token)
  let grapheme = string.to_graphemes(token)

  case grapheme {
    [] -> False
    _ ->
      list.any(grapheme, fn(part) { digit(part) })
      && list.all(grapheme, fn(part) {
        digit(part) || timestamp_punctuation(part)
      })
  }
}

fn digit(part: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], part)
}

fn timestamp_punctuation(part: String) -> Bool {
  list.contains(["-", "/", ":", ".", ",", "T", "Z"], part)
}

fn strip_query(url: String) -> String {
  case string.split_once(url, on: "?") {
    Ok(#(base, _)) -> base
    Error(Nil) -> url
  }
}
