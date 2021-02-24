
class Move:

    def __init__(self, from_index: int, to_index: int):
        self.from_index = from_index
        self.to_index = to_index


    def get_from_index(self) -> int:
        return self.from_index


    def get_to_index(self) -> int:
        return self.to_index


    def __hash__(self) -> int:
        return hash((self.from_index, self.to_index))


    def __eq__(self, other) -> bool:
        return hash(self) == hash(other)


    def string(self) -> str:
        return "Move from {} to {}".format(self.from_index, self.to_index)


    def print(self) -> None:
        print(self.string())

