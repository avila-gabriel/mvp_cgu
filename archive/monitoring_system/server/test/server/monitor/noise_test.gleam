import gleam/option.{None, Some}
import server/monitor/model
import server/monitor/noise

pub fn page_keeps_noisy_change_when_item_matches_test() {
  todo as "candidate.page should keep a noisy change when an active evaluation item makes it relevant"
}

pub fn page_ignores_noisy_change_when_no_item_matches_test() {
  todo as "candidate.page should ignore a noisy change when no active evaluation item makes it relevant"
}

pub fn page_keeps_non_noisy_change_as_candidate_test() {
  todo as "candidate.page should keep a non noisy change as a candidate"
}

pub fn item_returns_reason_for_matching_evaluation_item_test() {
  todo as "candidate.item should return the matching evaluation item reason when a change stays relevant"
}

pub fn whitespace_only_change_test() {
  let evidence =
    model.Evidence(
      path: "/policy",
      before: Some(
        page(
          html: "<main>\n  <p>Accessible policy</p>\n</main>",
          text: "Accessible policy",
          link: [],
        ),
      ),
      after: page(
        html: "<main> <p>Accessible policy</p> </main>",
        text: "Accessible policy",
        link: [],
      ),
    )

  assert noise.whitespace(evidence) == Some(model.Whitespace)
}

pub fn timestamp_only_change_test() {
  let evidence =
    model.Evidence(
      path: "/news",
      before: Some(
        page(
          html: "<main><p>Updated 2026-04-16 09:30</p></main>",
          text: "Updated 2026-04-16 09:30",
          link: [],
        ),
      ),
      after: page(
        html: "<main><p>Updated 2026-04-17 10:45</p></main>",
        text: "Updated 2026-04-17 10:45",
        link: [],
      ),
    )

  assert noise.timestamp(evidence) == Some(model.Timestamp)
}

pub fn query_only_change_test() {
  let evidence =
    model.Evidence(
      path: "/downloads",
      before: Some(
        page(
          html: "<a href=\"/report.pdf?v=1\">Report</a>",
          text: "Report",
          link: ["/report.pdf?v=1"],
        ),
      ),
      after: page(
        html: "<a href=\"/report.pdf?v=2\">Report</a>",
        text: "Report",
        link: ["/report.pdf?v=2"],
      ),
    )

  assert noise.query(evidence) == Some(model.Query)
}

pub fn substantive_change_is_not_timestamp_noise_test() {
  let evidence =
    model.Evidence(
      path: "/news",
      before: Some(
        page(
          html: "<main><p>Updated 2026-04-16 09:30</p></main>",
          text: "Updated 2026-04-16 09:30",
          link: [],
        ),
      ),
      after: page(
        html: "<main><p>Policy withdrawn</p></main>",
        text: "Policy withdrawn",
        link: [],
      ),
    )

  assert noise.timestamp(evidence) == None
}

pub fn timestamp_without_baseline_is_not_noise_test() {
  let evidence =
    model.Evidence(
      path: "/news",
      before: None,
      after: page(
        html: "<main><p>Updated 2026-04-17 10:45</p></main>",
        text: "Updated 2026-04-17 10:45",
        link: [],
      ),
    )

  assert noise.timestamp(evidence) == None
}

pub fn whitespace_without_baseline_is_not_noise_test() {
  let evidence =
    model.Evidence(
      path: "/policy",
      before: None,
      after: page(
        html: "<main> <p>Accessible policy</p> </main>",
        text: "Accessible policy",
        link: [],
      ),
    )

  assert noise.whitespace(evidence) == None
}

pub fn substantive_query_change_is_not_noise_test() {
  let evidence =
    model.Evidence(
      path: "/downloads",
      before: Some(
        page(
          html: "<a href=\"/report.pdf?v=1\">Report</a>",
          text: "Report",
          link: ["/report.pdf?v=1"],
        ),
      ),
      after: page(
        html: "<a href=\"/report.pdf?v=2\">Updated report</a>",
        text: "Updated report",
        link: ["/report.pdf?v=2"],
      ),
    )

  assert noise.query(evidence) == None
}

pub fn timestamp_with_link_change_is_not_noise_test() {
  let evidence =
    model.Evidence(
      path: "/news",
      before: Some(
        page(
          html: "<a href=\"/report-a.pdf\"><p>Updated 2026-04-16 09:30</p></a>",
          text: "Updated 2026-04-16 09:30",
          link: ["/report-a.pdf"],
        ),
      ),
      after: page(
        html: "<a href=\"/report-b.pdf\"><p>Updated 2026-04-17 10:45</p></a>",
        text: "Updated 2026-04-17 10:45",
        link: ["/report-b.pdf"],
      ),
    )

  assert noise.timestamp(evidence) == None
}

pub fn whitespace_with_text_change_is_not_noise_test() {
  let evidence =
    model.Evidence(
      path: "/policy",
      before: Some(
        page(
          html: "<main>\n  <p>Accessible policy</p>\n</main>",
          text: "Accessible policy",
          link: [],
        ),
      ),
      after: page(
        html: "<main> <p>Updated policy</p> </main>",
        text: "Updated policy",
        link: [],
      ),
    )

  assert noise.whitespace(evidence) == None
}

fn page(
  html html: String,
  text text: String,
  link link: List(String),
) -> model.Page {
  model.Page(url: "https://example.com", html:, text:, heading: [], link:)
}
