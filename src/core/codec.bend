import Base
import ./json.bend as J
import ./model.bend as M

# Changes as JSON: the event log on disk and the change stream to clients
# share this codec, so the browser folds exactly what the server stored.
# An encoded Change is {"$": "<Constructor>", ...fields}. Decoding is total:
# unknown tags answer None (a newer server's log is skipped, not misread).

def Codec.nat(n: Nat) -> J.Json:
  J.Num{Nat.show(n)}

def Codec.str(s: String) -> J.Json:
  J.Str{s}

def Codec.bool(b: Bool) -> J.Json:
  J.Flag{b}

def Codec.index.hit(names: List<&2, String>, +s: String) -> Bool:
  match names:
    case n <> _:
      String.eq(n, s)
    case Nil{}:
      False{}

def Codec.index.go(names: List<&2, String>, hit: Bool, +i: Nat, +s: String) -> Nat:
  match names hit:
    case _ <> _ True{}:
      i
    case _ <> +t False{}:
      Codec.index.go(t, Codec.index.hit(t, s), 1n+i, s)
    case Nil{} _:
      i

def Codec.pos(+names: List<&2, String>, +s: String) -> Nat:
  Codec.index.go(names, Codec.index.hit(names, s), 0n, s)

# Enums
# -----

def Role.name(r: M.Role) -> String:
  match r:
    case M.User{}:
      "user"
    case M.Assistant{}:
      "assistant"
    case M.System{}:
      "system"

def Role.of.k(i: Nat) -> M.Role:
  match i:
    case 0n:
      M.User{}
    case 1n:
      M.Assistant{}
    case _:
      M.System{}

def Role.of(+s: String) -> M.Role:
  Role.of.k(Codec.pos(["user", "assistant", "system"], s))

def Turn.name(t: M.TurnState) -> String:
  match t:
    case M.Idle{}:
      "idle"
    case M.Running{}:
      "running"
    case M.Completed{}:
      "completed"
    case M.Interrupted{}:
      "interrupted"
    case M.Failed{}:
      "failed"

def Turn.of.k(i: Nat) -> M.TurnState:
  match i:
    case 1n:
      M.Running{}
    case 2n:
      M.Completed{}
    case 3n:
      M.Interrupted{}
    case 4n:
      M.Failed{}
    case _:
      M.Idle{}

def Turn.of(+s: String) -> M.TurnState:
  Turn.of.k(Codec.pos(["idle", "running", "completed", "interrupted", "failed"], s))

def Env.name(e: M.EnvMode) -> String:
  match e:
    case M.Local{}:
      "local"
    case M.Worktree{}:
      "worktree"

def Env.of(+s: String) -> M.EnvMode:
  Bool.pick(M.EnvMode, String.eq(s, "worktree"), M.Worktree{}, M.Local{})

def Runtime.name(r: M.RuntimeMode) -> String:
  match r:
    case M.Supervised{}:
      "approval-required"
    case M.AcceptEdits{}:
      "auto-accept-edits"
    case M.AutoMode{}:
      "auto"
    case M.FullAccess{}:
      "full-access"

def Runtime.of.k(i: Nat) -> M.RuntimeMode:
  match i:
    case 0n:
      M.Supervised{}
    case 1n:
      M.AcceptEdits{}
    case 2n:
      M.AutoMode{}
    case _:
      M.FullAccess{}

def Runtime.of(+s: String) -> M.RuntimeMode:
  Runtime.of.k(Codec.pos(["approval-required", "auto-accept-edits", "auto", "full-access"], s))

def Interaction.name(i: M.InteractionMode) -> String:
  match i:
    case M.DefaultMode{}:
      "default"
    case M.PlanMode{}:
      "plan"

def Interaction.of(+s: String) -> M.InteractionMode:
  Bool.pick(M.InteractionMode, String.eq(s, "plan"), M.PlanMode{}, M.DefaultMode{})

def TaskSt.name(t: M.TaskState) -> String:
  match t:
    case M.TaskQueued{}:
      "queued"
    case M.TaskRunning{}:
      "running"
    case M.TaskDone{}:
      "done"
    case M.TaskFailed{}:
      "failed"
    case M.TaskCancelled{}:
      "cancelled"

def TaskSt.of.k(i: Nat) -> M.TaskState:
  match i:
    case 0n:
      M.TaskQueued{}
    case 1n:
      M.TaskRunning{}
    case 2n:
      M.TaskDone{}
    case 3n:
      M.TaskFailed{}
    case _:
      M.TaskCancelled{}

