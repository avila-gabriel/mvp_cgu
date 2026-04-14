import gleam/dynamic/decode
import gleam/http/response.{Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import rsvp
import shared/inbox

pub fn main() {
  let app = lustre.application(init, update, view)
  case lustre.start(app, "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

type Model {
  Model(
    queue: List(inbox.QueueEntry),
    loading: LoadingState,
    claiming: Option(String),
    error: Option(String),
    poll_id: Int,
    expanded_entry: Option(String),
  )
}

type LoadingState {
  FirstLoad
  Loaded
}

type Message {
  QueueLoaded(Result(List(inbox.QueueEntry), rsvp.Error))
  PollTicked(Int)
  UserRequestedClaim(String)
  ClaimFinished(String, Result(Nil, rsvp.Error))
  UserToggledEntryDetails(String)
}

fn init(_) -> #(Model, Effect(Message)) {
  #(
    Model(
      queue: [],
      loading: FirstLoad,
      claiming: None,
      error: None,
      poll_id: 0,
      expanded_entry: None,
    ),
    fetch_queue(),
  )
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    QueueLoaded(Ok(queue)) -> {
      let poll_id = model.poll_id + 1
      let expanded_entry = keep_expanded_entry(model.expanded_entry, queue)

      #(
        Model(
          ..model,
          queue: queue,
          loading: Loaded,
          error: None,
          poll_id: poll_id,
          expanded_entry: expanded_entry,
        ),
        schedule_queue_update(poll_id),
      )
    }

    QueueLoaded(Error(error)) -> {
      let poll_id = model.poll_id + 1

      #(
        Model(..model, error: Some(describe_error(error)), poll_id: poll_id),
        schedule_queue_update(poll_id),
      )
    }

    PollTicked(poll_id) ->
      case poll_id == model.poll_id, model.claiming {
        False, _ -> #(model, effect.none())
        True, None -> #(model, fetch_queue())
        True, Some(_) -> #(model, schedule_queue_update(poll_id))
      }

    UserRequestedClaim(evaluation_id) -> #(
      Model(..model, claiming: Some(evaluation_id), error: None),
      claim_evaluation(evaluation_id),
    )

    ClaimFinished(_, Ok(Nil)) -> {
      let poll_id = model.poll_id + 1

      #(
        Model(..model, claiming: None, error: None, poll_id: poll_id),
        fetch_queue(),
      )
    }

    ClaimFinished(_, Error(error)) -> #(
      Model(..model, claiming: None, error: Some(describe_error(error))),
      effect.none(),
    )

    UserToggledEntryDetails(evaluation_id) -> #(
      Model(
        ..model,
        expanded_entry: toggle_expanded_entry(
          model.expanded_entry,
          evaluation_id,
        ),
      ),
      effect.none(),
    )
  }
}

fn fetch_queue() -> Effect(Message) {
  let handler =
    rsvp.expect_json(decode.list(inbox.entry_decoder()), QueueLoaded)
  rsvp.get("/api/inbox/queue", handler)
}

fn claim_evaluation(evaluation_id: String) -> Effect(Message) {
  let handler =
    rsvp.expect_ok_response(fn(result) {
      case result {
        Ok(_) -> ClaimFinished(evaluation_id, Ok(Nil))
        Error(error) -> ClaimFinished(evaluation_id, Error(error))
      }
    })

  rsvp.post("/inbox/" <> evaluation_id <> "/claim", json.object([]), handler)
}

fn schedule_queue_update(poll_id: Int) -> Effect(Message) {
  use dispatch <- effect.from
  use <- set_timeout(2000)

  dispatch(PollTicked(poll_id))
}

@external(javascript, "./client.ffi.mjs", "set_timeout")
fn set_timeout(_delay: Int, _cb: fn() -> a) -> Nil {
  Nil
}

fn keep_expanded_entry(
  expanded_entry: Option(String),
  queue: List(inbox.QueueEntry),
) -> Option(String) {
  case expanded_entry {
    None -> None
    Some(evaluation_id) ->
      case list.any(queue, fn(entry) { entry.evaluation_id == evaluation_id }) {
        True -> Some(evaluation_id)
        False -> None
      }
  }
}

fn toggle_expanded_entry(
  expanded_entry: Option(String),
  evaluation_id: String,
) -> Option(String) {
  case expanded_entry {
    Some(active_evaluation_id) if active_evaluation_id == evaluation_id -> None
    _ -> Some(evaluation_id)
  }
}

