import Base
import ../../src/core/cbor.bend as C
import ../../src/core/json.bend as J

def keys() -> List<&2, String>:
  C.Cbor.keys()

def words() -> List<&2, String>:
  C.Cbor.words()

def encode(text: String) -> List<&2, U32>:
  C.Cbor.encode(Maybe.default(&2, J.Json, J.Json.parse(text), J.Null{}))

def decode(bs: List<&2, U32>) -> J.Json:
  Maybe.default(&2, J.Json, C.Cbor.decode(bs), J.Null{})

def show(j: J.Json) -> String:
  J.Json.show(j)


def rules() -> List<&2, List<&2, C.Rule>>:
  C.Cbor.rules()


def key_text(raw: String) -> Maybe<&2, String>:
  C.Cbor.key_text(raw, C.Cbor.keys())
