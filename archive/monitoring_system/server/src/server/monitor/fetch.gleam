import server/monitor/load

pub type Visit {
  Visit(
    url: String,
    final_url: String,
    status: Int,
    body: String,
    link: List(String),
  )
}

pub fn evaluation(_scope: load.Scope) -> Result(List(Visit), String) {
  todo as "fetch monitored URLs, walk the bounded evaluation neighborhood, and collect the raw pages needed for monitoring"
}

pub fn url(_url: load.Url) -> Result(Visit, String) {
  todo as "fetch one monitored URL and extract the response data and discovered links"
}
