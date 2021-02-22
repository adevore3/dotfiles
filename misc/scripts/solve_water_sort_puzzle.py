from enum import Enum, unique
from colorama import Back, Fore, Style
from collections import deque
from copy import deepcopy


@unique
class Color(Enum):
    NONE = Fore.BLACK
    RED = Fore.RED + Style.BRIGHT
    GREEN = Fore.GREEN
    BLUE = Fore.BLUE + Style.BRIGHT
    CYAN = Fore.CYAN + Style.BRIGHT
    PURPLE = Fore.MAGENTA + Style.DIM
    GRAY = Fore.WHITE + Style.DIM
    PINK = Fore.MAGENTA + Style.BRIGHT
    ORANGE = Fore.RED + Style.DIM
    NEON_GREEN = Fore.GREEN + Style.BRIGHT

    def pretty_string(self):
        return self.value + self.name + Style.RESET_ALL

    def pretty_print(self):
        print(self.pretty_string())


class Vial:

    MAX_NUM_COLORS = 4

    def __init__(self, name, colors):
        self.name = name
        self.stack = []
        for color in colors:
            self.push(color)

    def size(self):
        return len(self.stack)

    def is_empty(self):
        return self.size() == 0

    def is_full(self):
        return self.size() >= self.MAX_NUM_COLORS

    def is_complete(self):
        if not self.is_empty():
            bottom_color = self.stack[0]
            for color in self.stack:
                if bottom_color != color:
                    return False

        return self.is_full()

    def push(self, color: Color):
        if self.is_full():
            raise Exception("Pushing onto full vial")
        self.stack.append(color)

    def pop(self):
        if self.is_empty():
            raise Exception("Popping from empty vial")
        color = self.stack.pop()
        return color

    def peek(self):
        if self.is_empty():
            raise Exception("Peeking from empty vial")
        return self.stack[self.size() - 1]

    def get_name(self) -> str:
        return self.name

    def get_color(self, index: int) -> Color:
        if self.is_empty():
            return Color.NONE

        if index >= self.size() or index < 0:
            return Color.NONE

        return self.stack[index]

    def __hash__(self) -> int:
        return hash(tuple(self.stack))

    def __eq__(self, other) -> bool:
        return hash(self) == hash(other)

    def print(self):
        print("Vial {}: {}".format(self.name, self.stack))

    def pretty_string_row(self, index: int) -> str:
        if index == -2:
            return "{:^12s}".format(f"Vial {self.get_name()}")

        if index == -1:
            return "-" * 12

        color = Color.NONE
        if index < self.size() or index >= 0:
            color = self.get_color(index)

        # the regular format style, i.e. "|{:^8s}|".format(blah), doesn't work w/ the colors
        # my guess is because of the Style.RESET_ALL
        buffer_len = 10 - len(color.name)

        first_buffer = buffer_len // 2
        second_buffer = buffer_len // 2 + buffer_len % 2

        return "|" + (" " * first_buffer) + color.pretty_string() + (" " * second_buffer) + "|"

    def pretty_print(self):
        index_nums = [i for i in range(-2, self.MAX_NUM_COLORS)]
        index_nums.reverse()
        for index in index_nums:
            print(self.pretty_string_row(index))


class Move:

    def __init__(self, from_index: int, to_index: int):
        self.from_index = from_index
        self.to_index = to_index

    def get_from_index(self) -> int:
        return self.from_index

    def get_to_index(self) -> int:
        return self.to_index

    def string(self):
        return "Move from vial {} to vial {}".format(self.from_index, self.to_index)

    def print(self):
        print(self.string())


