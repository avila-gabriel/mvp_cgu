import gleam/option.{type Option, None, Some}
import pog

pub fn execute(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  next next: fn() -> return,
) -> return {
  case attempt {
    Ok(_) -> next()
    Error(error) -> on_query(error)
  }
}

pub fn count(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  next next: fn(Int) -> return,
) -> return {
  case attempt {
    Ok(returned) -> next(returned.count)
    Error(error) -> on_query(error)
  }
}

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

pub fn require_many(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_error on_error: return,
  next next: fn(List(row)) -> return,
) -> return {
  query_many(attempt, on_query: ignore(_, returning: on_error), next: next)
}

pub fn query_optional(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  on_cardinality on_cardinality: return,
  next next: fn(Option(row)) -> return,
) -> return {
  case attempt {
    Ok(returned) ->
      case returned.rows {
        [] -> next(None)
        [row] -> next(Some(row))
        _ -> on_cardinality
      }

    Error(error) -> on_query(error)
  }
}

pub fn require_optional(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_error on_error: return,
  next next: fn(Option(row)) -> return,
) -> return {
  query_optional(
    attempt,
    on_query: ignore(_, returning: on_error),
    on_cardinality: on_error,
    next: next,
  )
}

pub fn query_one(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_query on_query: fn(pog.QueryError) -> return,
  on_cardinality on_cardinality: return,
  next next: fn(row) -> return,
) -> return {
  case attempt {
    Ok(returned) ->
      case returned.rows {
        [row] -> next(row)
        _ -> on_cardinality
      }

    Error(error) -> on_query(error)
  }
}

pub fn require_one(
  attempt: Result(pog.Returned(row), pog.QueryError),
  on_error on_error: return,
  next next: fn(row) -> return,
) -> return {
  query_one(
    attempt,
    on_query: ignore(_, returning: on_error),
    on_cardinality: on_error,
    next: next,
  )
}

fn ignore(_ignored: a, returning value: b) -> b {
  value
}
