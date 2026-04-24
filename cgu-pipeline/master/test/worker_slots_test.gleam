import gleeunit/should
import master/worker_slots

pub fn no_workers_gets_no_assignments_test() {
  worker_slots.assign(2, [])
  |> should.equal([])
}

pub fn one_worker_gets_global_budget_test() {
  worker_slots.assign(2, [worker_slots.Worker("a", 2)])
  |> should.equal([worker_slots.Assignment("a", 2)])
}

pub fn one_worker_is_capped_by_capacity_test() {
  worker_slots.assign(2, [worker_slots.Worker("a", 1)])
  |> should.equal([worker_slots.Assignment("a", 1)])
}

pub fn two_workers_split_two_slots_test() {
  worker_slots.assign(2, [
    worker_slots.Worker("b", 2),
    worker_slots.Worker("a", 2),
  ])
  |> should.equal([
    worker_slots.Assignment("a", 1),
    worker_slots.Assignment("b", 1),
  ])
}

pub fn capacity_zero_does_not_consume_budget_test() {
  worker_slots.assign(2, [
    worker_slots.Worker("a", 0),
    worker_slots.Worker("b", 2),
    worker_slots.Worker("c", 2),
  ])
  |> should.equal([
    worker_slots.Assignment("a", 0),
    worker_slots.Assignment("b", 1),
    worker_slots.Assignment("c", 1),
  ])
}

pub fn uneven_capacity_redistributes_unused_slots_test() {
  worker_slots.assign(4, [
    worker_slots.Worker("a", 1),
    worker_slots.Worker("b", 3),
  ])
  |> should.equal([
    worker_slots.Assignment("a", 1),
    worker_slots.Assignment("b", 3),
  ])
}