class Game:

    def __init__(self, vials):
        self.vials = vials
        self.moves = []
        self.validate()

    def validate(self):
        return None

    def size(self):
        return len(self.vials)

    def get_vial(self, index: int) -> Vial:
        return self.vials[index]

    def get_moves(self) -> [Move]:
        return self.moves

    def possible_moves(self) -> [Move]:
        possible_moves = []

        for from_index, from_vial in enumerate(self.vials):
            if from_vial.is_complete() or from_vial.is_empty():
                continue

            for to_index, to_vial in enumerate(self.vials):
                if to_vial.is_complete() or from_index == to_index or to_vial.is_full():
                    continue

                if to_vial.is_empty() or from_vial.peek() == to_vial.peek():
                    move = Move(from_index, to_index)
                    possible_moves.append(move)

        return possible_moves

    def is_complete(self):
        return all(vial.is_complete() or vial.is_empty() for vial in self.vials)

    def move(self, move: Move):
        vial_from = self.vials[move.get_from_index()]
        if vial_from.is_empty():
            raise Exception('Move failed, vial {} is empty'.format(move.get_from_index()))

        vial_to = self.vials[move.get_to_index()]
        if vial_to.is_full():
            raise Exception('Move failed, vial {} is full'.format(move.get_to_index()))

        if not vial_from.is_empty() and not vial_to.is_empty() and vial_from.peek() != vial_to.peek():
            raise Exception(f"Move failed, vial {move.get_from_index()} and vial {move.get_to_index()} don't have the same colors on top")

        color = vial_from.pop()
        vial_to.push(color)

        self.moves.append(move)

        if not vial_from.is_empty() and not vial_to.is_full() and vial_from.peek() == vial_to.peek():
            self.move(move)

    def num_moves(self) -> int:
        return len(self.moves)

    def __hash__(self) -> int:
        vial_hashes = [ vial_hash for vial_hash in map(lambda vial: hash(vial), self.vials)]
        vial_hashes.sort()
        return hash(tuple(vial_hashes))

    def __eq__(self, other) -> bool:
        return hash(self) == hash(other)

    def print(self):
        for vial in self.vials:
            vial.print()

    def pretty_print(self):
        index_nums = [i for i in range(-2, 4)]
        index_nums.reverse()

        def print_vials(vials: [Vial], use_margin: bool = False):
            margin = " " * 5 if use_margin else ""
            for index in index_nums:
                color_rows = [ color_row for color_row in map(lambda vial: vial.pretty_string_row(index), vials)]
                print(margin + '   '.join(color_rows))

            print("\n")

        middle_index = self.size() // 2 + self.size() % 2

        first_half = self.vials[:middle_index]
        second_half = self.vials[middle_index:]
        first_margin = len(second_half) > len(first_half)
        second_margin = len(first_half) > len(second_half)

        print_vials(first_half, first_margin)
        print_vials(second_half, second_margin)

    def print_moves(self) -> str:
        print(f"{self.num_moves()} moves made:")
        count = 0
        for move in self.get_moves():
            count += 1
            move.print()
            if count % 5 == 0:
                print()


class GameSolver:

    def __init__(self, game: Game):
        self.game = game
        self.queue = deque()
        self.checked_games = set()

    def enqueue(self, game: Game):
        self.queue.append(game)

    def dequeue(self) -> Game:
        return self.queue.popleft()

    def solve(self):
        print("Starting to solve...")
        self.game.pretty_print()

        num_moves_made_initially = len(self.game.get_moves())

        current_game = self.game
        should_continue = "y"
        num_games_created = 0
        loop_count = 0
        num_zero_possible_moves = 0

        while not current_game.is_complete() and should_continue == "y":
            loop_count += 1
            self.checked_games.add(current_game)

            possible_moves = current_game.possible_moves()

            #if len(possible_moves) == 0:
            #    num_zero_possible_moves += 1
            #    if num_zero_possible_moves % 10 == 0:
            #        print(f"============================ num_zero_possible_moves: {num_zero_possible_moves}")

            if loop_count % 10000 == 0:
                print("============================")
                #print("Current game:")
                #current_game.pretty_print()
                print(f"length of queue {len(self.queue)}")

                #print(f"num possible_moves: {len(possible_moves)}")
                #for move in possible_moves:
                #    move.print()
                #print(f"moves made: {current_game.num_moves()}")

                print(f"num of games created: {num_games_created}")
                print(f"num of unique games: {len(self.checked_games)}")

                print("============================\n\n")

            for move in possible_moves:
                copy_game = deepcopy(current_game)
                num_games_created += 1

                copy_game.move(move)

                if copy_game in self.checked_games:
                    continue

                self.enqueue(copy_game)

            current_game = self.dequeue()

            #if loop_count % 100 == 0:
            #    should_continue = input("Continue? ")

        print("Solved!")

        current_game.pretty_print()

        print(f"num of moves initially made: {num_moves_made_initially}")
        print(f"num of games created: {num_games_created}")
        print(f"num of unique games: {len(self.checked_games)}")

        current_game.print_moves()


print("\nStart of program\n")