def TaskSt.of(+s: String) -> M.TaskState:
  TaskSt.of.k(Codec.pos(["queued", "running", "done", "failed", "cancelled"], s))

# Changes
# -------

def Change.obj(tag: String, kvs: List<&2, J.KV>) -> J.Json:
  J.Json.obj(J.KV{"$", J.Str{tag}} <> kvs)

def Change.encode(c: M.Change) -> J.Json:
  match c:
    case M.ProjectCreated{id, title, root, at}:
      Change.obj("ProjectCreated", [J.KV{"id", J.Str{id}}, J.KV{"title", J.Str{title}}, J.KV{"root", J.Str{root}}, J.KV{"at", Codec.nat(at)}])
    case M.ProjectRemoved{id, at}:
      Change.obj("ProjectRemoved", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadCreated{id, project, title, env, branch, worktree, provider, model, at}:
      Change.obj("ThreadCreated", [J.KV{"id", J.Str{id}}, J.KV{"project", J.Str{project}}, J.KV{"title", J.Str{title}}, J.KV{"env", J.Str{Env.name(env)}}, J.KV{"branch", J.Str{branch}}, J.KV{"worktree", J.Str{worktree}}, J.KV{"provider", J.Str{provider}}, J.KV{"model", J.Str{model}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadRenamed{id, title, at}:
      Change.obj("ThreadRenamed", [J.KV{"id", J.Str{id}}, J.KV{"title", J.Str{title}}, J.KV{"at", Codec.nat(at)}])
    case M.MessagePosted{thread, msg, role, text, at}:
      Change.obj("MessagePosted", [J.KV{"thread", J.Str{thread}}, J.KV{"msg", J.Str{msg}}, J.KV{"role", J.Str{Role.name(role)}}, J.KV{"text", J.Str{text}}, J.KV{"at", Codec.nat(at)}])
    case M.TurnChanged{thread, state, at}:
      Change.obj("TurnChanged", [J.KV{"thread", J.Str{thread}}, J.KV{"state", J.Str{Turn.name(state)}}, J.KV{"at", Codec.nat(at)}])
    case M.PendingChanged{thread, count, at}:
      Change.obj("PendingChanged", [J.KV{"thread", J.Str{thread}}, J.KV{"count", Codec.nat(count)}, J.KV{"at", Codec.nat(at)}])
    case M.ActivityLogged{thread, act, tone, kind, summary, at}:
      Change.obj("ActivityLogged", [J.KV{"thread", J.Str{thread}}, J.KV{"act", J.Str{act}}, J.KV{"tone", J.Str{tone}}, J.KV{"kind", J.Str{kind}}, J.KV{"summary", J.Str{summary}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadSettled{id, manual, at}:
      Change.obj("ThreadSettled", [J.KV{"id", J.Str{id}}, J.KV{"manual", J.Flag{manual}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadUnsettled{id, at}:
      Change.obj("ThreadUnsettled", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadArchived{id, archived, at}:
      Change.obj("ThreadArchived", [J.KV{"id", J.Str{id}}, J.KV{"archived", J.Flag{archived}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadPinned{id, pinned, at}:
      Change.obj("ThreadPinned", [J.KV{"id", J.Str{id}}, J.KV{"pinned", J.Flag{pinned}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadDeleted{id, at}:
      Change.obj("ThreadDeleted", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.WorktreeSet{id, branch, worktree, at}:
      Change.obj("WorktreeSet", [J.KV{"id", J.Str{id}}, J.KV{"branch", J.Str{branch}}, J.KV{"worktree", J.Str{worktree}}, J.KV{"at", Codec.nat(at)}])
    case M.SessionSet{id, session, at}:
      Change.obj("SessionSet", [J.KV{"id", J.Str{id}}, J.KV{"session", J.Str{session}}, J.KV{"at", Codec.nat(at)}])
    case M.ModesSet{id, runtime, interaction, model, at}:
      Change.obj("ModesSet", [J.KV{"id", J.Str{id}}, J.KV{"runtime", J.Str{Runtime.name(runtime)}}, J.KV{"interaction", J.Str{Interaction.name(interaction)}}, J.KV{"model", J.Str{model}}, J.KV{"at", Codec.nat(at)}])
    case M.TaskDelegated{task, parent, child, depth, provider, model, at}:
      Change.obj("TaskDelegated", [J.KV{"task", J.Str{task}}, J.KV{"parent", J.Str{parent}}, J.KV{"child", J.Str{child}}, J.KV{"depth", Codec.nat(depth)}, J.KV{"provider", J.Str{provider}}, J.KV{"model", J.Str{model}}, J.KV{"at", Codec.nat(at)}])
    case M.TaskStateSet{task, state, summary, at}:
      Change.obj("TaskStateSet", [J.KV{"task", J.Str{task}}, J.KV{"state", J.Str{TaskSt.name(state)}}, J.KV{"summary", J.Str{summary}}, J.KV{"at", Codec.nat(at)}])
    case M.TaskDelivered{task, at}:
      Change.obj("TaskDelivered", [J.KV{"task", J.Str{task}}, J.KV{"at", Codec.nat(at)}])
    case M.SettingSet{key, value, at}:
      Change.obj("SettingSet", [J.KV{"key", J.Str{key}}, J.KV{"value", J.Str{value}}, J.KV{"at", Codec.nat(at)}])
    case M.TurnQueued{thread, msg, text, at}:
      Change.obj("TurnQueued", [J.KV{"thread", J.Str{thread}}, J.KV{"msg", J.Str{msg}}, J.KV{"text", J.Str{text}}, J.KV{"at", Codec.nat(at)}])
    case M.QueueTaken{thread, at}:
      Change.obj("QueueTaken", [J.KV{"thread", J.Str{thread}}, J.KV{"at", Codec.nat(at)}])
    case M.AskOpened{id, thread, kind, tool, detail, options, at}:
      Change.obj("AskOpened", [J.KV{"id", J.Str{id}}, J.KV{"thread", J.Str{thread}}, J.KV{"kind", J.Str{kind}}, J.KV{"tool", J.Str{tool}}, J.KV{"detail", J.Str{detail}}, J.KV{"options", J.Str{options}}, J.KV{"at", Codec.nat(at)}])
    case M.AskClosed{id, answer, at}:
      Change.obj("AskClosed", [J.KV{"id", J.Str{id}}, J.KV{"answer", J.Str{answer}}, J.KV{"at", Codec.nat(at)}])
    case M.DeviceRegistered{token, platform, kind, thread, env, bundle, at}:
      Change.obj("DeviceRegistered", [J.KV{"token", J.Str{token}}, J.KV{"platform", J.Str{platform}}, J.KV{"kind", J.Str{kind}}, J.KV{"thread", J.Str{thread}}, J.KV{"env", J.Str{env}}, J.KV{"bundle", J.Str{bundle}}, J.KV{"at", Codec.nat(at)}])
    case M.DeviceDropped{token, at}:
      Change.obj("DeviceDropped", [J.KV{"token", J.Str{token}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadSnoozed{id, until, at}:
      Change.obj("ThreadSnoozed", [J.KV{"id", J.Str{id}}, J.KV{"until", Codec.nat(until)}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadOrdered{id, section, key, at}:
      Change.obj("ThreadOrdered", [J.KV{"id", J.Str{id}}, J.KV{"section", J.Str{section}}, J.KV{"key", J.Str{key}}, J.KV{"at", Codec.nat(at)}])
    case M.WorktreeSkipped{id, at}:
      Change.obj("WorktreeSkipped", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadMerged{id, url, at}:
      Change.obj("ThreadMerged", [J.KV{"id", J.Str{id}}, J.KV{"url", J.Str{url}}, J.KV{"at", Codec.nat(at)}])
    case M.WorktreeRemoved{id, at}:
      Change.obj("WorktreeRemoved", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.ProjectOrdered{id, key, at}:
      Change.obj("ProjectOrdered", [J.KV{"id", J.Str{id}}, J.KV{"key", J.Str{key}}, J.KV{"at", Codec.nat(at)}])
    case M.QueueEdited{thread, msg, text, at}:
      Change.obj("QueueEdited", [J.KV{"thread", J.Str{thread}}, J.KV{"msg", J.Str{msg}}, J.KV{"text", J.Str{text}}, J.KV{"at", Codec.nat(at)}])
    case M.QueueRemoved{thread, msg, at}:
      Change.obj("QueueRemoved", [J.KV{"thread", J.Str{thread}}, J.KV{"msg", J.Str{msg}}, J.KV{"at", Codec.nat(at)}])
    case M.QueueMoved{thread, msg, to, at}:
      Change.obj("QueueMoved", [J.KV{"thread", J.Str{thread}}, J.KV{"msg", J.Str{msg}}, J.KV{"to", Codec.nat(to)}, J.KV{"at", Codec.nat(at)}])
    case M.QueueTakenOne{thread, msg, at}:
      Change.obj("QueueTakenOne", [J.KV{"thread", J.Str{thread}}, J.KV{"msg", J.Str{msg}}, J.KV{"at", Codec.nat(at)}])
    case M.ThreadForked{id, source, at}:
      Change.obj("ThreadForked", [J.KV{"id", J.Str{id}}, J.KV{"source", J.Str{source}}, J.KV{"at", Codec.nat(at)}])
    case M.ProviderSet{id, provider, model, at}:
      Change.obj("ProviderSet", [J.KV{"id", J.Str{id}}, J.KV{"provider", J.Str{provider}}, J.KV{"model", J.Str{model}}, J.KV{"at", Codec.nat(at)}])
    case M.TodosSet{thread, todos, at}:
      Change.obj("TodosSet", [J.KV{"thread", J.Str{thread}}, J.KV{"todos", J.Str{todos}}, J.KV{"at", Codec.nat(at)}])
    case M.UsageSet{thread, used, window, at}:
      Change.obj("UsageSet", [J.KV{"thread", J.Str{thread}}, J.KV{"used", Codec.nat(used)}, J.KV{"window", Codec.nat(window)}, J.KV{"at", Codec.nat(at)}])
    case M.BotSet{id, name, thread, look, persona, at}:
      Change.obj("BotSet", [J.KV{"id", J.Str{id}}, J.KV{"name", J.Str{name}}, J.KV{"thread", J.Str{thread}}, J.KV{"look", Codec.nat(look)}, J.KV{"persona", J.Str{persona}}, J.KV{"at", Codec.nat(at)}])
    case M.BotDeleted{id, at}:
      Change.obj("BotDeleted", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.RoomSet{id, name, members, at}:
      Change.obj("RoomSet", [J.KV{"id", J.Str{id}}, J.KV{"name", J.Str{name}}, J.KV{"members", J.Str{members}}, J.KV{"at", Codec.nat(at)}])
    case M.RoomDeleted{id, at}:
      Change.obj("RoomDeleted", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.RoomPosted{id, room, from, text, hop, at}:
      Change.obj("RoomPosted", [J.KV{"id", J.Str{id}}, J.KV{"room", J.Str{room}}, J.KV{"from", J.Str{from}}, J.KV{"text", J.Str{text}}, J.KV{"hop", Codec.nat(hop)}, J.KV{"at", Codec.nat(at)}])
    case M.HookSet{id, bot, name, revoked, at}:
      Change.obj("HookSet", [J.KV{"id", J.Str{id}}, J.KV{"bot", J.Str{bot}}, J.KV{"name", J.Str{name}}, J.KV{"revoked", J.Flag{revoked}}, J.KV{"at", Codec.nat(at)}])
    case M.HookHit{id, at}:
      Change.obj("HookHit", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.RoutineSet{id, bot, name, cron, prompt, on, at}:
      Change.obj("RoutineSet", [J.KV{"id", J.Str{id}}, J.KV{"bot", J.Str{bot}}, J.KV{"name", J.Str{name}}, J.KV{"cron", J.Str{cron}}, J.KV{"prompt", J.Str{prompt}}, J.KV{"on", J.Flag{on}}, J.KV{"at", Codec.nat(at)}])
    case M.RoutineDeleted{id, at}:
      Change.obj("RoutineDeleted", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.RoutineFired{id, at}:
      Change.obj("RoutineFired", [J.KV{"id", J.Str{id}}, J.KV{"at", Codec.nat(at)}])
    case M.MemorySaved{bot, key, kind, text, tags, at}:
      Change.obj("MemorySaved", [J.KV{"bot", J.Str{bot}}, J.KV{"key", J.Str{key}}, J.KV{"kind", J.Str{kind}}, J.KV{"text", J.Str{text}}, J.KV{"tags", J.Str{tags}}, J.KV{"at", Codec.nat(at)}])
    case M.MemoryForgot{bot, key, at}:
      Change.obj("MemoryForgot", [J.KV{"bot", J.Str{bot}}, J.KV{"key", J.Str{key}}, J.KV{"at", Codec.nat(at)}])
    case M.SpaceSet{bot, spec, at}:
      Change.obj("SpaceSet", [J.KV{"bot", J.Str{bot}}, J.KV{"spec", J.Str{spec}}, J.KV{"at", Codec.nat(at)}])
    case M.PeerSet{id, name, url, revoked, at}:
      Change.obj("PeerSet", [J.KV{"id", J.Str{id}}, J.KV{"name", J.Str{name}}, J.KV{"url", J.Str{url}}, J.KV{"revoked", J.Flag{revoked}}, J.KV{"at", Codec.nat(at)}])
    case M.BotWoke{bot, hop, at}:
      Change.obj("BotWoke", [J.KV{"bot", J.Str{bot}}, J.KV{"hop", Codec.nat(hop)}, J.KV{"at", Codec.nat(at)}])
    case M.SpacePageSet{bot, html, at}:
      Change.obj("SpacePageSet", [J.KV{"bot", J.Str{bot}}, J.KV{"html", J.Str{html}}, J.KV{"at", Codec.nat(at)}])

def Change.decode.k(tag: String, +o: J.Json) -> Maybe<&2, M.Change>:
  match tag:
    case "ProjectCreated":
      Some{M.ProjectCreated{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "title", ""), J.Json.get_str(o, "root", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ProjectRemoved":
      Some{M.ProjectRemoved{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadCreated":
      Some{M.ThreadCreated{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "project", ""), J.Json.get_str(o, "title", ""), Env.of(J.Json.get_str(o, "env", "")), J.Json.get_str(o, "branch", ""), J.Json.get_str(o, "worktree", ""), J.Json.get_str(o, "provider", ""), J.Json.get_str(o, "model", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadRenamed":
      Some{M.ThreadRenamed{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "title", ""), J.Json.get_nat(o, "at", 0n)}}
    case "MessagePosted":
      Some{M.MessagePosted{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "msg", ""), Role.of(J.Json.get_str(o, "role", "")), J.Json.get_str(o, "text", ""), J.Json.get_nat(o, "at", 0n)}}
    case "TurnChanged":
      Some{M.TurnChanged{J.Json.get_str(o, "thread", ""), Turn.of(J.Json.get_str(o, "state", "")), J.Json.get_nat(o, "at", 0n)}}
    case "PendingChanged":
      Some{M.PendingChanged{J.Json.get_str(o, "thread", ""), J.Json.get_nat(o, "count", 0n), J.Json.get_nat(o, "at", 0n)}}
    case "ActivityLogged":
      Some{M.ActivityLogged{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "act", ""), J.Json.get_str(o, "tone", ""), J.Json.get_str(o, "kind", ""), J.Json.get_str(o, "summary", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadSettled":
      Some{M.ThreadSettled{J.Json.get_str(o, "id", ""), J.Json.get_bool(o, "manual", False{}), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadUnsettled":
      Some{M.ThreadUnsettled{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadArchived":
      Some{M.ThreadArchived{J.Json.get_str(o, "id", ""), J.Json.get_bool(o, "archived", False{}), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadPinned":
      Some{M.ThreadPinned{J.Json.get_str(o, "id", ""), J.Json.get_bool(o, "pinned", False{}), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadDeleted":
      Some{M.ThreadDeleted{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "WorktreeSet":
      Some{M.WorktreeSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "branch", ""), J.Json.get_str(o, "worktree", ""), J.Json.get_nat(o, "at", 0n)}}
    case "SessionSet":
      Some{M.SessionSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "session", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ModesSet":
      Some{M.ModesSet{J.Json.get_str(o, "id", ""), Runtime.of(J.Json.get_str(o, "runtime", "")), Interaction.of(J.Json.get_str(o, "interaction", "")), J.Json.get_str(o, "model", ""), J.Json.get_nat(o, "at", 0n)}}
    case "TaskDelegated":
      Some{M.TaskDelegated{J.Json.get_str(o, "task", ""), J.Json.get_str(o, "parent", ""), J.Json.get_str(o, "child", ""), J.Json.get_nat(o, "depth", 0n), J.Json.get_str(o, "provider", ""), J.Json.get_str(o, "model", ""), J.Json.get_nat(o, "at", 0n)}}
    case "TaskStateSet":
      Some{M.TaskStateSet{J.Json.get_str(o, "task", ""), TaskSt.of(J.Json.get_str(o, "state", "")), J.Json.get_str(o, "summary", ""), J.Json.get_nat(o, "at", 0n)}}
    case "TaskDelivered":
      Some{M.TaskDelivered{J.Json.get_str(o, "task", ""), J.Json.get_nat(o, "at", 0n)}}
    case "SettingSet":
      Some{M.SettingSet{J.Json.get_str(o, "key", ""), J.Json.get_str(o, "value", ""), J.Json.get_nat(o, "at", 0n)}}
    case "TurnQueued":
      Some{M.TurnQueued{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "msg", ""), J.Json.get_str(o, "text", ""), J.Json.get_nat(o, "at", 0n)}}
    case "QueueTaken":
      Some{M.QueueTaken{J.Json.get_str(o, "thread", ""), J.Json.get_nat(o, "at", 0n)}}
    case "AskOpened":
      Some{M.AskOpened{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "kind", ""), J.Json.get_str(o, "tool", ""), J.Json.get_str(o, "detail", ""), J.Json.get_str(o, "options", ""), J.Json.get_nat(o, "at", 0n)}}
    case "AskClosed":
      Some{M.AskClosed{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "answer", ""), J.Json.get_nat(o, "at", 0n)}}
    case "DeviceRegistered":
      Some{M.DeviceRegistered{J.Json.get_str(o, "token", ""), J.Json.get_str(o, "platform", ""), J.Json.get_str(o, "kind", ""), J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "env", ""), J.Json.get_str(o, "bundle", ""), J.Json.get_nat(o, "at", 0n)}}
    case "DeviceDropped":
      Some{M.DeviceDropped{J.Json.get_str(o, "token", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadSnoozed":
      Some{M.ThreadSnoozed{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "until", 0n), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadOrdered":
      Some{M.ThreadOrdered{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "section", ""), J.Json.get_str(o, "key", ""), J.Json.get_nat(o, "at", 0n)}}
    case "WorktreeSkipped":
      Some{M.WorktreeSkipped{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadMerged":
      Some{M.ThreadMerged{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "url", ""), J.Json.get_nat(o, "at", 0n)}}
    case "WorktreeRemoved":
      Some{M.WorktreeRemoved{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ProjectOrdered":
      Some{M.ProjectOrdered{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "key", ""), J.Json.get_nat(o, "at", 0n)}}
    case "QueueEdited":
      Some{M.QueueEdited{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "msg", ""), J.Json.get_str(o, "text", ""), J.Json.get_nat(o, "at", 0n)}}
    case "QueueRemoved":
      Some{M.QueueRemoved{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "msg", ""), J.Json.get_nat(o, "at", 0n)}}
    case "QueueMoved":
      Some{M.QueueMoved{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "msg", ""), J.Json.get_nat(o, "to", 0n), J.Json.get_nat(o, "at", 0n)}}
    case "QueueTakenOne":
      Some{M.QueueTakenOne{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "msg", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ThreadForked":
      Some{M.ThreadForked{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "source", ""), J.Json.get_nat(o, "at", 0n)}}
    case "ProviderSet":
      Some{M.ProviderSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "provider", ""), J.Json.get_str(o, "model", ""), J.Json.get_nat(o, "at", 0n)}}
    case "TodosSet":
      Some{M.TodosSet{J.Json.get_str(o, "thread", ""), J.Json.get_str(o, "todos", ""), J.Json.get_nat(o, "at", 0n)}}
    case "UsageSet":
      Some{M.UsageSet{J.Json.get_str(o, "thread", ""), J.Json.get_nat(o, "used", 0n), J.Json.get_nat(o, "window", 0n), J.Json.get_nat(o, "at", 0n)}}
    case "BotSet":
      Some{M.BotSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "name", ""), J.Json.get_str(o, "thread", ""), J.Json.get_nat(o, "look", 0n), J.Json.get_str(o, "persona", ""), J.Json.get_nat(o, "at", 0n)}}
    case "BotDeleted":
      Some{M.BotDeleted{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "RoomSet":
      Some{M.RoomSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "name", ""), J.Json.get_str(o, "members", ""), J.Json.get_nat(o, "at", 0n)}}
    case "RoomDeleted":
      Some{M.RoomDeleted{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "RoomPosted":
      Some{M.RoomPosted{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "room", ""), J.Json.get_str(o, "from", ""), J.Json.get_str(o, "text", ""), J.Json.get_nat(o, "hop", 0n), J.Json.get_nat(o, "at", 0n)}}
    case "HookSet":
      Some{M.HookSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "bot", ""), J.Json.get_str(o, "name", ""), J.Json.get_bool(o, "revoked", False{}), J.Json.get_nat(o, "at", 0n)}}
    case "HookHit":
      Some{M.HookHit{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "RoutineSet":
      Some{M.RoutineSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "bot", ""), J.Json.get_str(o, "name", ""), J.Json.get_str(o, "cron", ""), J.Json.get_str(o, "prompt", ""), J.Json.get_bool(o, "on", False{}), J.Json.get_nat(o, "at", 0n)}}
    case "RoutineDeleted":
      Some{M.RoutineDeleted{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "RoutineFired":
      Some{M.RoutineFired{J.Json.get_str(o, "id", ""), J.Json.get_nat(o, "at", 0n)}}
    case "MemorySaved":
      Some{M.MemorySaved{J.Json.get_str(o, "bot", ""), J.Json.get_str(o, "key", ""), J.Json.get_str(o, "kind", ""), J.Json.get_str(o, "text", ""), J.Json.get_str(o, "tags", ""), J.Json.get_nat(o, "at", 0n)}}
    case "MemoryForgot":
      Some{M.MemoryForgot{J.Json.get_str(o, "bot", ""), J.Json.get_str(o, "key", ""), J.Json.get_nat(o, "at", 0n)}}
    case "SpaceSet":
      Some{M.SpaceSet{J.Json.get_str(o, "bot", ""), J.Json.get_str(o, "spec", ""), J.Json.get_nat(o, "at", 0n)}}
    case "PeerSet":
      Some{M.PeerSet{J.Json.get_str(o, "id", ""), J.Json.get_str(o, "name", ""), J.Json.get_str(o, "url", ""), J.Json.get_bool(o, "revoked", False{}), J.Json.get_nat(o, "at", 0n)}}
    case "BotWoke":
      Some{M.BotWoke{J.Json.get_str(o, "bot", ""), J.Json.get_nat(o, "hop", 0n), J.Json.get_nat(o, "at", 0n)}}
    case "SpacePageSet":
      Some{M.SpacePageSet{J.Json.get_str(o, "bot", ""), J.Json.get_str(o, "html", ""), J.Json.get_nat(o, "at", 0n)}}
    case _:
      None{}

# a Change from its JSON, or None for an unknown tag
def Change.decode(+o: J.Json) -> Maybe<&2, M.Change>:
  Change.decode.k(J.Json.get_str(o, "$", ""), o)

# What clients see
# ----------------
# The log on disk keeps every field; the copy sent to clients (the "log" and
# "changes" messages) carries device events with only their tag and time.
# A push token is a secret, and clients fold an empty token as no device,
# so their sequence numbers still match the server's (law
# device_token_never_sent).

def Change.wire(c: M.Change) -> J.Json:
  match c:
    case M.DeviceRegistered{_, _, _, _, _, _, at}:
      Change.obj("DeviceRegistered", [J.KV{"at", Codec.nat(at)}])
    case M.DeviceDropped{_, at}:
      Change.obj("DeviceDropped", [J.KV{"at", Codec.nat(at)}])
    case M.ProjectCreated{id, title, root, at}:
      Change.encode(M.ProjectCreated{id, title, root, at})
    case M.ProjectRemoved{id, at}:
      Change.encode(M.ProjectRemoved{id, at})
    case M.ThreadCreated{id, project, title, env, branch, worktree, provider, model, at}:
      Change.encode(M.ThreadCreated{id, project, title, env, branch, worktree, provider, model, at})
    case M.ThreadRenamed{id, title, at}:
      Change.encode(M.ThreadRenamed{id, title, at})
    case M.MessagePosted{thread, msg, role, text, at}:
      Change.encode(M.MessagePosted{thread, msg, role, text, at})
    case M.TurnChanged{thread, state, at}:
      Change.encode(M.TurnChanged{thread, state, at})
    case M.PendingChanged{thread, count, at}:
      Change.encode(M.PendingChanged{thread, count, at})
    case M.ActivityLogged{thread, act, tone, kind, summary, at}:
      Change.encode(M.ActivityLogged{thread, act, tone, kind, summary, at})
    case M.ThreadSettled{id, manual, at}:
      Change.encode(M.ThreadSettled{id, manual, at})
    case M.ThreadUnsettled{id, at}:
      Change.encode(M.ThreadUnsettled{id, at})
    case M.ThreadArchived{id, archived, at}:
      Change.encode(M.ThreadArchived{id, archived, at})
    case M.ThreadPinned{id, pinned, at}:
      Change.encode(M.ThreadPinned{id, pinned, at})
    case M.ThreadDeleted{id, at}:
      Change.encode(M.ThreadDeleted{id, at})
    case M.WorktreeSet{id, branch, worktree, at}:
      Change.encode(M.WorktreeSet{id, branch, worktree, at})
    case M.SessionSet{id, session, at}:
      Change.encode(M.SessionSet{id, session, at})
    case M.ModesSet{id, runtime, interaction, model, at}:
      Change.encode(M.ModesSet{id, runtime, interaction, model, at})
    case M.TaskDelegated{task, parent, child, depth, provider, model, at}:
      Change.encode(M.TaskDelegated{task, parent, child, depth, provider, model, at})
    case M.TaskStateSet{task, state, summary, at}:
      Change.encode(M.TaskStateSet{task, state, summary, at})
    case M.TaskDelivered{task, at}:
      Change.encode(M.TaskDelivered{task, at})
    case M.SettingSet{key, value, at}:
      Change.encode(M.SettingSet{key, value, at})
    case M.TurnQueued{thread, msg, text, at}:
      Change.encode(M.TurnQueued{thread, msg, text, at})
    case M.QueueTaken{thread, at}:
      Change.encode(M.QueueTaken{thread, at})
    case M.AskOpened{id, thread, kind, tool, detail, options, at}:
      Change.encode(M.AskOpened{id, thread, kind, tool, detail, options, at})
    case M.AskClosed{id, answer, at}:
      Change.encode(M.AskClosed{id, answer, at})
    case M.ThreadSnoozed{id, until, at}:
      Change.encode(M.ThreadSnoozed{id, until, at})
    case M.ThreadOrdered{id, section, key, at}:
      Change.encode(M.ThreadOrdered{id, section, key, at})
    case M.WorktreeSkipped{id, at}:
      Change.encode(M.WorktreeSkipped{id, at})
    case M.ThreadMerged{id, url, at}:
      Change.encode(M.ThreadMerged{id, url, at})
    case M.WorktreeRemoved{id, at}:
      Change.encode(M.WorktreeRemoved{id, at})
    case M.ProjectOrdered{id, key, at}:
      Change.encode(M.ProjectOrdered{id, key, at})
    case M.QueueEdited{thread, msg, text, at}:
      Change.encode(M.QueueEdited{thread, msg, text, at})
    case M.QueueRemoved{thread, msg, at}:
      Change.encode(M.QueueRemoved{thread, msg, at})
    case M.QueueMoved{thread, msg, to, at}:
      Change.encode(M.QueueMoved{thread, msg, to, at})
    case M.QueueTakenOne{thread, msg, at}:
      Change.encode(M.QueueTakenOne{thread, msg, at})
    case M.ThreadForked{id, source, at}:
      Change.encode(M.ThreadForked{id, source, at})
    case M.ProviderSet{id, provider, model, at}:
      Change.encode(M.ProviderSet{id, provider, model, at})
    case M.TodosSet{thread, todos, at}:
      Change.encode(M.TodosSet{thread, todos, at})
    case M.UsageSet{thread, used, window, at}:
      Change.encode(M.UsageSet{thread, used, window, at})
    case M.BotSet{id, name, thread, look, persona, at}:
      Change.encode(M.BotSet{id, name, thread, look, persona, at})
    case M.BotDeleted{id, at}:
      Change.encode(M.BotDeleted{id, at})
    case M.RoomSet{id, name, members, at}:
      Change.encode(M.RoomSet{id, name, members, at})
    case M.RoomDeleted{id, at}:
      Change.encode(M.RoomDeleted{id, at})
    case M.RoomPosted{id, room, from, text, hop, at}:
      Change.encode(M.RoomPosted{id, room, from, text, hop, at})
    case M.HookSet{id, bot, name, revoked, at}:
      Change.encode(M.HookSet{id, bot, name, revoked, at})
    case M.HookHit{id, at}:
      Change.encode(M.HookHit{id, at})
    case M.RoutineSet{id, bot, name, cron, prompt, on, at}:
      Change.encode(M.RoutineSet{id, bot, name, cron, prompt, on, at})
    case M.RoutineDeleted{id, at}:
      Change.encode(M.RoutineDeleted{id, at})
    case M.RoutineFired{id, at}:
      Change.encode(M.RoutineFired{id, at})
    case M.MemorySaved{bot, key, kind, text, tags, at}:
      Change.encode(M.MemorySaved{bot, key, kind, text, tags, at})
    case M.MemoryForgot{bot, key, at}:
      Change.encode(M.MemoryForgot{bot, key, at})
    case M.SpaceSet{bot, spec, at}:
      Change.encode(M.SpaceSet{bot, spec, at})
    case M.PeerSet{id, name, url, revoked, at}:
      Change.encode(M.PeerSet{id, name, url, revoked, at})
    case M.BotWoke{bot, hop, at}:
      Change.encode(M.BotWoke{bot, hop, at})
    case M.SpacePageSet{bot, html, at}:
      Change.encode(M.SpacePageSet{bot, html, at})

def Change.private(+tag: String) -> Bool:
  Bool.or(String.eq(tag, "DeviceRegistered"), String.eq(tag, "DeviceDropped"))

def Change.wire_line.k(private: Bool, +o: J.Json, l: String) -> String:
  match private:
    case True{}:
      J.Json.show(Change.obj(J.Json.get_str(o, "$", ""), [J.KV{"at", Codec.nat(J.Json.get_nat(o, "at", 0n))}]))
    case False{}:
      l

# a stored line (parsed as o) as clients may see it
def Change.wire_line(+o: J.Json, l: String) -> String:
  Change.wire_line.k(Change.private(J.Json.get_str(o, "$", "")), o, l)
