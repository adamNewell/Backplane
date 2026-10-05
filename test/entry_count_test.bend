import Base
import ./check.bend as C
import ../src/core/model.bend as M
import ../src/core/far.bend as F

def state() -> M.State:
  M.State.replay([
    M.MessagePosted{"owner", "t:sender:delivery", M.User{}, "forwarded", 0n},
    M.ActivityLogged{"owner", "a", "tool", "shell", "done", 1n},
    M.MessagePosted{"peer~remote", "r", M.Assistant{}, "remote", 2n}
  ], M.State.empty())

def main() -> IO(Unit):
  do IO<Unit>:
    +s : M.State = state()
    C.Check.str("count owner once despite sender index", Nat.show(M.State.entry_count(s, "owner")), "2")
    C.Check.str("sender index does not change ownership", Nat.show(M.State.entry_count(s, "sender")), "0")
    C.Check.str("missing thread counts zero", Nat.show(M.State.entry_count(s, "missing")), "0")
    C.Check.str("remote reset rebuilds ownership counts", Nat.show(M.State.entry_count(F.Fr.forget(s, "peer"), "peer~remote")), "0")
    C.Check.str("remote reset keeps local counts", Nat.show(M.State.entry_count(F.Fr.forget(s, "peer"), "owner")), "2")
