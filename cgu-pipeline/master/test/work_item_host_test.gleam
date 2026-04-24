import gleeunit/should
import master/work_items/host

pub fn extracts_lowercase_http_host_test() {
  host.from_url("https://Portal.Example.Gov/path?x=1")
  |> should.equal(Ok("portal.example.gov"))
}

pub fn rejects_non_http_url_test() {
  host.from_url("mailto:admin@example.gov")
  |> should.equal(Error(Nil))
}
