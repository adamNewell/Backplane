import Base
import ../../src/core/model.bend as M

def project(es: List<&2, M.Entry>, st: M.State) -> M.State:
  match es:
    case Nil{}:
      st
    case e <> t:
      project(t, M.State.post(st, e))

def state(es: List<&2, M.Entry>) -> M.State:
  project(es, M.State.empty())

def count(st: M.State, th: String) -> Nat:
  M.State.entry_count(st, th)
