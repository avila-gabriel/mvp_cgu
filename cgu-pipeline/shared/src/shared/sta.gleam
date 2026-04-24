import gleam/string
import shared/url.{type Url}

pub opaque type STAId {
  STAId(String)
}

pub type VerificationStatus {
  NotVerified
  Conform
  NonConform
}

pub type STAItem {
  STAItem(
    source_key: String,
    url: Url,
    status: VerificationStatus,
    current_archive_date: String,
    archive_fallback_dates: List(String),
    metadata_json: String,
  )
}

pub type STA {
  STA(id: STAId, items: List(STAItem))
}

pub fn sta_id(value: String) -> Result(STAId, Nil) {
  let value = string.trim(value)

  case value {
    "" -> Error(Nil)
    _ -> Ok(STAId(value))
  }
}

pub fn id_to_string(id: STAId) -> String {
  let STAId(value) = id
  value
}

pub fn verification_status_from_string(
  value: String,
) -> Result(VerificationStatus, Nil) {
  case normalise_status(value) {
    "not_verified" -> Ok(NotVerified)
    "conform" -> Ok(Conform)
    "non_conform" -> Ok(NonConform)
    _ -> Error(Nil)
  }
}

pub fn verification_status_to_string(status: VerificationStatus) -> String {
  case status {
    NotVerified -> "not_verified"
    Conform -> "conform"
    NonConform -> "non_conform"
  }
}

fn normalise_status(value: String) -> String {
  value
  |> string.trim
  |> string.lowercase
  |> string.replace(each: "-", with: "_")
  |> string.replace(each: " ", with: "_")
}
