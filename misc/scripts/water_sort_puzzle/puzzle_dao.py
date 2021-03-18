from typing import List
import json

from puzzle import Puzzle


class PuzzleDao:

    def __init__(self, filename: str):
        self.filename = filename
        self.puzzles = []
        self.puzzles_json = {}

        self.load()


    def save(self):
        self.update_puzzle_names()

        self.puzzles.sort(key=lambda puzzle: puzzle.name)

        self.puzzles_json = [Puzzle.serialize(puzzle) for puzzle in self.puzzles]

        with open(self.filename, 'w') as f:
            json.dump(self.puzzles_json, f, indent=4)


    def update_puzzle_names(self):
        num_puzzles = len(self.puzzles)
        num_digits = len(f"{num_puzzles}")
        for puzzle in self.puzzles:
            if len(puzzle.name) < num_digits:
                puzzle.name = f"0{puzzle.name}"


    def load(self):
        f = open(self.filename)
        self.puzzles_json = json.load(f)

        self.puzzles = [Puzzle.deserialize(puzzle_json) for puzzle_json in self.puzzles_json]

        f.close()


    def add_puzzle(self, puzzle: Puzzle):
        self.puzzles.append(puzzle)

        self.save()