fn describe_error(error: rsvp.Error) -> String {
  case error {
    rsvp.BadBody ->
      "O servidor retornou um conteúdo que não pôde ser lido pelo cliente."
    rsvp.BadUrl(_) -> "Não foi possível montar a requisição corretamente."
    rsvp.HttpError(Response(status:, ..)) ->
      "Não foi possível concluir a ação no momento."
      <> " O servidor respondeu com o status "
      <> int.to_string(status)
      <> "."
    rsvp.JsonError(_) ->
      "O servidor retornou uma resposta em um formato diferente do esperado."
    rsvp.NetworkError -> "Não foi possível conectar ao servidor."
    rsvp.UnhandledResponse(_) ->
      "Recebemos uma resposta inesperada do servidor."
  }
}

fn view(model: Model) -> Element(Message) {
  html.main([attribute.class("min-h-screen bg-zinc-50 text-zinc-950")], [
    html.div([attribute.class("mx-auto max-w-5xl px-4 py-6 sm:px-6 lg:px-8")], [
      html.header([attribute.class("mb-6")], [
        html.h1([attribute.class("text-2xl font-semibold")], [
          html.text("Fila de reavaliação"),
        ]),
      ]),
      view_queue(model),
    ]),
  ])
}

fn view_queue(model: Model) -> Element(Message) {
  case model.loading, model.queue {
    FirstLoad, _ -> view_skeleton_queue()
    Loaded, [] -> view_empty_state()
    Loaded, queue ->
      keyed.ul([attribute.class("flex flex-col gap-4")], {
        list.map(queue, fn(entry) {
          #(entry.evaluation_id, html.li([], [view_entry(model, entry)]))
        })
      })
  }
}

fn view_skeleton_queue() -> Element(Message) {
  html.ul(
    [attribute.class("flex flex-col gap-4")],
    list.repeat(view_skeleton_card(), 5),
  )
}

fn view_skeleton_card() -> Element(Message) {
  html.li(
    [
      attribute.class(
        "rounded-3xl border border-zinc-200 bg-white p-5 animate-pulse",
      ),
    ],
    [
      html.div([attribute.class("h-4 w-1/3 bg-zinc-200 rounded mb-3")], []),
      html.div([attribute.class("h-3 w-2/3 bg-zinc-200 rounded mb-4")], []),
      html.div([attribute.class("h-3 w-full bg-zinc-200 rounded mb-2")], []),
      html.div([attribute.class("h-3 w-5/6 bg-zinc-200 rounded mb-4")], []),
      html.div([attribute.class("h-8 w-32 bg-zinc-200 rounded")], []),
    ],
  )
}

fn view_empty_state() -> Element(Message) {
  html.div([attribute.class("text-center text-zinc-600")], [
    html.text("Nenhum item priorizado disponível no momento."),
  ])
}

fn view_entry(model: Model, entry: inbox.QueueEntry) -> Element(Message) {
  let claim_in_progress = case model.claiming {
    Some(id) -> id == entry.evaluation_id
    None -> False
  }

  let is_expanded = case model.expanded_entry {
    Some(id) -> id == entry.evaluation_id
    None -> False
  }

  html.article(
    [attribute.class("rounded-3xl border border-zinc-200 bg-white p-5")],
    [
      html.div([attribute.class("flex justify-between items-start")], [
        html.div([], [
          html.h3([], [html.text(entry.organization_name)]),
          html.p([attribute.class("text-sm text-zinc-500")], [
            html.text(entry.base_url),
          ]),
        ]),
        html.button(
          [
            event.on_click(UserRequestedClaim(entry.evaluation_id)),
            attribute.class("bg-zinc-900 text-white px-4 py-2 rounded-xl"),
          ],
          [html.text(claim_label(claim_in_progress))],
        ),
      ]),
      case entry.priority_summary {
        Some(reason) ->
          html.p([attribute.class("mt-3 text-sm")], [html.text(reason)])
        None -> html.span([], [])
      },
      html.button(
        [
          event.on_click(UserToggledEntryDetails(entry.evaluation_id)),
          attribute.class("mt-3 text-sm text-zinc-600"),
        ],
        [html.text(details_toggle_label(is_expanded))],
      ),
      case is_expanded, entry.explanation_summary {
        True, Some(expl) ->
          html.p([attribute.class("mt-2 text-sm text-zinc-700")], [
            html.text(expl),
          ])
        _, _ -> html.span([], [])
      },
    ],
  )
}

fn details_toggle_label(is_expanded: Bool) -> String {
  case is_expanded {
    True -> "Ocultar detalhes"
    False -> "Ver detalhes"
  }
}

fn claim_label(in_progress: Bool) -> String {
  case in_progress {
    True -> "Pegando..."
    False -> "Pegar revisão"
  }
}
