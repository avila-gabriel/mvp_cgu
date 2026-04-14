import gleam/option.{type Option}

pub type Page {
  Page(
    url: String,
    html: String,
    text: String,
    heading: List(String),
    link: List(String),
  )
}

pub type Evidence {
  Evidence(path: String, before: Option(Page), after: Page)
}

pub type Noise {
  StyleSheet
  StyleTag
  InlineStyle
  Class
  Id
  Script
  Token
  Analytics
  Timestamp
  Query
  Whitespace
  Formatting
  Wrapper
  Footer
  Header
  CookieBanner
  PrivacyBanner
  AccessibilityWidget
  ChatWidget
  Carousel
  AdSlot
  SessionContent
  ForgeryToken
  RandomIdentifier
  AssetHash
  ImageVersion
  RepeatedPattern
}

pub type Classified {
  Classified(evidence: Evidence, noise: List(Noise))
}

pub type Event {
  PageChanged
  PathDiscovered
  PathRemoved
  TopologyChanged
}

pub type Candidate {
  Candidate(path: String, event: Event, summary: String, noise: List(Noise))
}

pub type Decision {
  CandidateDecision(Candidate)
  Ignore(noise: List(Noise))
}
