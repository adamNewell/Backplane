import Base
import ../../src/core/client.bend as U
import ../../src/core/model.bend as M
import ../../src/core/json.bend as J
import ../../src/web/app.bend as A

def init() -> U.Ui:
  A.init(0n, "bench")

def recv(u: U.Ui, o: J.Json) -> U.Act:
  A.recv(u, o)

def decode(o: J.Json) -> List<&2, M.Change>:
  U.Ui.decode(J.Json.elems(J.Json.get_obj(o, "items")))

def replay(cs: List<&2, M.Change>) -> M.State:
  M.State.replay(cs, M.State.empty())

def parse(s: String) -> Maybe<&2, J.Json>:
  J.Json.parse(s)


def ingest(u: U.Ui, o: J.Json) -> U.Ui:
  U.Ui.ingest(J.Json.get_obj(o, "items"), u)

def fold(u: U.Ui, o: J.Json) -> U.Ui:
  U.Ui.fold(U.Ui.decode(J.Json.elems(J.Json.get_obj(o, "items"))), u)

def select(u: U.Ui, th: String) -> U.Ui:
  U.Act.ui(U.Ui.act(u, "select", th))

def ready(x: M.Ext, th: String) -> Bool:
  M.Ext.ready(x, th)

def history(s: M.State, th: String) -> List<&2, M.DesignRecord>:
  M.State.design(s, th)
