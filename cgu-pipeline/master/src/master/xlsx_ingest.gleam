import gleam/dict
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import shared/sta
import shared/url.{type Url}

pub type ParseError {
  ParseError(file: String, row: Int, detail: String)
}

pub type ParseReport {
  ParseReport(
    records: List(sta.STA),
    skipped_missing_url: Int,
    discarded_rows: List(DiscardedRow),
  )
}

pub type DiscardedRow {
  DiscardedRow(
    file: String,
    row: Int,
    reason: String,
    sta_id: String,
    item_url: String,
    assunto: String,
    item: String,
  )
}

type Workbook {
  Workbook(file_name: String, rows: List(List(String)))
}

type Header {
  Header(
    assunto: Int,
    item: Int,
    resposta_orgao: Int,
    url: Int,
    data_atualizacao: Int,
    data_avaliacao_cgu: Int,
    status: Int,
    avaliacao_cgu: Int,
  )
}

type RawRow {
  RawRow(
    file_name: String,
    row_number: Int,
    sta_id: String,
    assunto: String,
    item_text: String,
    resposta_orgao: String,
    item_url: String,
    data_atualizacao: String,
    data_avaliacao_cgu: String,
    status: String,
    avaliacao_cgu: String,
  )
}

type SeenRow {
  SeenRow(
    sta_id: String,
    source_key: String,
    item_url: Url,
    status: sta.VerificationStatus,
    current_archive_date: String,
    archive_fallback_dates: List(String),
    metadata_json: String,
  )
}

type Date {
  Date(year: Int, month: Int, day: Int)
}

