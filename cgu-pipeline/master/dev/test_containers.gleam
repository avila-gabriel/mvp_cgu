import gleam/int
import gleam/result
import master/storage
import testcontainer
import testcontainer/container
import testcontainer/error as tc_error
import testcontainer/port
import testcontainer/wait

pub const postgres_user = "postgres"

pub const postgres_password = "postgres"

pub const postgres_database = "cgu_pipeline_test"

pub const bucket_user = "cgu_pipeline"

pub const bucket_password = "cgu_pipeline_dev_password"

pub const bucket_name = "cgu-pipeline-artifacts"

pub const bucket_region = "us-east-1"

pub type ContainerError {
  ContainerError(tc_error.Error)
}

pub type Postgres {
  Postgres(database_url: String)
}

pub type Bucket {
  Bucket(config: storage.Config)
}

pub fn with_postgres(
  body: fn(Postgres) -> Result(a, e),
  map_error: fn(ContainerError) -> e,
) -> Result(a, e) {
  use postgres <- testcontainer.with_container_mapped(
    container.new("postgres:16-alpine")
      |> container.with_env("POSTGRES_USER", postgres_user)
      |> container.with_env("POSTGRES_PASSWORD", postgres_password)
      |> container.with_env("POSTGRES_DB", postgres_database)
      |> container.expose_port(port.tcp(5432))
      |> container.wait_for(
        wait.command([
          "pg_isready",
          "-U",
          postgres_user,
          "-d",
          postgres_database,
        ]),
      ),
    fn(error) { map_error(ContainerError(error)) },
  )

  use host_port <- result.try(
    container.host_port(postgres, port.tcp(5432))
    |> result.map_error(fn(error) { map_error(ContainerError(error)) }),
  )

  body(Postgres(
    database_url: "postgres://"
    <> postgres_user
    <> ":"
    <> postgres_password
    <> "@"
    <> container.host(postgres)
    <> ":"
    <> int.to_string(host_port)
    <> "/"
    <> postgres_database,
  ))
}

pub fn with_bucket(
  body: fn(Bucket) -> Result(a, e),
  map_error: fn(ContainerError) -> e,
) -> Result(a, e) {
  use bucket <- testcontainer.with_container_mapped(
    container.new("minio/minio:latest")
      |> container.with_env("MINIO_ROOT_USER", bucket_user)
      |> container.with_env("MINIO_ROOT_PASSWORD", bucket_password)
      |> container.expose_port(port.tcp(9000))
      |> container.with_command(["server", "/data"])
      |> container.wait_for(wait.http(9000, "/minio/health/ready")),
    fn(error) { map_error(ContainerError(error)) },
  )

  use host_port <- result.try(
    container.host_port(bucket, port.tcp(9000))
    |> result.map_error(fn(error) { map_error(ContainerError(error)) }),
  )

  body(
    Bucket(storage.Config(
      endpoint_scheme: "http",
      endpoint_host: container.host(bucket),
      endpoint_port: host_port,
      region: bucket_region,
      access_key_id: bucket_user,
      secret_access_key: bucket_password,
      bucket_name:,
      request_timeout_ms: 30_000,
    )),
  )
}
