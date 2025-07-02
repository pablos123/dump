from selenium import webdriver
from bs4 import BeautifulSoup
import sys
from pathlib import Path
from dataclasses import dataclass

CSV_FILE: Path = Path("data.csv")
COMMENTS_FILE: Path = Path("comentarios.txt")
COMMENTS_FILE_URL: Path = Path("comentarios_con_url.txt")
DESCRIPTIONS_FILE: Path = Path("descripciones.txt")
DESCRIPTIONS_FILE_URL: Path = Path("descripciones_con_url.txt")


@dataclass
class PostInfo:
    url: str
    comments_count: int
    shares_count: int
    interactions_count: int
    description: str
    hashtags: list[str]
    date: str
    comments: list[str]


# Get information of the urls in the given file.
# The urls in the file needs to be in the form of:
# https://www.facebook.com/ArchivoGeneraldelaNacionArgentina/posts/pfbid0sHSHvgaUUCJ1CxHqZE95XkCwsscC79swgjNETRLwabgxtA1Jam7z54u59PWGw6Zzl
# Maybe it works with another type of url but this script is not taking that into account.
def main():
    # ------------------------------------
    assert sys.argv[1]

    try:
        post_file: Path = Path(sys.argv[1])
    except Exception:
        print("Invalid file")
        return

    if not post_file.is_file():
        print("Invalid file")
        return
    # ------------------------------------

    urls: list[str] = []
    with open(post_file) as f:
        for line in f:
            urls.append(line.rstrip())

    with DESCRIPTIONS_FILE.open("w"):
        ...

    with DESCRIPTIONS_FILE_URL.open("w"):
        ...

    with COMMENTS_FILE.open("w"):
        ...

    with COMMENTS_FILE_URL.open("w"):
        ...

    with CSV_FILE.open("w") as f:
        f.write(
            "Nro.Compartidos|Nro.Interacciones|Nro.Comentarios|Engagement|Hashtags|Fecha|Descripción|URL\n"
        )

    driver: webdriver.Chrome = get_chrome_driver()
    for url in urls:
        print(f"Procesando {url}")
        show_info(create_post_info(get_url_soup(url, driver), url))

    driver.quit()


def show_info(info: PostInfo) -> None:
    info_string: str = "|".join(
        [
            str(info.shares_count),
            str(info.interactions_count),
            str(info.comments_count),
            str(info.shares_count + info.interactions_count + info.comments_count),
            " ".join(info.hashtags),
            info.date,
            info.description,
            info.url,
        ]
    )

    with CSV_FILE.open("a") as f:
        f.write(f"{info_string}\n")

    with DESCRIPTIONS_FILE_URL.open("a") as f1, DESCRIPTIONS_FILE.open("a") as f2:
        f1.write(f"{info.url}\n{info.description}\n")
        f2.write(f"{info.description}\n")

    with COMMENTS_FILE_URL.open("a") as f1, COMMENTS_FILE.open("a") as f2:
        f1.write(f"{info.url}\n")
        for comment in info.comments:
            f1.write(f"{comment}\n")
            f2.write(f"{comment}\n")
        f1.write("\n")


# Only support for x, xK, x.xK just for the problem's scope
def str_to_int(string_number: str) -> int:
    if not string_number:
        return 0

    if string_number.find("K") > 0:
        return int(float(string_number.removesuffix("K")) * 1000)
    return int(string_number)


