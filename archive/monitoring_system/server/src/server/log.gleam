import gleam/string
import pog
import wisp

pub fn error(action: String, detail: String) -> Nil {
  wisp.log_error(action <> ": " <> detail)
}

pub fn query_error(action: String, query_error: pog.QueryError) -> Nil {
  error(action, string.inspect(query_error))
}

pub fn query_cardinality_error(action: String, expected: String) -> Nil {
  error(action, "query returned rows that do not match expected " <> expected)
}

pub fn result_error(action: String, attempt: Result(a, String)) -> Nil {
  case attempt {
    Ok(_) -> Nil
    Error(detail) -> error(action, detail)
  }
}
