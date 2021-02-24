from copy import deepcopy
from functools import total_ordering
from typing import List, Set

from color import Color
from move import Move
from vial import Vial


@total_ordering
class Puzzle:

    def __init__(self, name: str, vials: List[Vial]):
        self.name = name
        self.vials: List[Vial] = vials
        self.moves: List[Move] = []

        self.vial_count = 0
        self.weight = 0
        for vial in self.vials:
            self.vial_count += 1
            self.weight += vial.get_weight()

        self.validate()


    def __hash__(self) -> int:
        return Vial.hash_vials(self.vials)


    def __eq__(self, other) -> bool:
        return hash(self) == hash(other)


    def __lt__(self, other):
        return self.get_weight() < other.get_weight()


    @staticmethod
    def serialize(puzzle: 'Puzzle') -> List[str]:
        vials = [Vial.serialize(vial) for vial in puzzle.vials]
        return { 'name': puzzle.name, 'vials': vials }


    @staticmethod
    def deserialize(puzzle_json) -> 'Puzzle':
        name = puzzle_json['name']
        vials = [Vial.deserialize(vial) for vial in puzzle_json['vials']]
        return Puzzle(name, vials)


    def validate(self):
        counts = {}

        for vial in self.vials:
            colors = vial.get_colors()

            for color in colors:
                counts[color] = counts.get(color, 0) + 1

        wrong_color_counts = dict(filter(lambda item: item[1] != Vial.MAX_NUM_COLORS, counts.items()))
        if wrong_color_counts:
            self.pretty_print()
            print()
            raise Exception(f"Invalid puzzle, vials don't contain {Vial.MAX_NUM_COLORS} of each color: {wrong_color_counts}")


    def get_vial_count(self) -> int:
        return self.vial_count


    def get_vial(self, index: int) -> Vial:
        return self.vials[index]


    def get_moves(self) -> [Move]:
        return self.moves


    def get_weight(self) -> int:
        # Optimal solution
        #return self.weight - self.num_moves()

        # Fastest
        return self.weight


    def possible_moves(self) -> List[Move]:
        possible_moves: List[Move] = []
        unique_moves: Set[int] = set()

        for from_index, from_vial in enumerate(self.vials):
            if from_vial.is_complete() or from_vial.is_empty():
                continue

            for to_index, to_vial in enumerate(self.vials):
                if to_vial.is_complete() or from_index == to_index or to_vial.is_full():
                    continue

                if to_vial.is_empty() or from_vial.peek() == to_vial.peek():
                    copy_from_vial = deepcopy(from_vial)
                    copy_to_vial = deepcopy(to_vial)

                    color: Color = copy_from_vial.pop()
                    copy_to_vial.push(color)

                    vials_hash: int = Vial.hash_vials([copy_from_vial, copy_to_vial])

                    if not vials_hash in unique_moves:
                        unique_moves.add(vials_hash)

                        move = Move(from_index, to_index)
                        possible_moves.append(move)

        return possible_moves


    def is_complete(self) -> bool:
        return all(vial.is_complete() or vial.is_empty() for vial in self.vials)


    def can_move(self, move: Move) -> bool:
        vial_from: Vial = self.vials[move.get_from_index()]
        if vial_from.is_empty():
            return False

        vial_to: Vial = self.vials[move.get_to_index()]
        if vial_to.is_full():
            return False

        if not vial_from.is_empty() and not vial_to.is_empty() and vial_from.peek() != vial_to.peek():
            return False

        return True


    def move(self, move: Move) -> None:
        vial_from: Vial = self.vials[move.get_from_index()]
        if vial_from.is_empty():
            raise Exception('Move failed, vial {} is empty'.format(move.get_from_index()))

        vial_to: Vial = self.vials[move.get_to_index()]
        if vial_to.is_full():
            raise Exception('Move failed, vial {} is full'.format(move.get_to_index()))

        if not vial_from.is_empty() and not vial_to.is_empty() and vial_from.peek() != vial_to.peek():
            raise Exception(f"Move failed, vial {move.get_from_index()} and vial {move.get_to_index()} don't have the same colors on top")

        vials = [vial_from, vial_to]

        for vial in vials:
            self.weight -= vial.get_weight()

        color: Color = vial_from.pop()
        vial_to.push(color)

        for vial in vials:
            self.weight += vial.get_weight()

        if not vial_from.is_empty() and not vial_to.is_full() and vial_from.peek() == vial_to.peek():
            self.move(move)
        else:
            self.moves.append(move)


    def num_moves(self) -> int:
        return len(self.moves)


    def print(self) -> None:
        for vial in self.vials:
            vial.print()


    def pretty_print(self, print_name: bool = False) -> None:
        index_nums = [i for i in range(-2, 4)]
        index_nums.reverse()

        def print_vials(vials: [Vial], use_margin: bool = False) -> None:
            margin = " " * 5 if use_margin else ""
            for index in index_nums:
                color_rows = [ color_row for color_row in map(lambda vial: vial.pretty_string_row(index), vials)]
                print(margin + '   '.join(color_rows))

            print("\n")

        print_two_rows = self.get_vial_count() > 5

        middle_index = self.get_vial_count() // 2 + self.get_vial_count() % 2 if print_two_rows else self.get_vial_count()

        first_half = self.vials[:middle_index]
        second_half = self.vials[middle_index:]
        first_margin = len(second_half) > len(first_half)
        second_margin = len(first_half) > len(second_half)


        if print_name:
            print(f"Puzzle '{self.name}'\n")

        print_vials(first_half, first_margin)

        if print_two_rows:
            print_vials(second_half, second_margin)

    def print_moves(self, verbose: bool = False) -> None:
        print(f"{self.num_moves()} moves made:")

        if verbose:
            count = 0
            for move in self.get_moves():
                count += 1
                move.print()
                if count % 5 == 0:
                    print()
        print()


    def print_possible_moves(self) -> None:
        possible_moves: List[Move] = self.possible_moves()
        print(f"{len(possible_moves)} possible moves:")
        count = 0
        for move in possible_moves:
            count += 1
            move.print()
            if count % 5 == 0:
                print()


    def print_puzzle_code(self) -> None:
        print("Puzzle code")
        print("Puzzle([")
        for vial in self.vials:
            color_names = [ f"Color.{color_name}" for color_name in map(lambda color: color.name, vial.get_colors())]
            print(f"    Vial ({vial.get_name()}, [{', '.join(color_names)}]),")
        print("])")

