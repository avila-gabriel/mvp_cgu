import gleam/option.{type Option, None, Some}
import pog

pub fn query_many(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  next next: fn(List(row)) -> return,
) -> return {
  case attempt {
    Ok(returned) -> next(returned.rows)
    Error(error) -> on_query(error)
  }
}

pub fn query_optional(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  on_cardinality on_cardinality: fn() -> return,
  next next: fn(Option(row)) -> return,
) -> return {
  case attempt {
    Ok(returned) ->
      case returned.rows {
        [] -> next(None)
        [row] -> next(Some(row))
        _ -> on_cardinality()
      }

    Error(error) -> on_query(error)
  }
}

pub fn query_one(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  on_cardinality on_cardinality: fn() -> return,
  next next: fn(row) -> return,
) -> return {
  case attempt {
    Ok(returned) ->
      case returned.rows {
        [row] -> next(row)
        _ -> on_cardinality()
      }

    Error(error) -> on_query(error)
  }
}
