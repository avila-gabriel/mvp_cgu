import gleam/int
import gleam/list
import gleam/order
import gleam/string

pub type Worker {
  Worker(worker_id: String, capacity: Int)
}

pub type Assignment {
  Assignment(worker_id: String, assigned_slots: Int)
}

type SlotState {
  SlotState(worker_id: String, capacity: Int, assigned_slots: Int)
}

pub fn assign(global_slots: Int, workers: List(Worker)) -> List(Assignment) {
  let workers =
    workers
    |> list.sort(compare_workers)
    |> list.map(fn(worker) {
      let Worker(worker_id:, capacity:) = worker
      Worker(worker_id:, capacity: int.max(capacity, 0))
    })

  let budget = int.min(int.max(global_slots, 0), total_capacity(workers))

  case workers, budget {
    [], _ -> []
    _, 0 ->
      list.map(workers, fn(worker) {
        let Worker(worker_id:, ..) = worker
        Assignment(worker_id:, assigned_slots: 0)
      })
    _, _ ->
      workers
      |> list.map(fn(worker) {
        let Worker(worker_id:, capacity:) = worker
        SlotState(worker_id:, capacity:, assigned_slots: 0)
      })
      |> distribute(budget)
      |> list.map(fn(state) {
        let SlotState(worker_id:, assigned_slots:, ..) = state
        Assignment(worker_id:, assigned_slots:)
      })
  }
}

fn distribute(states: List(SlotState), budget: Int) -> List(SlotState) {
  case budget <= 0 {
    True -> states
    False -> {
      let #(states, remaining_budget, changed) =
        distribute_pass(states, budget, [], False)
      case changed {
        True -> distribute(states, remaining_budget)
        False -> states
      }
    }
  }
}

fn distribute_pass(
  states: List(SlotState),
  budget: Int,
  acc: List(SlotState),
  changed: Bool,
) -> #(List(SlotState), Int, Bool) {
  case states {
    [] -> #(list.reverse(acc), budget, changed)
    [state, ..rest] -> {
      let SlotState(assigned_slots:, capacity:, ..) = state
      case budget > 0 && assigned_slots < capacity {
        True ->
          distribute_pass(
            rest,
            budget - 1,
            [SlotState(..state, assigned_slots: assigned_slots + 1), ..acc],
            True,
          )
        False -> distribute_pass(rest, budget, [state, ..acc], changed)
      }
    }
  }
}

fn total_capacity(workers: List(Worker)) -> Int {
  list.fold(workers, 0, fn(total, worker) {
    let Worker(capacity:, ..) = worker
    total + capacity
  })
}

fn compare_workers(a: Worker, b: Worker) -> order.Order {
  let Worker(worker_id: a_id, ..) = a
  let Worker(worker_id: b_id, ..) = b
  string.compare(a_id, b_id)
}
