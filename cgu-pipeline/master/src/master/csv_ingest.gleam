import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import shared/sta
import shared/url.{type Url}

pub type ParseError {
  ParseError(line: Int, detail: String)
}

type Header {
  Header(sta_index: Int, item_index: Int, status_index: Int)
}

type RawRow {
  RawRow(line: Int, sta_url: String, item_url: String, status: String)
}

type SeenRow {
  SeenRow(
    sta_url: String,
    item_url: Url,
    item_url_string: String,
    status: sta.VerificationStatus,
  )
}

pub fn parse(csv: String) -> Result(List(sta.STA), ParseError) {
  let lines =
    csv
    |> string.split(on: "\n")
    |> list.index_map(fn(line, index) { #(index + 1, string.trim_end(line)) })
    |> list.filter(fn(line) { string.trim(line.1) != "" })

  case lines {
    [] -> Error(ParseError(1, "CSV is empty"))
    [header_line, ..body_lines] -> {
      use header <- result.try(parse_header(header_line))
      use rows <- result.try(
        list.try_map(body_lines, fn(line) { parse_body_line(line, header) }),
      )
      group_rows(rows, dict.new())
    }
  }
}

pub fn parse_error_to_string(error: ParseError) -> String {
  "line " <> int_to_string(error.line) <> ": " <> error.detail
}

fn parse_header(line: #(Int, String)) -> Result(Header, ParseError) {
  use fields <- result.try(parse_csv_line(line.1, line.0))
  let normalised = list.map(fields, normalise_header)

  case
    index_of_any(normalised, ["sta_url", "sta_identifier", "sta_id"]),
    index_of_any(normalised, ["item_url", "url"]),
    index_of_any(normalised, ["status", "verification_status"])
  {
    Ok(sta_index), Ok(item_index), Ok(status_index) ->
      Ok(Header(sta_index:, item_index:, status_index:))
    _, _, _ ->
      Error(ParseError(
        line.0,
        "header must include sta_url, item_url, and status columns",
      ))
  }
}

fn parse_body_line(
  line: #(Int, String),
  header: Header,
) -> Result(RawRow, ParseError) {
  let Header(sta_index:, item_index:, status_index:) = header
  use fields <- result.try(parse_csv_line(line.1, line.0))

  case
    get_at(fields, sta_index),
    get_at(fields, item_index),
    get_at(fields, status_index)
  {
    Ok(sta_url), Ok(item_url), Ok(status) ->
      Ok(RawRow(line: line.0, sta_url:, item_url:, status:))
    _, _, _ ->
      Error(ParseError(line.0, "row has fewer columns than the header"))
  }
}

fn group_rows(
  rows: List(RawRow),
  seen: Dict(String, SeenRow),
) -> Result(List(sta.STA), ParseError) {
  use seen <- result.try(validate_rows(rows, seen))

  seen
  |> dict.to_list
  |> list.map(fn(row) { row.1 })
  |> rows_to_sta
}

fn validate_rows(
  rows: List(RawRow),
  seen: Dict(String, SeenRow),
) -> Result(Dict(String, SeenRow), ParseError) {
  case rows {
    [] -> Ok(seen)
    [row, ..rest] -> {
      use parsed <- result.try(validate_row(row))
      let key = parsed.sta_url <> "\n" <> parsed.item_url_string

      case dict.get(seen, key) {
        Ok(_) -> Error(ParseError(row.line, "duplicate sta_url and item_url"))
        Error(Nil) -> validate_rows(rest, dict.insert(seen, key, parsed))
      }
    }
  }
}

fn validate_row(row: RawRow) -> Result(SeenRow, ParseError) {
  let RawRow(line:, sta_url:, item_url:, status:) = row

  case
    sta.sta_id(sta_url),
    url.parse(item_url),
    sta.verification_status_from_string(status)
  {
    Ok(sta_id), Ok(item_url), Ok(status) ->
      Ok(SeenRow(
        sta_url: sta.id_to_string(sta_id),
        item_url:,
        item_url_string: url.to_string(item_url),
        status:,
      ))
    Error(Nil), _, _ -> Error(ParseError(line, "sta_url must not be empty"))
    _, Error(Nil), _ -> Error(ParseError(line, "item_url must be an HTTP URL"))
    _, _, Error(Nil) ->
      Error(ParseError(
        line,
        "status must be not_verified, conform, or non_conform",
      ))
  }
}

fn rows_to_sta(rows: List(SeenRow)) -> Result(List(sta.STA), ParseError) {
  let grouped =
    list.fold(rows, dict.new(), fn(grouped, row) {
      let item =
        sta.STAItem(
          source_key: row.item_url_string,
          url: row.item_url,
          status: row.status,
          current_archive_date: "",
          archive_fallback_dates: [],
          metadata_json: "{}",
        )

      let items = case dict.get(grouped, row.sta_url) {
        Ok(items) -> [item, ..items]
        Error(Nil) -> [item]
      }

      dict.insert(grouped, row.sta_url, items)
    })

  grouped
  |> dict.to_list
  |> list.map(fn(pair) {
    sta.STA(id: unsafe_sta_id(pair.0), items: list.reverse(pair.1))
  })
  |> Ok
}

fn parse_csv_line(
  line: String,
  line_number: Int,
) -> Result(List(String), ParseError) {
  line
  |> string.to_graphemes
  |> parse_chars([], [], False, False, line_number)
}

fn parse_chars(
  chars: List(String),
  fields: List(String),
  field: List(String),
  in_quotes: Bool,
  after_quote: Bool,
  line_number: Int,
) -> Result(List(String), ParseError) {
  case chars {
    [] if in_quotes ->
      Error(ParseError(line_number, "quoted field is not closed"))
    [] -> Ok(list.reverse([finish_field(field), ..fields]))

    [",", ..rest] if !in_quotes ->
      parse_chars(
        rest,
        [finish_field(field), ..fields],
        [],
        False,
        False,
        line_number,
      )

    ["\"", "\"", ..rest] if in_quotes ->
      parse_chars(rest, fields, ["\"", ..field], True, False, line_number)

    ["\"", ..rest] if in_quotes ->
      parse_chars(rest, fields, field, False, True, line_number)

    ["\"", ..rest] if field == [] && !after_quote ->
      parse_chars(rest, fields, field, True, False, line_number)

    [char, ..rest] if after_quote && { char == " " || char == "\t" } ->
      parse_chars(rest, fields, field, False, True, line_number)

    [_, ..] if after_quote ->
      Error(ParseError(
        line_number,
        "only whitespace or comma may follow a closing quote",
      ))

    ["\"", ..] ->
      Error(ParseError(line_number, "quote must start a quoted field"))

    [char, ..rest] ->
      parse_chars(rest, fields, [char, ..field], in_quotes, False, line_number)
  }
}

fn finish_field(field: List(String)) -> String {
  field
  |> list.reverse
  |> string.concat
  |> string.trim
}

fn normalise_header(value: String) -> String {
  value
  |> string.trim
  |> string.lowercase
  |> string.replace(each: "-", with: "_")
  |> string.replace(each: " ", with: "_")
}

fn index_of_any(values: List(String), names: List(String)) -> Result(Int, Nil) {
  index_of_any_loop(values, names, 0)
}

fn index_of_any_loop(
  values: List(String),
  names: List(String),
  index: Int,
) -> Result(Int, Nil) {
  case values {
    [] -> Error(Nil)
    [value, ..rest] ->
      case list.contains(names, value) {
        True -> Ok(index)
        False -> index_of_any_loop(rest, names, index + 1)
      }
  }
}

fn get_at(values: List(a), index: Int) -> Result(a, Nil) {
  case values, index {
    [], _ -> Error(Nil)
    [value, ..], 0 -> Ok(value)
    [_, ..rest], _ -> get_at(rest, index - 1)
  }
}

fn unsafe_sta_id(value: String) -> sta.STAId {
  let assert Ok(id) = sta.sta_id(value)
  id
}

fn int_to_string(value: Int) -> String {
  value |> int.to_string
}
