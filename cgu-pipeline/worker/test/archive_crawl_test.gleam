import gleam/list
import gleeunit
import worker/archive_crawl

pub fn main() {
  gleeunit.main()
}

pub fn unwrap_wayback_href_test() {
  let href =
    archive_crawl.unwrap_wayback_href(
      "https://web.archive.org/web/20220102030405id_/https://example.gov.br/transparencia",
    )

  assert href == "https://example.gov.br/transparencia"
}

pub fn unwrap_arquivo_href_test() {
  let href =
    archive_crawl.unwrap_wayback_href(
      "https://arquivo.pt/wayback/20220102030405id_/https://example.gov.br/transparencia",
    )

  assert href == "https://example.gov.br/transparencia"
}

pub fn unwrap_archive_it_href_test() {
  let href =
    archive_crawl.unwrap_wayback_href(
      "https://wayback.archive-it.org/all/20220102030405id_/https://example.gov.br/transparencia",
    )

  assert href == "https://example.gov.br/transparencia"
}

pub fn normalise_relative_link_test() {
  let href =
    archive_crawl.normalise_link(
      "https://example.gov.br/portal/noticias/index.html",
      [#("href", "../licitacoes?id=10#section")],
    )

  assert href
    == archive_crawl.AcceptedLink(
      "https://example.gov.br/portal/licitacoes?id=10",
    )
}

pub fn missing_href_is_explicit_test() {
  let href =
    archive_crawl.normalise_link(
      "https://example.gov.br/portal/noticias/index.html",
      [#("class", "nav-link")],
    )

  assert href == archive_crawl.RejectedLink(archive_crawl.MissingHref)
}

pub fn invalid_archive_date_test() {
  let resolution =
    archive_crawl.visit(url: "https://example.gov.br", at: "2024-01-011")

  let is_invalid = case resolution.resolution {
    archive_crawl.InvalidArchiveDate(_) -> True
    _ -> False
  }

  assert is_invalid
}

pub fn archive_lookup_candidates_are_exact_first_with_safe_aliases_test() {
  let candidates =
    archive_crawl.archive_lookup_candidates(
      "http://WWW.Example.GOV.BR:80/path?x=1#section",
    )

  let assert [first, ..] = candidates
  let archive_crawl.ArchiveLookup(url: first_url, alias_rule: first_rule) =
    first
  assert first_url == "http://WWW.Example.GOV.BR:80/path?x=1#section"
  assert first_rule == "exact"

  let urls =
    list.map(candidates, fn(candidate) {
      let archive_crawl.ArchiveLookup(url:, ..) = candidate
      url
    })

  assert list.contains(urls, "http://www.example.gov.br/path?x=1")
  assert list.contains(urls, "https://www.example.gov.br/path?x=1")
  assert list.contains(urls, "http://example.gov.br/path?x=1")
  assert list.contains(urls, "https://example.gov.br/path?x=1")
}
