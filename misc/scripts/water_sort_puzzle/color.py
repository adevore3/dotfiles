from enum import Enum, unique
from colorama import Fore, Style


@unique
class Color(Enum):
    NONE = Fore.BLACK
    RED = Fore.RED + Style.DIM
    GREEN = Fore.GREEN
    BLUE = Fore.BLUE + Style.BRIGHT
    CYAN = Fore.CYAN + Style.BRIGHT
    PURPLE = Fore.MAGENTA + Style.DIM
    GRAY = Fore.WHITE + Style.DIM
    PINK = Fore.MAGENTA + Style.BRIGHT
    ORANGE = Fore.RED + Style.BRIGHT
    NEON_GREEN = Fore.GREEN + Style.BRIGHT


    @staticmethod
    def serialize(color: 'Color') -> str:
        return color.name


    @staticmethod
    def deserialize(color_name: str) -> 'Color':
        for color in Color:
            if color_name.upper() in color.name:
                return color

        return Color.NONE


    def pretty_string(self) -> str:
        return self.value + self.name + Style.RESET_ALL


    def pretty_print(self) -> None:
        print(self.pretty_string())

