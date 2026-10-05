import Base
import ../check.bend as C
import ../../src/server/host.bend as H
import ../../src/server/server.bend as S

def Probe.eof(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> Bool:
  match r:
    case Done{Nil{}}:
      True{}
    case _:
      False{}

def Probe.peer_got(got: Socket & Result<&1, &1, U32 & String, List<&2, U32>>, +closed: Chan(Bool)) -> IO(Unit):
  (s2, r) = got
  do IO<Unit>:
    Socket.close(s2)
    ok : Bool <- Chan.send(Bool, closed, Probe.eof(r))
    return Unit{}

def Probe.peer(+closed: Chan(Bool)) -> IO(Unit):
  do IO<Unit>:
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", 3893))
    IO.bind(Socket & Result<&1, &1, U32 & String, List<&2, U32>>, Unit, H.Sock.recv_bytes(s, 8), r => Probe.peer_got(r, closed))

def Probe.notice(m: Maybe<&1, S.Msg>) -> String:
  match m:
    case Some{S.AgentWriteFailed{t, pid, code, reason}}:
      t ++ ":" ++ U32.show(pid) ++ ":" ++ U32.show(code) ++ ":" ++ reason
    case _:
      "missing"

def Probe.continued(s: Socket, +ran: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- Chan.send(Unit, ran, Unit{})
    Socket.close(s)
    return Unit{}

def Probe.ran(m: Maybe<&1, Unit>) -> Bool:
  match m:
    case Some{_}:
      True{}
    case None{}:
      False{}

def Probe.accepted(r: Listener & Result<&1, &1, U32 & String, Socket>, +closed: Chan(Bool)) -> IO(Unit):
  (l, res) = r
  do IO<Unit>:
    Listener.close(l)
    s : Socket <- IO.try(Socket, IO.pure(Result<&1, &1, U32 & String, Socket>, res))
    +input : Chan(String) <- Chan.new(String, 1)
    +inbox : Chan(S.Msg) <- Chan.new(S.Msg, 1)
    +ran : Chan(Unit) <- Chan.new(Unit, 1)
    ok : Bool <- Chan.send(String, input, "queued command")
    S.Agent.wrote((s, Fail{(60, "timeout")}), input, 12345, "thread", inbox, s2 => Probe.continued(s2, ran))
    notice : Maybe<&1, S.Msg> <- Chan.recv(S.Msg, inbox)
    C.Check.str("write failure reaches lifecycle owner", Probe.notice(notice), "thread:12345:60:timeout")
    next : Bool <- Chan.send(String, input, "next command")
    C.Check.str("failed stream rejects new commands", Bool.show(next), "False")
    Chan.close(Unit, ran)
    continued : Maybe<&1, Unit> <- Chan.recv(Unit, ran)
    C.Check.str("failed writer never consumes another command", Bool.show(Probe.ran(continued)), "False")
    eof : Maybe<&1, Bool> <- Chan.recv(Bool, closed)
    C.Check.str("abort releases peer reader", Bool.show(Maybe.default(&1, Bool, eof, False{})), "True")
    Chan.close(S.Msg, inbox)
    Chan.close(Bool, closed)

def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(3893))
    +closed : Chan(Bool) <- Chan.new(Bool, 1)
    IO.spawn(Unit, Probe.peer(closed))
    IO.bind(Listener & Result<&1, &1, U32 & String, Socket>, Unit, TCP.accept(l), r => Probe.accepted(r, closed))
