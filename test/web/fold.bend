import Base
import ../../src/core/model.bend as M
import ../../src/core/fold.bend as F
import ../../src/web/view.bend as V
import ../../src/web/dom.bend as D

def Test.role(role: Nat) -> F.Role:
  match role:
    case 0n:
      F.RHead{"step", "Design change", False{}}
    case 1n:
      F.RIn{False{}}
    case _:
      F.RWork{"work:step", "Work", False{}, F.RShow{}}

def closed(summary: String, role: Nat) -> List<&2, D.Node>:
  V.View.role(Test.role(role), M.Act{"step", "t", "step", "kicad", summary, 0n}, M.State.empty(), "t")
