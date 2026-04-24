import gleam/list
import gleeunit/should
import master/csv_ingest
import shared/sta
import shared/url

pub fn parses_sta_items_test() {
  let csv =
    "sta_url,item_url,status
https://sta.example.gov,https://portal.example.gov/a,not verified
https://sta.example.gov,https://portal.example.gov/b,non-conform
"

  let assert Ok([sta]) = csv_ingest.parse(csv)

  sta.id_to_string(sta.id)
  |> should.equal("https://sta.example.gov")
  sta.items
  |> list.length
  |> should.equal(2)
}

pub fn parses_quoted_csv_fields_test() {
  let csv =
    "sta_url,item_url,status
\"https://sta.example.gov\",\"https://portal.example.gov/a?name=a,b\",conform
"

  let assert Ok([sta]) = csv_ingest.parse(csv)
  let assert [item] = sta.items

  url.to_string(item.url)
  |> should.equal("https://portal.example.gov/a?name=a,b")
  item.status
  |> should.equal(sta.Conform)
}

pub fn rejects_duplicate_sta_item_pair_test() {
  let csv =
    "sta_url,item_url,status
https://sta.example.gov,https://portal.example.gov/a,not_verified
https://sta.example.gov,https://portal.example.gov/a,conform
"

  let assert Error(error) = csv_ingest.parse(csv)

  csv_ingest.parse_error_to_string(error)
  |> should.equal("line 3: duplicate sta_url and item_url")
}

pub fn rejects_malformed_status_test() {
  let csv =
    "sta_url,item_url,status
https://sta.example.gov,https://portal.example.gov/a,maybe
"

  let assert Error(error) = csv_ingest.parse(csv)

  csv_ingest.parse_error_to_string(error)
  |> should.equal(
    "line 2: status must be not_verified, conform, or non_conform",
  )
}
