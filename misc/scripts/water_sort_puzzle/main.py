from typing import List
from pathlib import Path
import os

from color import Color
from puzzle import Puzzle
from puzzle_dao import PuzzleDao
from move import Move
from solver import PuzzleSolver
from vial import Vial

speed_testing = False
#speed_testing = True
print_verbose = not speed_testing

def find(name, path):
    for root, dirs, files in os.walk(path):
        if name in files:
            return os.path.join(root, name)

home_dir = str(Path.home())
puzzles_file = find('puzzles.json', f'{home_dir}/dotfiles')

dao = PuzzleDao(puzzles_file)

puzzles = dao.puzzles

puzzle_names_to_puzzles = { puzzle.name : puzzle for puzzle in puzzles }

def choose_puzzle() -> Puzzle:
    if speed_testing:
        for puzzle in puzzles:
            if puzzle.name == '74':
                return puzzle

        return puzzles[len(puzzles) - 1]


    print("Please choose from the list of puzzles:")
    for index, puzzle in enumerate(puzzles):
        puzzle.pretty_print(True)

    def ask_and_find_puzzle_names() -> List[str]:
        search_key = input(f"Choose a puzzle number: [{puzzles[0].name}] ").strip() or puzzles[0].name
        print()

        puzzle = puzzle_names_to_puzzles[search_key] if search_key in puzzle_names_to_puzzles else None

        puzzle_names = [key for key in puzzle_names_to_puzzles.keys() if search_key in key]

        return (puzzle, puzzle_names)

    (puzzle, puzzle_names) = ask_and_find_puzzle_names()
    num_puzzle_names = len(puzzle_names)

    while not puzzle and num_puzzle_names != 1:
        if num_puzzle_names == 0:
            print("Found zero puzzles matching name. Please try again")
        else:
            print(f"Found multiple puzzles matching name: {puzzle_names}")

        (puzzle, puzzle_names) = ask_and_find_puzzle_names()
        num_puzzle_names = len(puzzle_names)

    return puzzle or puzzle_names_to_puzzles[puzzle_names[0]]


colors = [color for color in Color if not color == Color.NONE]

def print_and_save_puzzle(puzzle: Puzzle) -> None:
    print("Done building!\n")
    puzzle.pretty_print(True)

    print("Saving puzzle.\n")
    dao.add_puzzle(puzzle)


if True:
    choice = 2
    if not speed_testing:
        print("Would you like to:")
        print("  1. Play")
        print("  2. Solve")
        print("  3. Solve all puzzles")
        print("  4. Build puzzle")
        print("  5. Build puzzle fast")
        print("  6. Build randomized puzzle ")
        print("  7. Check for missing puzzles")

        choice = int(input("\nChoose an option: ").strip())
    print()

    if choice == 1:
        chosen_puzzle = choose_puzzle()
        print("Let's start!\n")
        chosen_puzzle.pretty_print(True)

        while not chosen_puzzle.is_complete():
            from_index = int(input("Enter a vial number to pour from: ").strip())
            to_index = int(input("Enter a vial number to pour into: ").strip())
            print()

            move = Move(from_index, to_index)
            if not chosen_puzzle.can_move(move):
                print(f"{move.string()} cannot be made, please choose again.")
                continue

            chosen_puzzle.move(move)

            chosen_puzzle.pretty_print()

        print("Puzzle complete!")
        chosen_puzzle.print_moves(print_verbose)

    elif choice == 2:
        chosen_puzzle = choose_puzzle()
        solver = PuzzleSolver(chosen_puzzle)
        finished_puzzle = solver.solve(print_verbose)

        if not speed_testing:
            show_replay = input("Would you like to see the replay? [Y/n] ").strip() or "Y"
            print()

            if show_replay == "Y":
                solver.show_replay(finished_puzzle.get_moves())

    elif choice == 3:
        for puzzle in puzzles:
            solver = PuzzleSolver(puzzle)
            print(puzzle.name)
            solver.solve(verbose=False)

    elif choice == 4:
        def choose_colors(num_colors: int) -> List[Color]:
            for color_index, color in enumerate(colors):
                print(f"Color {color_index}: {color.pretty_string()}")

            color_choices = []
            print(f"\nChoose {num_colors} colors from bottom to top")
            for choice_index in range(num_colors):
                color_choice = int(input(f"For color {choice_index + 1}, choose a number between 0 and {len(colors)}: ").strip())
                while color_choice < 0 or color_choice >= len(colors):
                    color_choice = int(input(f"Invalid color option, choose a number between 0 and {len(colors)}: ").strip())

                color_choices.append(colors[color_choice])

            return color_choices

        print("Let's start!\n")

        puzzle_name = input("What's the name of this puzzle? ").strip()

        num_vials = int(input("\nHow many vials do you want? ").strip())
        print()

        vials: List[Vial] = []

        vials = []
        for vial_index in range(num_vials):
            num_colors_answer = input("How many colors do you want? [4] ").strip() or "4"
            num_colors = int(num_colors_answer)

            vial = None
            if num_colors == 0:
                vial = Vial(vial_index, [])

            else:
                is_good = "n"
                while not is_good == "Y":
                    print(f"Please choose your colors for vial {vial_index}")
                    color_choices = choose_colors(num_colors)

                    vial = Vial(vial_index, color_choices)
                    vial.pretty_print()
                    is_good = input("\nDoes the vial look correct? [Y/n] ").strip() or "Y"

            vials.append(vial)
            print("\n")

        puzzle = Puzzle(puzzle_name, vials)

        print_and_save_puzzle(puzzle)

    elif choice == 5:
        def choose_colors() -> List[Color]:
            color_choices = []
            colors_input = input(f"Type a comma separated list of colors from bottom to top: ").strip()

            for partial_color_str in colors_input.split(","):
                for color in colors:
                    if partial_color_str.upper() in color.name:
                        color_choices.append(color)
                        break

            return color_choices

        print("Let's start!\n")

        puzzle_name = input("What's the name of this puzzle? ").strip()

        num_vials = int(input("\nHow many vials do you want? ").strip())
        print()

        vials: List[Vial] = []

        for color in colors:
            print(f"{color.pretty_string()}")

        vials = []
        empty_vials = 2
        for vial_index in range(num_vials):
            vial = None

            if vial_index >= num_vials - empty_vials:
                vial = Vial(vial_index, [])

            else:
                is_good = "n"
                while not is_good == "Y":
                    print(f"Please choose your colors for vial {vial_index}")
                    color_choices = choose_colors()

                    vial = Vial(vial_index, color_choices)
                    vial.pretty_print()
                    is_good = input("\nDoes the vial look correct? [Y/n] ").strip() or "Y"

                print("\n")

            vials.append(vial)

        puzzle = Puzzle(puzzle_name, vials)

        print_and_save_puzzle(puzzle)

    elif choice == 6:
        print("To be built...")

    elif choice == 7:
        print("Printing missing puzzles...\n")

        for expected_index in range(1, 101):
            found_expected_puzzle = False

            for puzzle in puzzles:
                if int(puzzle.name) == expected_index:
                    found_expected_puzzle = True
                    break

            if not found_expected_puzzle:
                print(f"Missing puzzle '{expected_index}'")

    else:
        print("Whoops, choose a number from 1 to 7 next time")

