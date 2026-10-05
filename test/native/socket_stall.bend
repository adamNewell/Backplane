import Base
import ../check.bend as C
import ../../src/server/host.bend as H

def Probe.peer(+done: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    s : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", 3892))
    ack : Maybe<&1, Unit> <- Chan.recv(Unit, done)
    Socket.close(s)
    Chan.close(Unit, done)

def Probe.failed(res: Result<&1, &1, U32 & String, Unit>) -> Bool:
  match res:
    case Fail{_}:
      True{}
    case Done{_}:
      False{}

def Probe.sent(r: Socket & Result<&1, &1, U32 & String, Unit>, +t0: Nat, done: Chan(Unit)) -> IO(Unit):
  (s, res) = r
  do IO<Unit>:
    +t1 : Nat <- IO.now()
    C.Check.str("unread peer cannot stall socket write forever", Bool.show(Probe.failed(res)), "True")
    C.Check.str("write waits for its deadline", Bool.show(Nat.is_ge(Nat.sub(t1, t0), 29000n)), "True")
    C.Check.str("write deadline is bounded", Bool.show(Nat.is_le(Nat.sub(t1, t0), 33000n)), "True")
    IO.print("socket write elapsed ms=" ++ Nat.show(Nat.sub(t1, t0)))
    Socket.close(s)
    ok : Bool <- Chan.send(Unit, done, Unit{})
    return Unit{}

def Probe.accepted(r: Listener & Result<&1, &1, U32 & String, Socket>, +done: Chan(Unit)) -> IO(Unit):
  (l, res) = r
  do IO<Unit>:
    Listener.close(l)
    s : Socket <- IO.try(Socket, IO.pure(Result<&1, &1, U32 & String, Socket>, res))
    t0 : Nat <- IO.now()
    IO.bind(Socket & Result<&1, &1, U32 & String, Unit>, Unit,
      H.Sock.send_bytes(s, List.replicate(U32, 8388608n, 120)), r2 => Probe.sent(r2, t0, done))

def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(3892))
    +done : Chan(Unit) <- Chan.new(Unit, 1)
    IO.spawn(Unit, Probe.peer(done))
    IO.bind(Listener & Result<&1, &1, U32 & String, Socket>, Unit, TCP.accept(l), r => Probe.accepted(r, done))
