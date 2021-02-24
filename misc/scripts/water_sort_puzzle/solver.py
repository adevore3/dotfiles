from copy import deepcopy
from max_priority_queue import MaxPriorityQueue
from typing import List
import time

from puzzle import Puzzle
from move import Move


class PuzzleSolver:

    def __init__(self, puzzle: Puzzle):
        self.puzzle = puzzle
        self.queue = MaxPriorityQueue()


    def enqueue(self, puzzle: Puzzle) -> None:
        self.queue.put(puzzle.get_weight(), puzzle)


    def dequeue(self) -> Puzzle:
        return self.queue.get()[1]


    def solve(self, verbose: bool = False) -> Puzzle:
        if verbose:
            print("Starting to solve...\n")
            self.puzzle.pretty_print(True)

        current_puzzle = self.puzzle

        num_puzzles_created = 0
        checked_puzzles = set()

        while current_puzzle and not current_puzzle.is_complete():
            checked_puzzles.add(current_puzzle)

            possible_moves = current_puzzle.possible_moves()

            for move in possible_moves:
                copy_puzzle = deepcopy(current_puzzle)
                num_puzzles_created += 1

                copy_puzzle.move(move)

                if copy_puzzle in checked_puzzles:
                    continue

                self.enqueue(copy_puzzle)

            if self.queue.empty():
                print("Unable to solve puzzle")
                break

            current_puzzle = self.dequeue()

        if verbose:
            print("Solved!\n")

            current_puzzle.pretty_print()

        print(f"num of puzzles created: {num_puzzles_created}")
        print(f"num of unique puzzles: {len(checked_puzzles)}")
        print(f"length of queue {self.queue.qsize()}")

        current_puzzle.print_moves(verbose)

        return current_puzzle


    def show_replay(self, moves: List[Move]) -> None:
        copy_puzzle = deepcopy(self.puzzle)

        print("Starting\n")
        copy_puzzle.pretty_print()

        for index, move in enumerate(moves):
            time.sleep(1)
            print(f"Move {index + 1}: {move.string()}\n")
            copy_puzzle.move(move)
            copy_puzzle.pretty_print()
            print(f"puzzle weight: {copy_puzzle.get_weight()}")
            copy_puzzle.validate()
            print("\n")