@external(erlang, "Elixir.Master.XlsxFfi", "parse_zip")
fn parse_zip_rows(
  body: BitArray,
) -> Result(List(#(String, List(List(String)))), String)

pub fn parse_zip(body: BitArray) -> Result(ParseReport, ParseError) {
  case parse_zip_rows(body) {
    Error(error) -> Error(ParseError(file: "zip", row: 0, detail: error))
    Ok(workbooks) ->
      workbooks
      |> list.map(fn(workbook) {
        Workbook(file_name: workbook.0, rows: workbook.1)
      })
      |> parse_workbooks([], 0, [])
  }
}

pub fn parse_error_to_string(error: ParseError) -> String {
  error.file <> ": row " <> int.to_string(error.row) <> ": " <> error.detail
}

fn parse_workbooks(
  workbooks: List(Workbook),
  rows: List(SeenRow),
  skipped_missing_url: Int,
  discarded_rows: List(DiscardedRow),
) -> Result(ParseReport, ParseError) {
  case workbooks {
    [] ->
      rows
      |> rows_to_sta
      |> result.map(fn(records) {
        ParseReport(
          records:,
          skipped_missing_url:,
          discarded_rows: list.reverse(discarded_rows),
        )
      })

    [workbook, ..rest] -> {
      use parsed <- result.try(parse_workbook(workbook))
      parse_workbooks(
        rest,
        list.append(parsed.rows, rows),
        skipped_missing_url + parsed.skipped_missing_url,
        list.append(parsed.discarded_rows, discarded_rows),
      )
    }
  }
}

type WorkbookParse {
  WorkbookParse(
    rows: List(SeenRow),
    skipped_missing_url: Int,
    discarded_rows: List(DiscardedRow),
  )
}

fn parse_workbook(workbook: Workbook) -> Result(WorkbookParse, ParseError) {
  case workbook.rows {
    [] -> Error(ParseError(workbook.file_name, 1, "worksheet is empty"))
    [header_row, ..body_rows] -> {
      use header <- result.try(parse_header(workbook.file_name, header_row))
      parse_body_rows(
        body_rows,
        header,
        workbook.file_name,
        sta_id_from_file(workbook.file_name),
        2,
        [],
        0,
        [],
      )
    }
  }
}

fn parse_header(
  file_name: String,
  row: List(String),
) -> Result(Header, ParseError) {
  let normalised = list.map(row, normalise_header)

  case
    index_of(normalised, "assunto"),
    index_of(normalised, "item"),
    index_of(normalised, "respostaorgao"),
    index_of(normalised, "url"),
    index_of(normalised, "dataatualizacao"),
    index_of(normalised, "dataavaliacaocgu"),
    index_of(normalised, "status"),
    index_of(normalised, "avaliacaocgu")
  {
    Ok(assunto),
      Ok(item),
      Ok(resposta_orgao),
      Ok(url),
      Ok(data_atualizacao),
      Ok(data_avaliacao_cgu),
      Ok(status),
      Ok(avaliacao_cgu)
    ->
      Ok(Header(
        assunto:,
        item:,
        resposta_orgao:,
        url:,
        data_atualizacao:,
        data_avaliacao_cgu:,
        status:,
        avaliacao_cgu:,
      ))

    _, _, _, _, _, _, _, _ ->
      Error(ParseError(
        file_name,
        1,
        "header must include Assunto, Item, RespostaOrgao, URL, DataAtualizacao, DataAvaliacaoCGU, Status, and AvaliacaoCGU",
      ))
  }
}

fn parse_body_rows(
  rows: List(List(String)),
  header: Header,
  file_name: String,
  sta_id: String,
  row_number: Int,
  acc: List(SeenRow),
  skipped_missing_url: Int,
  discarded_rows: List(DiscardedRow),
) -> Result(WorkbookParse, ParseError) {
  case rows {
    [] -> Ok(WorkbookParse(rows: acc, skipped_missing_url:, discarded_rows:))
    [row, ..rest] -> {
      use parsed <- result.try(parse_body_row(
        row,
        header,
        file_name,
        sta_id,
        row_number,
      ))

      case string.trim(parsed.item_url) {
        "" ->
          parse_body_rows(
            rest,
            header,
            file_name,
            sta_id,
            row_number + 1,
            acc,
            skipped_missing_url + 1,
            [discarded_row(parsed, "URL is empty"), ..discarded_rows],
          )

        _ -> {
          use seen <- result.try(validate_row(parsed))
          parse_body_rows(
            rest,
            header,
            file_name,
            sta_id,
            row_number + 1,
            [seen, ..acc],
            skipped_missing_url,
            discarded_rows,
          )
        }
      }
    }
  }
}

fn parse_body_row(
  row: List(String),
  header: Header,
  file_name: String,
  sta_id: String,
  row_number: Int,
) -> Result(RawRow, ParseError) {
  let Header(
    assunto:,
    item:,
    resposta_orgao:,
    url:,
    data_atualizacao:,
    data_avaliacao_cgu:,
    status:,
    avaliacao_cgu:,
  ) = header

  Ok(RawRow(
    file_name:,
    row_number:,
    sta_id:,
    assunto: get(row, assunto),
    item_text: get(row, item),
    resposta_orgao: get(row, resposta_orgao),
    item_url: get(row, url),
    data_atualizacao: get(row, data_atualizacao),
    data_avaliacao_cgu: get(row, data_avaliacao_cgu),
    status: get(row, status),
    avaliacao_cgu: get(row, avaliacao_cgu),
  ))
}

fn discarded_row(row: RawRow, reason: String) -> DiscardedRow {
  DiscardedRow(
    file: row.file_name,
    row: row.row_number,
    reason:,
    sta_id: row.sta_id,
    item_url: row.item_url,
    assunto: row.assunto,
    item: row.item_text,
  )
}

fn validate_row(row: RawRow) -> Result(SeenRow, ParseError) {
  case
    sta.sta_id(row.sta_id),
    url.parse(row.item_url),
    status_from_cgu(row.status, row.avaliacao_cgu)
  {
    Ok(sta_id), Ok(item_url), Ok(status) -> {
      use current_archive_date <- result.try(parse_cgu_date(
        row.data_avaliacao_cgu,
        row,
        "DataAvaliacaoCGU",
      ))
      use update_date <- result.try(parse_cgu_date(
        row.data_atualizacao,
        row,
        "DataAtualizacao",
      ))
      Ok(SeenRow(
        sta_id: sta.id_to_string(sta_id),
        source_key: source_key(row),
        item_url:,
        status:,
        current_archive_date: format_wayback_date(current_archive_date),
        archive_fallback_dates: archive_fallback_dates(update_date),
        metadata_json: metadata(row),
      ))
    }

    Error(Nil), _, _ ->
      Error(ParseError(row.file_name, row.row_number, "STA identifier is empty"))
    _, Error(Nil), _ ->
      Error(ParseError(row.file_name, row.row_number, "URL must be an HTTP URL"))
    _, _, Error(Nil) ->
      Error(ParseError(
        row.file_name,
        row.row_number,
        "AvaliacaoCGU is not recognised",
      ))
  }
}

fn parse_cgu_date(
  value: String,
  row: RawRow,
  field_name: String,
) -> Result(Date, ParseError) {
  case parse_br_date(value) {
    Ok(date) -> Ok(date)
    Error(Nil) ->
      Error(ParseError(
        row.file_name,
        row.row_number,
        field_name <> " must be a valid DD/MM/YYYY date",
      ))
  }
}

fn status_from_cgu(
  status: String,
  avaliacao_cgu: String,
) -> Result(sta.VerificationStatus, Nil) {
  case normalise_status(status), normalise_status(avaliacao_cgu) {
    "verificado", "cumpre" -> Ok(sta.Conform)
    "verificado", "nao_cumpre" -> Ok(sta.NonConform)
    "verificado", "cumpre_parcialmente" -> Ok(sta.NonConform)
    _, "" -> Ok(sta.NotVerified)
    _, _ -> Error(Nil)
  }
}

fn rows_to_sta(rows: List(SeenRow)) -> Result(List(sta.STA), ParseError) {
  let grouped =
    list.fold(rows, dict.new(), fn(grouped, row) {
      let item =
        sta.STAItem(
          source_key: row.source_key,
          url: row.item_url,
          status: row.status,
          current_archive_date: row.current_archive_date,
          archive_fallback_dates: row.archive_fallback_dates,
          metadata_json: row.metadata_json,
        )

      let items = case dict.get(grouped, row.sta_id) {
        Ok(items) -> [item, ..items]
        Error(Nil) -> [item]
      }

      dict.insert(grouped, row.sta_id, items)
    })

  grouped
  |> dict.to_list
  |> list.map(fn(pair) {
    sta.STA(id: unsafe_sta_id(pair.0), items: list.reverse(pair.1))
  })
  |> Ok
}

fn source_key(row: RawRow) -> String {
  workbook_name(row.file_name)
  <> "\n"
  <> int.to_string(row.row_number)
  <> "\n"
  <> normalise_key_part(row.assunto)
  <> "\n"
  <> normalise_key_part(row.item_text)
  <> "\n"
  <> normalise_key_part(row.item_url)
}

fn metadata(row: RawRow) -> String {
  json.object([
    #("source_file", json.string(workbook_name(row.file_name))),
    #("source_path", json.string(row.file_name)),
    #("row_number", json.int(row.row_number)),
    #("assunto", json.string(row.assunto)),
    #("item", json.string(row.item_text)),
    #("resposta_orgao", json.string(row.resposta_orgao)),
    #("data_atualizacao", json.string(row.data_atualizacao)),
    #("data_avaliacao_cgu", json.string(row.data_avaliacao_cgu)),
    #("status_raw", json.string(row.status)),
    #("avaliacao_cgu", json.string(row.avaliacao_cgu)),
  ])
  |> json.to_string
}

fn archive_fallback_dates(update_date: Date) -> List(String) {
  [
    subtract_month(update_date) |> format_wayback_date,
    subtract_days(update_date, 7) |> format_wayback_date,
    subtract_days(update_date, 1) |> format_wayback_date,
    format_wayback_date(update_date),
  ]
  |> dedupe_strings([])
}

fn dedupe_strings(values: List(String), seen: List(String)) -> List(String) {
  case values {
    [] -> list.reverse(seen)
    [value, ..rest] ->
      case list.contains(seen, value) {
        True -> dedupe_strings(rest, seen)
        False -> dedupe_strings(rest, [value, ..seen])
      }
  }
}

fn parse_br_date(value: String) -> Result(Date, Nil) {
  case string.split(string.trim(value), on: "/") {
    [day_text, month_text, year_text] -> {
      use day <- result.try(int.parse(day_text))
      use month <- result.try(int.parse(month_text))
      use year <- result.try(int.parse(year_text))
      case valid_date(year, month, day) {
        True -> Ok(Date(year:, month:, day:))
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn valid_date(year: Int, month: Int, day: Int) -> Bool {
  case calendar.month_from_int(month) {
    Ok(month) -> calendar.is_valid_date(calendar.Date(year, month, day))
    Error(Nil) -> False
  }
}

fn subtract_month(date: Date) -> Date {
  let Date(year:, month:, day:) = date
  let #(year, month) = case month {
    1 -> #(year - 1, 12)
    _ -> #(year, month - 1)
  }
  Date(year:, month:, day: clamp_day(year, month, day))
}

fn subtract_days(date: Date, days: Int) -> Date {
  case days <= 0 {
    True -> date
    False -> subtract_days(previous_day(date), days - 1)
  }
}

fn previous_day(date: Date) -> Date {
  let Date(year:, month:, day:) = date
  case day > 1 {
    True -> Date(year:, month:, day: day - 1)
    False -> {
      let #(year, month) = case month {
        1 -> #(year - 1, 12)
        _ -> #(year, month - 1)
      }
      Date(year:, month:, day: days_in_month(year, month))
    }
  }
}

fn clamp_day(year: Int, month: Int, day: Int) -> Int {
  let max_day = days_in_month(year, month)
  case day > max_day {
    True -> max_day
    False -> day
  }
}

fn days_in_month(year: Int, month: Int) -> Int {
  case month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
    4 | 6 | 9 | 11 -> 30
    2 ->
      case calendar.is_leap_year(year) {
        True -> 29
        False -> 28
      }
    _ -> 30
  }
}

fn format_wayback_date(date: Date) -> String {
  int.to_string(date.year) <> pad2(date.month) <> pad2(date.day)
}

fn pad2(value: Int) -> String {
  case value < 10 {
    True -> "0" <> int.to_string(value)
    False -> int.to_string(value)
  }
}

fn sta_id_from_file(file_name: String) -> String {
  file_name
  |> workbook_name
  |> string.replace(each: ".xlsx", with: "")
  |> string.replace(each: "informacoesDetalhadasSTA - ", with: "")
  |> string.trim
}

fn workbook_name(path: String) -> String {
  basename(path)
}

fn basename(path: String) -> String {
  path
  |> string.split(on: "/")
  |> list.last
  |> result.unwrap(path)
}

fn normalise_key_part(value: String) -> String {
  value
  |> string.trim
  |> string.lowercase
}

fn normalise_header(value: String) -> String {
  value
  |> string.trim
  |> string.lowercase
  |> string.replace(each: "ã", with: "a")
  |> string.replace(each: "ç", with: "c")
  |> string.replace(each: " ", with: "")
  |> string.replace(each: "_", with: "")
}

fn normalise_status(value: String) -> String {
  value
  |> string.trim
  |> string.lowercase
  |> string.replace(each: "ã", with: "a")
  |> string.replace(each: "á", with: "a")
  |> string.replace(each: "à", with: "a")
  |> string.replace(each: "é", with: "e")
  |> string.replace(each: "í", with: "i")
  |> string.replace(each: "ó", with: "o")
  |> string.replace(each: "ú", with: "u")
  |> string.replace(each: " ", with: "_")
}

fn index_of(values: List(String), name: String) -> Result(Int, Nil) {
  index_of_loop(values, name, 0)
}

fn index_of_loop(
  values: List(String),
  name: String,
  index: Int,
) -> Result(Int, Nil) {
  case values {
    [] -> Error(Nil)
    [value, ..rest] ->
      case value == name {
        True -> Ok(index)
        False -> index_of_loop(rest, name, index + 1)
      }
  }
}

fn get(values: List(String), index: Int) -> String {
  case values, index {
    [], _ -> ""
    [value, ..], 0 -> value
    [_, ..rest], _ -> get(rest, index - 1)
  }
}

fn unsafe_sta_id(value: String) -> sta.STAId {
  let assert Ok(id) = sta.sta_id(value)
  id
}
