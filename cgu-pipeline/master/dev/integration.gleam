import cigogne
import cigogne/config as cigogne_config
import gleam/bit_array
import gleam/erlang/process.{type Pid}
import gleam/int
import gleam/io
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import master/storage
import pog
import test_containers
import testcontainer/error as tc_error

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

pub type Error {
  Container(test_containers.ContainerError)
  DatabaseConfig
  DatabaseStart
  Migration(cigogne.CigogneError)
  Query(pog.QueryError)
  Storage(storage.StorageError)
  StoredBodyMismatch
}

type Db {
  Db(pid: Pid, connection: pog.Connection)
}

pub fn main() {
  case run() {
    Ok(_) -> {
      io.println("Integration passed")
      Nil
    }
    Error(error) -> {
      io.println_error("Integration failed: " <> describe(error))
      halt(1)
    }
  }
}

pub fn run() -> Result(Nil, Error) {
  use postgres <- with_postgres()
  use bucket <- with_bucket()

  let test_containers.Postgres(database_url:) = postgres
  let test_containers.Bucket(config: storage_config) = bucket

  use db <- result.try(start_db(database_url))
  let Db(connection:, ..) = db
  use _ <- result.try(apply_migrations(connection))
  use _ <- result.try(assert_migrated(connection))
  use _ <- result.try(
    storage.ensure_bucket(storage_config)
    |> result.map_error(Storage),
  )
  use _ <- result.try(assert_storage(storage_config))
  stop_db(db)

  Ok(Nil)
}

fn with_postgres(body: fn(test_containers.Postgres) -> Result(a, Error)) {
  test_containers.with_postgres(body, Container)
}

fn with_bucket(body: fn(test_containers.Bucket) -> Result(a, Error)) {
  test_containers.with_bucket(body, Container)
}

fn start_db(database_url: String) -> Result(Db, Error) {
  let name = process.new_name(prefix: "master_dev_integration_db")
  use config <- result.try(
    pog.url_config(name, database_url)
    |> result.map_error(fn(_) { DatabaseConfig }),
  )

  case pog.start(config) {
    Ok(actor.Started(pid:, data: connection)) -> Ok(Db(pid:, connection:))
    Error(_) -> Error(DatabaseStart)
  }
}

fn stop_db(db: Db) -> Nil {
  process.send_exit(db.pid)
}

fn apply_migrations(db: pog.Connection) -> Result(Nil, Error) {
  let config =
    cigogne_config.Config(
      database: cigogne_config.ConnectionDbConfig(db),
      migration_table: cigogne_config.default_mig_table_config,
      migrations: cigogne_config.MigrationsConfig(
        application_name: "master",
        migration_folder: option.None,
        dependencies: [],
        no_hash_check: option.None,
      ),
    )

  use engine <- result.try(
    cigogne.create_engine(config)
    |> result.map_error(Migration),
  )
  cigogne.apply_all(engine)
  |> result.map_error(Migration)
}

fn assert_migrated(db: pog.Connection) -> Result(Nil, Error) {
  use returned <- result.try(
    pog.query("select count(*) from work_item")
    |> pog.execute(on: db)
    |> result.map_error(Query),
  )

  case returned.rows {
    [Nil] -> Ok(Nil)
    _ -> Error(Query(pog.UnexpectedResultType([])))
  }
}

fn assert_storage(config: storage.Config) -> Result(Nil, Error) {
  let body = <<"integration body">>
  use stored <- result.try(
    storage.store(config, body)
    |> result.map_error(Storage),
  )

  case
    stored.body_size_bytes == bit_array.byte_size(body),
    stored.storage_content_encoding == storage.content_encoding,
    string.starts_with(stored.storage_url, "s3://" <> config.bucket_name <> "/")
  {
    True, True, True -> Ok(Nil)
    _, _, _ -> Error(StoredBodyMismatch)
  }
}

fn describe(error: Error) -> String {
  case error {
    Container(test_containers.ContainerError(error)) ->
      "container setup failed: " <> describe_container_error(error)
    DatabaseConfig -> "database URL could not be parsed"
    DatabaseStart -> "database pool did not start"
    Migration(error) -> "migration failed: " <> string.inspect(error)
    Query(error) -> "database query failed: " <> string.inspect(error)
    Storage(error) -> "storage failed: " <> storage.describe_error(error)
    StoredBodyMismatch -> "stored body metadata did not match expectations"
  }
}

fn describe_container_error(error: tc_error.Error) -> String {
  case error {
    tc_error.DockerUnavailable(socket_path, reason) ->
      "Docker unavailable at "
      <> inspected(socket_path)
      <> ": "
      <> inspected(reason)
    tc_error.ImagePullFailed(image, reason) ->
      "could not pull " <> inspected(image) <> ": " <> inspected(reason)
    tc_error.ContainerCreateFailed(image, reason) ->
      "could not create " <> inspected(image) <> ": " <> inspected(reason)
    tc_error.ContainerStartFailed(container_id, reason) ->
      "could not start " <> inspected(container_id) <> ": " <> inspected(reason)
    tc_error.ContainerStopFailed(container_id, reason) ->
      "could not stop " <> inspected(container_id) <> ": " <> inspected(reason)
    tc_error.WaitTimedOut(strategy, elapsed_ms) ->
      "wait timed out for "
      <> strategy
      <> " after "
      <> int.to_string(elapsed_ms)
      <> "ms"
    tc_error.WaitFailed(strategy, reason) ->
      "wait failed for " <> strategy <> ": " <> inspected(reason)
    tc_error.ExecFailed(container_id, cmd, exit_code, stderr) ->
      "exec failed in "
      <> container_id
      <> " running "
      <> string.inspect(cmd)
      <> " with exit "
      <> int.to_string(exit_code)
      <> ": "
      <> inspected(stderr)
    tc_error.PortNotMapped(port) ->
      "container port not mapped: " <> int.to_string(port)
    tc_error.FileCopyFailed(path, reason) ->
      "file copy failed for " <> inspected(path) <> ": " <> inspected(reason)
    tc_error.PortMappingParseFailed(container_id, reason) ->
      "could not parse port mapping for "
      <> inspected(container_id)
      <> ": "
      <> inspected(reason)
    tc_error.DockerApiError(method, path, status, body) ->
      method
      <> " "
      <> path
      <> " returned "
      <> int.to_string(status)
      <> ": "
      <> inspected(body)
    tc_error.InvalidImageRef(raw) ->
      "invalid image reference: " <> inspected(raw)
    tc_error.InvalidPort(port) -> "invalid port: " <> int.to_string(port)
  }
}

fn inspected(value: a) -> String {
  string.inspect(value)
}
