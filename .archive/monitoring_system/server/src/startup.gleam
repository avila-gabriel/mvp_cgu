import cigogne
import cigogne/config
import clockwork
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/option.{None}
import gleam/result
import m25
import pog
import server/clock
import server/monitor
import server/monitor/clock as monitor_clock
import server/release
import server/release/clock as release_clock
import server/score
import server/score/clock as score_clock
import server/web.{type Context, Context}
import server/web/error
import server/web/evaluation
import wisp

pub type Startup {
  Startup(
    port: Int,
    secret_key_base: String,
    migration_engine: cigogne.MigrationEngine,
    clocks: List(clock.Clock),
    jobs: m25.M25,
    context: Context,
  )
}

pub fn check() -> Startup {
  let db_name = process.new_name(prefix: "server_db_pool")
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
    as "DATABASE_URL is required"
  let assert Ok(port) = envoy.get("PORT") |> result.try(int.parse)
    as "PORT is required and must be an integer"
  let secret_key_base = wisp.random_string(64)
  let assert Ok(db_config) = pog.url_config(db_name, database_url)
    as "DATABASE_URL is invalid"

  let assert Ok(_) = pog.start(db_config) as "database pool failed to start"
  let db = pog.named_connection(db_name)
  let assert Ok(pog.Returned(rows: [1], ..)) =
    "select 1;"
    |> pog.query
    |> pog.returning(health_decoder())
    |> pog.execute(db)
    as "database health check failed"

  let assert Ok(migration_engine) =
    config.Config(
      database: config.UrlDbConfig(database_url),
      migration_table: config.MigrationTableConfig(schema: None, table: None),
      migrations: config.MigrationsConfig(
        application_name: "server",
        migration_folder: None,
        dependencies: [],
        no_hash_check: None,
      ),
    )
    |> cigogne.create_engine
    as "cigogne engine failed to be created"

  let assert Ok(_) = evaluation.check()
    as "server/web/evaluation.extension_origin is invalid"
  let assert Ok(_) = error.check()
    as "server/web/error.extension_origin is invalid"
  let assert Ok(monitor_cron) =
    clockwork.from_string(monitor_clock.cron_expression)
    as "server/monitor/clock.cron_expression is invalid"
  let assert Ok(score_cron) = clockwork.from_string(score_clock.cron_expression)
    as "server/score/clock.cron_expression is invalid"
  let assert Ok(release_cron) =
    clockwork.from_string(release_clock.cron_expression)
    as "server/release/clock.cron_expression is invalid"

  let assert Ok(jobs) =
    m25.new(db)
    |> m25.add_queue(monitor.queue(db))
    |> result.try(m25.add_queue(_, score.queue(db)))
    |> result.try(m25.add_queue(_, release.queue(db)))
    as "m25 failed to register queues"

  let clocks = [
    monitor_clock.clock(db, monitor_cron),
    score_clock.clock(db, score_cron),
    release_clock.clock(db, release_cron),
  ]

  Startup(
    port:,
    secret_key_base:,
    migration_engine:,
    clocks:,
    jobs:,
    context: Context(db:),
  )
}

pub fn main() -> Nil {
  let _ = check()
  Nil
}

fn health_decoder() -> decode.Decoder(Int) {
  {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }
}