vials = [
    Vial(0, [Color.RED, Color.RED, Color.RED, Color.RED]),
    Vial(1, [Color.BLUE, Color.BLUE, Color.BLUE, Color.BLUE]),
    Vial(2, [Color.PURPLE, Color.GREEN, Color.PURPLE]),
    Vial(3, [Color.GREEN, Color.PURPLE, Color.GREEN, Color.PURPLE]),
    Vial(4, [Color.CYAN, Color.CYAN, Color.CYAN, Color.CYAN]),
    Vial(5, [Color.GREEN]),
]
easy_vials = [
    Vial(0, [Color.RED, Color.RED, Color.RED, Color.RED]),
    Vial(1, [Color.BLUE, Color.BLUE, Color.BLUE, Color.BLUE]),
    Vial(2, [Color.PURPLE, Color.PURPLE, Color.PURPLE]),
    Vial(3, [Color.GREEN, Color.GREEN, Color.GREEN, Color.PURPLE]),
    Vial(4, [Color.CYAN, Color.CYAN, Color.CYAN, Color.CYAN]),
    Vial(5, [Color.GREEN]),
]
first_challenge = [
    Vial(0, [Color.BLUE, Color.PINK, Color.ORANGE, Color.NEON_GREEN]),
    Vial(1, [Color.PINK, Color.RED, Color.NEON_GREEN, Color.CYAN]),
    Vial(2, [Color.RED, Color.CYAN, Color.PINK, Color.CYAN]),
    Vial(3, [Color.ORANGE, Color.BLUE, Color.GRAY, Color.NEON_GREEN]),
    Vial(4, [Color.ORANGE, Color.GRAY, Color.ORANGE, Color.RED]),
    Vial(5, [Color.GRAY, Color.GRAY, Color.BLUE, Color.RED]),
    Vial(6, [Color.CYAN, Color.PINK, Color.NEON_GREEN, Color.BLUE]),
    Vial(7, []),
    Vial(8, []),
]
first_challenge_easier = [
    Vial(0, [Color.BLUE, Color.PINK, Color.ORANGE]),
    Vial(1, [Color.PINK, Color.RED]),
    Vial(2, [Color.RED, Color.CYAN, Color.PINK]),
    Vial(3, [Color.ORANGE, Color.BLUE, Color.GRAY]),
    Vial(4, [Color.ORANGE, Color.GRAY, Color.ORANGE, Color.RED]),
    Vial(5, [Color.GRAY, Color.GRAY, Color.BLUE, Color.RED]),
    Vial(6, [Color.CYAN, Color.PINK, Color.NEON_GREEN, Color.BLUE]),
    Vial(7, [Color.CYAN, Color.CYAN]),
    Vial(8, [Color.NEON_GREEN, Color.NEON_GREEN, Color.NEON_GREEN]),
]
game1 = Game(vials)

game_first_challenge = Game(first_challenge)
game_first_challenge_easier = Game(first_challenge_easier)
game_first_challenge_moves_made = Game(first_challenge)

game_first_challenge_moves_made.move(Move(1, 7))
game_first_challenge_moves_made.move(Move(2, 7))
game_first_challenge_moves_made.move(Move(0, 8))
game_first_challenge_moves_made.move(Move(1, 8))
game_first_challenge_moves_made.move(Move(3, 8))

game_first_challenge_moves_made.move(Move(4, 1))
game_first_challenge_moves_made.move(Move(4, 0))
#game_first_challenge_moves_made.move(Move(4, 3))
#game_first_challenge_moves_made.move(Move(0, 4))
#game_first_challenge_moves_made.move(Move(2, 0))

#game_first_challenge_moves_made.move(Move(2, 7))
#game_first_challenge_moves_made.move(Move(1, 2))
#game_first_challenge_moves_made.move(Move(0, 1))
#game_first_challenge_moves_made.move(Move(5, 2))
#game_first_challenge_moves_made.move(Move(5, 0))

#game_first_challenge_moves_made.move(Move(3, 5))
#game_first_challenge_moves_made.move(Move(3, 0))
#game_first_challenge_moves_made.move(Move(3, 4))
#game_first_challenge_moves_made.move(Move(6, 0))
#game_first_challenge_moves_made.move(Move(6, 8))

#game_first_challenge_moves_made.move(Move(6, 1))
#game_first_challenge_moves_made.move(Move(6, 7))

game_first_challenge_moves_made.pretty_print()
num_moves_made_initially = len(game_first_challenge_moves_made.get_moves())
print(f"num of moves initially made: {num_moves_made_initially}")

solver = GameSolver(game_first_challenge_moves_made)
solver.solve()

#print("Would you like to:")
#print("  1. Play")
#print("  2. Solve")
#choice = int(input("Choose an option: \n"))
#
#if choice == 1:
#    current_game = game1
#    current_game.pretty_print()
#
#    while not current_game.is_complete():
#        from_index = int(input("Enter a vial number to pour from: "))
#        to_index = int(input("Enter a vial number to pour into: "))
#
#        current_game.move(Move(from_index, to_index))
#
#        current_game.pretty_print()
#
#    print("Game complete!")
#    current_game.print_moves()
#
#elif choice == 2:
#    solver = GameSolver(game1)
#    solver.solve()
#
#else:
#    print("Whoops, choose 1 or 2 next time")