# Get post's relevant information
def create_post_info(soup: BeautifulSoup, url: str) -> PostInfo:
    # Comments and shares count
    # -------------------------------------------------------------------------
    comments_count: int = 0
    shares_count: int = 0
    try:
        comments_and_shares_count_spans = soup.select(
            "span.html-span.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.xexx8yu.x4uap5.x18d9i69.xkhd6sd.x1hl2dhg.x16tdsg8.x1vvkbs.xkrqix3.x1sur9pj"
        )
        for s in comments_and_shares_count_spans:
            if not s.text:
                continue

            if s.text.find("comments") > 0:
                comments_count: int = str_to_int(s.text.removesuffix(" comments"))
            elif s.text.find("shares") > 0:
                shares_count: int = str_to_int(s.text.removesuffix(" shares"))
    except Exception:
        ...
    # -------------------------------------------------------------------------

    # Interactions count
    # -------------------------------------------------------------------------
    interactions_count: int = 0
    try:
        interactions_count = str_to_int(
            soup.select("span.xrbpyxo.x6ikm8r.x10wlt62.xlyipyv.x1exxlbk")[0].text
        )
    except Exception:
        ...
    # -------------------------------------------------------------------------

    # Comments
    # -------------------------------------------------------------------------
    comments: list[str] = []
    try:
        comments_divs = soup.select("div.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.x1vvkbs")

        for comment_div_i in range(1, comments_divs.__len__()):
            comment = comments_divs[comment_div_i].text
            if comment:
                comments.append(comment)
    except Exception:
        ...
    # -------------------------------------------------------------------------

    # Description
    # -------------------------------------------------------------------------
    description: str = ""
    try:
        description_span: str = (
            soup.select(
                "span.x193iq5w.xeuugli.x13faqbe.x1vvkbs.x10flsy6.x1lliihq.x1s928wv.xhkezso.x1gmr53x.x1cpjm7i.x1fgarty.x1943h6x.x4zkp8e.x41vudc.x6prxxf.xvq8zen.xo1l8bm.xzsf02u.x1yc453h"
            )[0].text
            or ""
        )
        description_divs: list = soup.select(
            "div.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.x1vvkbs.x126k92a"
        )

        if description_span:
            description = description_span

        for i in description_divs:
            for j in i:
                if str(j.text) not in description:
                    description = f"{description}{str(j.text).rstrip().lstrip()}"

    except Exception:
        ...
    # -------------------------------------------------------------------------

    # Hashtags
    # -------------------------------------------------------------------------
    hashtags: list[str] = []
    if description:
        for string in description.split():
            if string.startswith("#"):
                hashtags.append(string)
    # -------------------------------------------------------------------------

    # Date
    # -------------------------------------------------------------------------
    def month_to_number(string: str) -> str:
        if string == "January":
            return "01"
        elif string == "February":
            return "02"
        elif string == "March":
            return "03"
        elif string == "April":
            return "04"
        elif string == "May":
            return "05"
        elif string == "June":
            return "06"
        elif string == "July":
            return "07"
        elif string == "August":
            return "08"
        elif string == "September":
            return "09"
        elif string == "October":
            return "10"
        elif string == "November":
            return "11"
        elif string == "December":
            return "12"

        return ""

    date: str = ""
    try:
        date = (
            soup.select(
                "a.x1i10hfl.xjbqb8w.x1ejq31n.xd10rxx.x1sy0etr.x17r0tee.x972fbf.xcfux6l.x1qhh985.xm0m39n.x9f619.x1ypdohk.xt0psk2.xe8uvvx.xdj266r.x11i5rnm.xat24cr.x1mh8g0r.xexx8yu.x4uap5.x18d9i69.xkhd6sd.x16tdsg8.x1hl2dhg.xggy1nq.x1a2a7pz.x1heor9g.xkrqix3.x1sur9pj.x1s688f"
            )[0].text
            or ""
        )
        date_splitted: list[str] = date.replace(",", "").split()
        date = (
            f"{date_splitted[1]}/{month_to_number(date_splitted[0])}/{date_splitted[2]}"
        )
    except Exception:
        ...
    # -------------------------------------------------------------------------

    return PostInfo(
        url,
        comments_count,
        shares_count,
        interactions_count,
        description,
        hashtags,
        date,
        comments,
    )


def get_chrome_driver() -> webdriver.Chrome:
    # Chrome brower options
    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    # Launch Chrome browser
    return webdriver.Chrome(options=options)


# Open chrome browser and get the sopa.
def get_url_soup(url: str, driver: webdriver.Chrome) -> BeautifulSoup:
    # Navigate to the page
    driver.get(url)
    # Give the page some time to load
    driver.implicitly_wait(10)
    # Get the page source after JavaScript has rendered the content
    page_source = driver.page_source

    return BeautifulSoup(page_source, "html.parser")


if __name__ == "__main__":
    main()
