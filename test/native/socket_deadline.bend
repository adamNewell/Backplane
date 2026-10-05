import Base

# The JS integration test uses the compiler's real IO scheduler.
def main() -> IO(Unit):
  IO.sleep(1)
