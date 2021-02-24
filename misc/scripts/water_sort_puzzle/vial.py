from typing import List, Optional

from color import Color


class Vial:

    MAX_NUM_COLORS: int = 4

    def __init__(self, name, colors):
        self.name: str = name
        self.colors: List[Color] = []
        self.size = 0
        self.complete_num = 0
        self.bottom_color = Color.NONE

        for color in colors:
            self.push(color)


    def __hash__(self) -> int:
        return hash(tuple(self.colors))


    def __eq__(self, other) -> bool:
        return hash(self) == hash(other)


    @staticmethod
    def serialize(vial: 'Vial') -> dict:
        colors = [Color.serialize(color) for color in vial.colors]
        return { 'name': vial.name, 'colors': colors }


    @staticmethod
    def deserialize(vial_json) -> 'Vial':
        name = vial_json['name']
        colors = [Color.deserialize(color_name) for color_name in vial_json['colors']]
        return Vial(name, colors)


    @staticmethod
    def hash_vials(vials: ['Vial']) -> int:
        vial_hashes = [ vial_hash for vial_hash in map(lambda vial: hash(vial), vials)]
        vial_hashes.sort()
        return hash(tuple(vial_hashes))


    def get_name(self) -> str:
        return self.name


    def get_colors(self) -> List[Color]:
        return self.colors;


    def get_size(self) -> int:
        return self.size


    def get_color(self, index: int) -> Optional[Color]:
        if index >= self.get_size() or index < 0:
            return None

        return self.colors[index]


    def get_weight(self) -> int:
        return self.complete_num


    def is_empty(self) -> bool:
        return self.get_size() == 0


    def is_full(self) -> bool:
        return self.get_size() == self.MAX_NUM_COLORS


    def is_complete(self) -> bool:
        return self.complete_num == self.MAX_NUM_COLORS


    def push(self, color: Color) -> None:
        if self.is_full():
            raise Exception("Pushing onto full vial")

        if self.size == 0:
            self.bottom_color = color
            self.complete_num += 1
        elif self.size == self.complete_num and color == self.bottom_color:
            self.complete_num += 1

        self.size += 1

        self.colors.append(color)


    def pop(self) -> Color:
        if self.is_empty():
            raise Exception("Popping from empty vial")

        color = self.colors.pop()

        if self.size == self.complete_num and color == self.bottom_color:
            self.complete_num -= 1

        if self.complete_num == 0:
            self.bottom_color = Color.NONE

        self.size -= 1

        return color


    def peek(self) -> Color:
        if self.is_empty():
            raise Exception("Peeking from empty vial")
        return self.colors[self.get_size() - 1]


    def print(self) -> None:
        print(f"Vial {self.name}: {self.colors}")


    def pretty_string_row(self, index: int) -> str:
        if index == -2:
            return "{:^12s}".format(f"Vial {self.get_name()}")

        if index == -1:
            return "-" * 12

        color = self.get_color(index)

        if color:
            # the regular format style, i.e. "|{:^12s}|".format(blah), doesn't work w/ the colors
            # my guess is because of the Style.RESET_ALL
            buffer_len = 10 - len(color.name)

            first_buffer = buffer_len // 2
            second_buffer = buffer_len // 2 + buffer_len % 2

            return "|" + (" " * first_buffer) + color.pretty_string() + (" " * second_buffer) + "|"
        else:
            return "|" + (" " * 10) + "|"


    def pretty_print(self) -> None:
        index_nums = [i for i in range(-2, self.MAX_NUM_COLORS)]
        index_nums.reverse()
        for index in index_nums:
            print(self.pretty_string_row(index))


    def print_stats(self) -> None:
        self.pretty_print()
        print(f"self.size: {self.size}")
        print(f"self.bottom_color: {self.bottom_color}")
        print(f"self.complete_num: {self.complete_num}")
        print(f"self.get_size(): {self.get_size()}")
        print(f"self.is_full(): {self.is_full()}")
        print(f"self.is_empty(): {self.is_empty()}")
        print(f"self.is_complete(): {self.is_complete()}")
        print()

