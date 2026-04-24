import cigogne
import cigogne/config
import gleam/erlang/process
import gleam/option.{None}
import master/router
import master/storage
import master/web.{Context}
import mist
import pog
import startup
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()
  let startup.Startup(port:, database_url:, secret_key_base:, storage_config:) =
    startup.load()
  let db_name = process.new_name(prefix: "master_db_pool")
  let assert Ok(db_config) = pog.url_config(db_name, database_url)
    as "DATABASE_URL is invalid"

  let assert Ok(_) = pog.start(db_config) as "database pool failed to start"
  let db = pog.named_connection(db_name)
  let assert Ok(engine) =
    config.Config(
      database: config.UrlDbConfig(database_url),
      migration_table: config.MigrationTableConfig(schema: None, table: None),
      migrations: config.MigrationsConfig(
        application_name: "master",
        migration_folder: None,
        dependencies: [],
        no_hash_check: None,
      ),
    )
    |> cigogne.create_engine
    as "migration engine failed"
  let assert Ok(_) = cigogne.apply_all(engine) as "migration failed"
  let assert Ok(_) = storage.ensure_bucket(storage_config)
    as "bucket storage must be reachable or creatable"

  let context = Context(db:, storage: storage_config)
  let assert Ok(_) =
    router.handle_request(_, context)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start
    as "mist start failed"

  process.sleep_forever()
}
