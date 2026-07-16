class Color:
    def __init__(self, r: int, g: int, b: int) -> None:
        assert type(r) is int and 0 <= r < 256
        assert type(g) is int and 0 <= g < 256
        assert type(b) is int and 0 <= b < 256

        self.r = r
        self.g = g
        self.b = b

    @property
    def rgb(self) -> tuple[int, int, int]:
        return (self.r, self.g, self.b)

    @property
    def hex(self) -> str:
        def int_to_hex(i: int) -> str:
            return hex(i).removeprefix("0x")

        return f"#{int_to_hex(self.r)}{int_to_hex(self.g)}{int_to_hex(self.b)}"

    @property
    def ansi(self) -> str:
        return f"\\033[38;2;{self.r};{self.g};{self.b}m"


class ColorUtils:
    @staticmethod
    def hex_to_rgb(hexp: str) -> tuple[int, int, int]:
        assert type(hexp) is str
        assert hexp.__len__() == 7
        hexp = hexp.removeprefix("#")
        return int(hexp[:2], 16), int(hexp[2:4], 16), int(hexp[4:6], 16)

    @staticmethod
    def hex_to_ansi(hexp: str) -> str:
        assert type(hexp) is str
        assert hexp.__len__() == 7
        hexp = hexp.removeprefix("#")
        return (
            f"\\033[38;2;{int(hexp[:2], 16)};{int(hexp[2:4], 16)};{int(hexp[4:6], 16)}m"
        )

    @staticmethod
    def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
        assert type(rgb) is tuple
        assert type(rgb[0]) is int and 0 <= rgb[0] < 256
        assert type(rgb[0]) is int and 0 <= rgb[1] < 256
        assert type(rgb[0]) is int and 0 <= rgb[2] < 256

        def int_to_hex(i: int) -> str:
            return hex(i).removeprefix("0x")

        return f"#{int_to_hex(rgb[0])}{int_to_hex(rgb[1])}{int_to_hex(rgb[2])}"

    @staticmethod
    def rgb_to_ansi(rgb: tuple[int, int, int]) -> str:
        assert type(rgb) is tuple
        assert type(rgb[0]) is int and 0 <= rgb[0] < 256
        assert type(rgb[0]) is int and 0 <= rgb[1] < 256
        assert type(rgb[0]) is int and 0 <= rgb[2] < 256
        return f"\\033[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m"
